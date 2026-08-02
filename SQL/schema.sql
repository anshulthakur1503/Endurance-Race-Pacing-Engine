CREATE DATABASE IF NOT EXISTS race_pacing_engine;    -- Database : race_pacing_engine
USE race_pacing_engine;
DROP DATABASE race_pacing_engine; -- Dropped the database // autoincrement was causing issue while dropping tables



-- I BASE TABLES : 1. RUNNER 2.RACES
-- RUNNERS TABLE

CREATE TABLE Runners (
    RunnerID INT AUTO_INCREMENT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Gender ENUM('M', 'F', 'X') NOT NULL,
    DOB DATE NOT NULL,
    Nationality VARCHAR(3) 
);

-- RACES TABLE
CREATE TABLE Races (
    RaceID INT AUTO_INCREMENT PRIMARY KEY,
    RaceName VARCHAR(100) NOT NULL,
    RaceDate DATE NOT NULL,
    Location VARCHAR(100) NOT NULL,
    Distance_KM DECIMAL(5, 2) NOT NULL, -- e.g., 21.10 for Half Marathon, 42.20 for Marathon
    ElevationGain_M INT DEFAULT 0
);

-- II JUNCTION/TRANSACTION TABLES : 1. REGISTERATIONS 2. SPLITLOGS



-- REGISTRATIONS TABLE
CREATE TABLE Registrations (
    RegID INT AUTO_INCREMENT PRIMARY KEY,
    RunnerID INT NOT NULL,
    RaceID INT NOT NULL,
    BibNumber VARCHAR(10) NOT NULL,
    Category VARCHAR(20) NOT NULL, -- e.g., '18-24', 'Open', 'Masters'
    RegistrationStatus ENUM('Registered', 'DNS', 'DNF', 'Finished') DEFAULT 'Registered',
    -- DNS = Did Not Start, DNF = Did Not Finish
    UNIQUE(RunnerID, RaceID), -- A runner can only register for the same race once
    FOREIGN KEY (RunnerID) REFERENCES Runners(RunnerID) ON DELETE CASCADE,
    FOREIGN KEY (RaceID) REFERENCES Races(RaceID) ON DELETE CASCADE
);


-- SPLITLOGS TABLE
CREATE TABLE SplitLogs (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    RegID INT NOT NULL,
    Kilometer_Mark DECIMAL(5, 2) NOT NULL, -- The location of the timing mat (e.g., 5.00, 10.00, 21.10)
    Chip_Timestamp DATETIME NOT NULL,      -- The exact time the runner crossed the mat
    FOREIGN KEY (RegID) REFERENCES Registrations(RegID) ON DELETE CASCADE
);

-- III Indexes for Performance Optimization

CREATE INDEX idx_split_reg ON SplitLogs(RegID);
CREATE INDEX idx_split_km ON SplitLogs(Kilometer_Mark);
CREATE INDEX idx_race_date ON Races(RaceDate);
