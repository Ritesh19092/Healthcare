create database health 

use health

select * from dbo.encounters
select * from organizations
select * from patients
select * from payers
select * from procedures

alter table encounters add New_date datetime

Update encounters set New_date = CONVERT(DATETIME, REPLACE(START, 'Z', ''), 126)

alter table encounters add stop_date datetime

Update encounters set stop_date = CONVERT(DATETIME, REPLACE(STOP, 'Z', ''), 126)

alter table encounters drop column start 

alter table encounters drop column stop 

alter table procedures add New_date datetime

Update procedures set New_date = CONVERT(DATETIME, REPLACE(START, 'Z', ''), 126)

alter table procedures add stop_date datetime

Update procedures set stop_date = CONVERT(DATETIME, REPLACE(STOP, 'Z', ''), 126)

alter table procedures drop column start 

alter table procedures drop column stop 

select Column_name, Data_type
from Information_schema.columns
where table_name in ('encounters','organizations','patients','payers','procedures')

--Analysis 1 

--Evaluating Financial Risk by Encounter Outcome

SELECT COUNT(encounters.Id) AS EncounterCount, SUM(encounters.Total_Claim_Cost - encounters.Payer_Coverage) AS TotalUncoveredCost, 
AVG(encounters.Total_Claim_Cost - encounters.Payer_Coverage) AS AvgUncoveredCost,patients.Gender, patients.Race, patients.Ethnicity, patients.Marital,
organizations.NAME,encounters.EncounterClass, encounters.Code , encounters.Description
FROM encounters 
JOIN patients ON encounters.Patient = patients.Id
JOIN organizations  ON encounters.Organization = organizations.Id
WHERE encounters.Total_Claim_Cost > encounters.Payer_Coverage 
GROUP BY patients.Gender, patients.Race, patients.Ethnicity, patients.Marital, encounters.EncounterClass, encounters.Code, encounters.Description,organizations.NAME
ORDER BY TotalUncoveredCost DESC

-- Analysis 2 

-- Identifying Patients with Frequent High-Cost Encounters

SELECT patients.Id , patients.First, patients.Last, patients.Gender, patients.BirthDate, COUNT(encounters.Id) AS EncounterCount, 
SUM(encounters.Total_Claim_Cost) AS TotalCost
FROM encounters 
JOIN patients  ON encounters.Patient = patients.Id
WHERE encounters.Total_Claim_Cost > 10000  
AND YEAR(encounters.New_date) IN (2011, 2012, 2013, 2014)  
GROUP BY patients.Id, patients.First, patients.Last, patients.Gender, patients.BirthDate
HAVING COUNT(encounters.Id) > 3  
ORDER BY TotalCost DESC

-- Analysis 3

-- Identifying Risk Factors Based on Demographics and Encounter Reasons

WITH TopReasonCodes AS (SELECT encounters.ReasonCode, encounters.ReasonDescription, COUNT(encounters.Id) AS EncounterCount,
ROW_NUMBER() OVER (ORDER BY COUNT(encounters.Id) DESC) AS RowNum
FROM encounters 
WHERE encounters.Total_Claim_Cost > 10000  
GROUP BY encounters.ReasonCode, encounters.ReasonDescription
)

SELECT encounters.ReasonCode, encounters.ReasonDescription, patients.Gender, patients.Race, patients.Ethnicity, patients.Marital, 
COUNT(encounters.Id) AS EncounterCount, SUM(encounters.Total_Claim_Cost) AS TotalCost
FROM encounters 
JOIN patients  ON encounters.Patient = patients.Id
JOIN TopReasonCodes  ON encounters.ReasonCode = TopReasonCodes.ReasonCode
WHERE TopReasonCodes.RowNum <= 3  
GROUP BY encounters.ReasonCode, encounters.ReasonDescription, patients.Gender, patients.Race, patients.Ethnicity, patients.Marital
ORDER BY EncounterCount DESC

-- Analysis 4 

-- Assessing Payer Contributions for Different Procedure Types

SELECT procedures.Code, procedures.Description ,payers.Name , SUM(procedures.Base_Cost) AS TotalBaseCost,
SUM(encounters.Total_Claim_Cost) AS TotalClaimCost, SUM(encounters.Payer_Coverage) AS TotalPayerCoverage, 
SUM(encounters.Total_Claim_Cost - encounters.Payer_Coverage) AS UncoveredCost
FROM procedures 
JOIN encounters ON procedures.Encounter = encounters.Id
JOIN payers ON encounters.Payer = payers.Id
GROUP BY procedures.Code, procedures.Description, payers.Name
ORDER BY UncoveredCost DESC

-- Analysis 5 

-- Identifying Patients with Multiple Procedures Across Encounters

SELECT patients.Id , patients.First, patients.Last, procedures.ReasonCode, procedures.ReasonDescription, 
COUNT(DISTINCT encounters.Id) AS DistinctEncounterCount, COUNT(procedures.Code) AS ProcedureCount
FROM procedures 
JOIN encounters ON procedures.Encounter = encounters.Id
JOIN patients ON encounters.Patient = patients.Id
WHERE procedures.ReasonCode IS NOT NULL  
GROUP BY patients.Id, patients.First, patients.Last, procedures.ReasonCode, procedures.ReasonDescription
HAVING COUNT(DISTINCT encounters.Id) > 1  
ORDER BY ProcedureCount DESC

-- Analysis 6 

-- Analyzing Patient Encounter Duration for Different Classes

WITH EncounterDurations AS (SELECT encounters.Organization, organizations.Name , encounters.EncounterClass, 
DATEDIFF(HOUR, encounters.New_date, encounters.stop_date) AS DurationHours  
FROM encounters 
JOIN organizations ON encounters.Organization = organizations.Id
)

SELECT EncounterDurations.Organization, EncounterDurations.Name, EncounterDurations.EncounterClass, COUNT(*) AS EncounterCount, 
AVG(EncounterDurations.DurationHours) AS AvgDurationHours,
SUM(CASE WHEN EncounterDurations.DurationHours > 24 THEN 1 ELSE 0 END) AS EncountersOver24Hours
FROM EncounterDurations 
GROUP BY EncounterDurations.Organization, EncounterDurations.Name, EncounterDurations.EncounterClass
ORDER BY AvgDurationHours DESC
