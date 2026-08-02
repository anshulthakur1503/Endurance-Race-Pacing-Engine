End-to-End Data Analytics Project: Endurance Race Pacing Engine (SQL + Python)

Overview

This project is an end-to-end data analytics solution designed to track, analyze, and optimize endurance race performances. It bridges the gap between raw, sequential timing-mat logs and actionable race-day intelligence. The project encompasses complete database development in MySQL and advanced time-series feature engineering and visualization using Python and Pandas.

Tech Stack

Database: MySQL, MySQL Workbench

Programming Language: Python

Environment: Jupyter Notebook, VS Code

Data Analysis: Pandas, NumPy

Visualization: Matplotlib

Version Control: Git, GitHub

Project Structure

Endurance_Race_Analytics/
│
├── README.md
├── SQL/
│   ├── schema.sql
│   ├── sample_data.sql
│   └── advanced_sql_features.sql
│
├── Python/
│   ├── 01_data_extraction.ipynb
│   └── 02_pacing_analytics.ipynb
│
├── Output/
│   ├── Charts/
│   │   └── pacing_strategy_analysis.png
│   └── Results/
│
├── Reports/
│   └── Project_Report.pdf


Business Problem

Marathon organizers and athletic directors lack granular, automated metrics to identify split pacing irregularities, dynamically rank runners across multiple age divisions, and spot negative splits versus pacing burnouts. Without this data, crowd control, medical staff allocation, and post-race performance reviews rely on guesswork rather than data-driven intelligence.

Database Design

The relational database was normalized to 3NF to ensure data integrity.

Master Tables: Runners (demographics), Races (event details)

Transaction Tables: Registrations (junction), SplitLogs (time-series chip reads)

Advanced Features: Implemented DENSE_RANK() for leaderboards, LAG() for split-duration calculations, and automated Triggers for finish-line status updates.

Key Analyses & KPIs

Pace Variance (Consistency Metric): Calculated the standard deviation of pace per kilometer to classify runners as consistent pacers or erratic pacers.

Dynamic Leaderboards: Partitioned runners by gender and age categories to assign exact podium ranks regardless of tied finish times.

Pacing Strategy Detection: Identified "Negative Splitters" (accelerating) vs. "Positive Splitters" (hitting the wall) using shifting time deltas.

Sample Insights

Observation: Consistent pacers maintain a variance near 0.0 (Std Dev < 0.1), whereas "negative split" runners decrease their pace by up to 30 seconds per kilometer in the second half of the race.

Reason: Runners adopt different physiological strategies; negative splitters conserve energy early to accelerate past fatigued runners later in the race.

Business Impact: Understanding divergent pacing profiles is crucial for crowd control. Accelerating runners traverse the final 10km much faster than anticipated, causing sudden, dense clusters at the finish line and medical tents.

Recommendation: Dynamically shift medical staff and heavy hydration resources from the 5km/10km marks to the 15km/20km stations during the second hour of the race to support the sudden influx of high-exertion runners.

How to Run This Project

Clone this repository.

Ensure MySQL is running on your local machine.

Execute the SQL scripts in the SQL/ folder in the following order: schema.sql -> sample_data.sql -> advanced_sql_features.sql.

Open the Jupyter Notebooks in the Python/ folder.

Update the MySQL connection credentials (user and password) in the notebooks.

Run the notebook cells sequentially to extract the data, calculate KPIs, and generate charts.

Author

Anshul Thakur

