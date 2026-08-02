-- Views 

-- View 1: vw_runner_demographics
-- Purpose: Simplifies reporting by pre-joining Runners, Registrations, and Races.
-- This makes it easy to quickly pull a roster without writing complex JOINs every time.

CREATE OR REPLACE VIEW vw_runner_demographics AS
SELECT 
    reg.RegID,
    race.RaceID,
    reg.BibNumber,
    r.FirstName,
    r.LastName,
    r.Gender,
    TIMESTAMPDIFF(YEAR, r.DOB, race.RaceDate) AS AgeOnRaceDay,
    reg.Category,
    race.RaceName,
    race.Distance_KM
FROM Registrations reg
JOIN Runners r ON reg.RunnerID = r.RunnerID
JOIN Races race ON reg.RaceID = race.RaceID;

-- View 2: vw_race_completion_stats
-- Purpose: Aggregates completion statuses to give race directors a quick health check of the event.
CREATE OR REPLACE VIEW vw_race_completion_stats AS
SELECT 
    RaceID,
    COUNT(*) AS TotalRegistrations,
    SUM(CASE WHEN RegistrationStatus = 'Finished' THEN 1 ELSE 0 END) AS TotalFinished,
    SUM(CASE WHEN RegistrationStatus = 'DNF' THEN 1 ELSE 0 END) AS TotalDNF,
    SUM(CASE WHEN RegistrationStatus = 'DNS' THEN 1 ELSE 0 END) AS TotalDNS,
    ROUND((SUM(CASE WHEN RegistrationStatus = 'Finished' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS CompletionRatePercent
FROM Registrations
GROUP BY RaceID;

-- View 3: vw_latest_chip_reads
-- Purpose: Isolates the most recent timing mat crossed by every runner.
-- Useful for live tracking during an ongoing race.
CREATE OR REPLACE VIEW vw_latest_chip_reads AS
SELECT 
    s1.RegID,
    s1.Kilometer_Mark AS LastKnownKM,
    s1.Chip_Timestamp AS LastKnownTime
FROM SplitLogs s1
JOIN (
    -- Subquery finds the max distance logged for each registration
    SELECT RegID, MAX(Kilometer_Mark) AS Max_KM
    FROM SplitLogs
    GROUP BY RegID
) s2 ON s1.RegID = s2.RegID AND s1.Kilometer_Mark = s2.Max_KM;


-- Procedures 

DELIMITER //

-- Procedure 1: sp_register_new_runner
-- Purpose: Safely registers a runner for a race, handling both the Runner table (if new) 
-- and the Registration table in a single transaction.
CREATE PROCEDURE sp_register_new_runner(
    IN p_FirstName VARCHAR(50),
    IN p_LastName VARCHAR(50),
    IN p_Gender ENUM('M', 'F', 'X'),
    IN p_DOB DATE,
    IN p_Nationality VARCHAR(3),
    IN p_RaceID INT,
    IN p_BibNumber VARCHAR(10),
    IN p_Category VARCHAR(20)
)
BEGIN
    DECLARE v_RunnerID INT;
    
    -- Check if runner already exists based on Name and DOB
    SELECT RunnerID INTO v_RunnerID
    FROM Runners
    WHERE FirstName = p_FirstName AND LastName = p_LastName AND DOB = p_DOB
    LIMIT 1;
    
    -- If runner doesn't exist, insert them
    IF v_RunnerID IS NULL THEN
        INSERT INTO Runners (FirstName, LastName, Gender, DOB, Nationality)
        VALUES (p_FirstName, p_LastName, p_Gender, p_DOB, p_Nationality);
        
        -- Grab the newly generated Auto-Increment ID
        SET v_RunnerID = LAST_INSERT_ID();
    END IF;
    
    -- Insert the registration record
    INSERT INTO Registrations (RunnerID, RaceID, BibNumber, Category, RegistrationStatus)
    VALUES (v_RunnerID, p_RaceID, p_BibNumber, p_Category, 'Registered');
    
END //


-- Procedure 2: sp_get_runner_splits
-- Purpose: Takes a specific Bib Number and returns their complete split history.
CREATE PROCEDURE sp_get_runner_splits(IN p_BibNumber VARCHAR(10))
BEGIN
    SELECT 
        r.FirstName,
        r.LastName,
        reg.BibNumber,
        sl.Kilometer_Mark,
        sl.Chip_Timestamp
    FROM Registrations reg
    JOIN Runners r ON reg.RunnerID = r.RunnerID
    JOIN SplitLogs sl ON reg.RegID = sl.RegID
    WHERE reg.BibNumber = p_BibNumber
    ORDER BY sl.Kilometer_Mark ASC;
END //

DELIMITER ;

-- Triggers 
DELIMITER //
-- Trigger 1: trg_update_status_on_finish
-- Purpose: Automatically updates a runner's RegistrationStatus to 'Finished' 
-- if they log a split at the final distance of their race.
CREATE TRIGGER trg_update_status_on_finish
AFTER INSERT ON SplitLogs
FOR EACH ROW
BEGIN
    DECLARE v_RaceDistance DECIMAL(5,2);
    
    -- Find the total distance of the race this runner is in
    SELECT r.Distance_KM INTO v_RaceDistance
    FROM Races r
    JOIN Registrations reg ON r.RaceID = reg.RaceID
    WHERE reg.RegID = NEW.RegID;
    
    -- If the new split log matches the race distance, mark them as Finished
    IF NEW.Kilometer_Mark >= v_RaceDistance THEN
        UPDATE Registrations
        SET RegistrationStatus = 'Finished'
        WHERE RegID = NEW.RegID AND RegistrationStatus != 'Finished';
    END IF;
END //

-- Trigger 2: trg_prevent_future_splits
-- Purpose: Data validation. Prevents inserting a chip timestamp that is in the future.
CREATE TRIGGER trg_prevent_future_splits
BEFORE INSERT ON SplitLogs
FOR EACH ROW
BEGIN
    IF NEW.Chip_Timestamp > NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Cannot insert a chip timestamp in the future.';
    END IF;
END //

DELIMITER ;

-- Window Functions 

-- 1. RANKING (DENSE_RANK): Official Category Leaderboard for Race 1
-- Assigns a rank to runners within their specific age/gender category based on finish time.
SELECT 
    vw.Category,
    vw.Gender,
    vw.FirstName,
    vw.LastName,
    sl.Chip_Timestamp AS FinishTime,
    DENSE_RANK() OVER(PARTITION BY vw.Category, vw.Gender ORDER BY sl.Chip_Timestamp ASC) AS PodiumRank
FROM vw_runner_demographics vw
JOIN SplitLogs sl ON vw.RegID = sl.RegID
WHERE vw.RaceID = 1 AND sl.Kilometer_Mark = 21.10;


-- 2. PREVIOUS VS CURRENT (LAG): Calculating exactly how long it took to run the previous 5km segment
-- This calculates the "Split Duration" in minutes.
SELECT 
    RegID,
    Kilometer_Mark,
    Chip_Timestamp,
    LAG(Chip_Timestamp) OVER(PARTITION BY RegID ORDER BY Kilometer_Mark) AS PreviousMatTime,
    -- Calculate difference in minutes between current mat and previous mat
    TIMESTAMPDIFF(MINUTE, 
        LAG(Chip_Timestamp) OVER(PARTITION BY RegID ORDER BY Kilometer_Mark), 
        Chip_Timestamp
    ) AS SplitDuration_Minutes
FROM SplitLogs
WHERE RegID = 5; -- Looking specifically at David (RegID 5)


-- 3. PERCENTILE/QUARTILE (NTILE): Segmenting finishers into Performance Tiers (Top 25%, Bottom 25%)
-- Useful for race directors to analyze the spread of the pack.
SELECT 
    reg.BibNumber,
    sl.Chip_Timestamp AS FinishTime,
    NTILE(4) OVER(ORDER BY sl.Chip_Timestamp ASC) AS PerformanceQuartile 
    -- 1 = Fastest 25%, 4 = Slowest 25%
FROM Registrations reg
JOIN SplitLogs sl ON reg.RegID = sl.RegID
WHERE reg.RaceID = 1 AND sl.Kilometer_Mark = 21.10;


-- 4. MOVING AVERAGE (AVG OVER): Smoothing out pace calculations
-- Calculates a moving average of the duration of the last 3 splits to identify runners who are rapidly slowing down.
WITH SplitDurations AS (
    SELECT 
        RegID,
        Kilometer_Mark,
        TIMESTAMPDIFF(MINUTE, LAG(Chip_Timestamp) OVER(PARTITION BY RegID ORDER BY Kilometer_Mark), Chip_Timestamp) AS SplitMinutes
    FROM SplitLogs
)
SELECT 
    RegID,
    Kilometer_Mark,
    SplitMinutes,
    ROUND(AVG(SplitMinutes) OVER(PARTITION BY RegID ORDER BY Kilometer_Mark ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS MovingAvg_3_Splits
FROM SplitDurations
WHERE SplitMinutes IS NOT NULL;


-- 5. RUNNING TOTAL (COUNT OVER): Cumulative volume of runners crossing the 10km mat.
-- Solves the "Bottleneck" business problem, showing directors when aid stations are hit hardest.
SELECT 
    Chip_Timestamp,
    COUNT(*) OVER(ORDER BY Chip_Timestamp) AS CumulativeRunnersPassed
FROM SplitLogs
WHERE Kilometer_Mark = 10.00 AND RegID IN (SELECT RegID FROM Registrations WHERE RaceID = 1);
