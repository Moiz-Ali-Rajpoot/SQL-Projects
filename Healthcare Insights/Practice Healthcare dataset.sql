 -- 1. Lets create a database -- 
 
 CREATE DATABASE healthcare_db;
 USE healthcare_db;
 
 -- 2. Now lets create tables in the database -- 
 
 CREATE TABLE patients 
	( 
     patient_id		INT PRIMARY KEY,
     first_name		VARCHAR(30),
     last_name 		VARCHAR(30),
     dob 			DATE,
     gender 		ENUM('M','F'),
     city 			VARCHAR(30),
     state 			CHAR(2)
     );
     
-- 2.2  providers
CREATE TABLE providers (
    npi            BIGINT PRIMARY KEY,
    provider_name  VARCHAR(50),
    speciality     VARCHAR(50),
    city           VARCHAR(30),
    state          CHAR(2)
);

-- 2.3  icd10_codes (diagnosis lookup)
CREATE TABLE icd10_codes (
    diagnosis_code VARCHAR(30) PRIMARY KEY,
    short_desc     VARCHAR(80),
    long_desc      VARCHAR(200)
);

-- 2.4  cpt_codes (procedure lookup)
CREATE TABLE cpt_codes (
    cpt_code   VARCHAR(5) PRIMARY KEY,
    short_desc VARCHAR(80),
    base_fee   DECIMAL(8,2)
);

-- 2.5  encounters (the billing facts)
CREATE TABLE encounters (
    encounter_id INT PRIMARY KEY,
    patient_id   INT,
    provider_npi BIGINT,
    dos          DATE,          -- date of service
    dx_code_1    VARCHAR(7),
    dx_code_2    VARCHAR(7),
    cpt_code     VARCHAR(5),
    qty          TINYINT DEFAULT 1,
    allowed_amt  DECIMAL(8,2),
    paid_amt     DECIMAL(8,2),
    status       ENUM('Paid','Denied','Pending'),
    CONSTRAINT fk_enc_patient FOREIGN KEY (patient_id)  REFERENCES patients(patient_id),
    CONSTRAINT fk_enc_prov    FOREIGN KEY (provider_npi) REFERENCES providers(npi),
    CONSTRAINT fk_enc_dx1     FOREIGN KEY (dx_code_1)    REFERENCES icd10_codes(diagnosis_code),
    CONSTRAINT fk_enc_cpt     FOREIGN KEY (cpt_code)     REFERENCES cpt_codes(cpt_code)
);    


-- LETS CHECK EACH TABLE NOW


SELECT * FROM patients;
SELECT * FROM cpt_codes;
SELECT * FROM icd10_codes;
SELECT * FROM providers;
SELECT * FROM encounters;


-- 2. wipe lookup tables
DELETE FROM encounters WHERE encounter_id > 0;   -- PK > 0
DELETE FROM cpt_codes WHERE cpt_code <> '';      -- PK not empty
DELETE FROM icd10_codes WHERE diagnosis_code <> '';
DELETE FROM providers WHERE npi > 0;
DELETE FROM patients WHERE patient_id > 0;


-- make the column big enough for any ICD-10 code
ALTER TABLE icd10_codes MODIFY diagnosis_code VARCHAR(30);

ALTER TABLE encounters MODIFY dx_code_2 VARCHAR(30);

-- 3.1  patients
INSERT INTO patients VALUES
(1,'Emma','Martinez','1988-04-10','F','Austin','TX'),
(2,'Liam','Johnson','1975-11-22','M','Dallas','TX'),
(3,'Olivia','Brown','1992-07-03','F','Phoenix','AZ'),
(4,'Noah','Davis','1969-12-15','M','Mesa','AZ'),
(5,'Ava','Wilson','1983-02-28','F','Houston','TX'),
(6,'Ethan','Taylor','1995-09-09','M','San Antonio','TX'),
(7,'Sophia','Anderson','1980-05-18','F','Tucson','AZ'),
(8,'Mason','Thomas','1978-08-30','M','El Paso','TX'),
(9,'Isabella','Jackson','1991-01-20','F','Plano','TX'),
(10,'William','White','1986-10-12','M','Scottsdale','AZ');

-- 3.2  providers
INSERT INTO providers VALUES
(1234567890,'Dr. Smith, MD','Family Medicine','Austin','TX'),
(1234567891,'Dr. Lee, DO','Internal Medicine','Dallas','TX'),
(1234567892,'Dr. Garcia, NP','Nurse Practitioner','Phoenix','AZ'),
(1234567893,'Dr. Patel, MD','Cardiology','Houston','TX'),
(1234567894,'Dr. Kim, PA-C','Physician Assistant','San Antonio','TX');

-- 3.3  icd10_codes
INSERT INTO icd10_codes VALUES
('Z00.00','Encounter for general adult medical examination','Encounter for general adult medical examination without abnormal findings'),
('J06.9','Acute upper respiratory infection','Acute upper respiratory infection, unspecified'),
('M25.50','Pain in unspecified joint','Pain in unspecified joint'),
('I10','Essential hypertension','Essential (primary) hypertension'),
('E11.9','Type 2 diabetes','Type 2 diabetes mellitus without complications'),
('R50.9','Fever, unspecified','Fever, unspecified'),
('S72.001A','Unspecified fracture of right femur','Unspecified fracture of right femur, initial encounter'),
('Z23','Encounter for immunization','Encounter for immunization'),
('K21.9','GERD','Gastro-esophageal reflux disease without esophagitis'),
('N39.0','UTI','Urinary tract infection, site not specified');

-- 3.4  cpt_codes  (ALL needed codes in one shot)
INSERT INTO cpt_codes VALUES
('99213','Office visit est 15 min',120.00),
('99214','Office visit est 25 min',180.00),
('90834','Psychotherapy 45 min',150.00),
('80053','Comprehensive metabolic panel',45.00),
('85025','CBC with diff',35.00),
('93306','Echo complete',450.00),
('36415','Routine venipuncture',15.00),
('J0696','Rocephin injection',25.00),
('99284','ED visit level 4',350.00),
('G0439','Annual wellness visit',165.00),
('90715','Tdap vaccine',85.00);

-- 3.5  encounters  (30 clean rows)
INSERT INTO encounters
(encounter_id,patient_id,provider_npi,dos,dx_code_1,dx_code_2,cpt_code,qty,allowed_amt,paid_amt,status)
VALUES
(1,1,1234567890,'2024-04-01','Z00.00',NULL,'99213',1,120.00,120.00,'Paid'),
(2,1,1234567890,'2024-04-01','Z23',NULL,'90715',1,85.00,85.00,'Paid'),
(3,2,1234567891,'2024-04-02','I10',NULL,'99214',1,180.00,180.00,'Paid'),
(4,3,1234567892,'2024-04-03','J06.9',NULL,'99213',1,120.00,120.00,'Paid'),
(5,4,1234567893,'2024-04-04','E11.9','I10','80053',1,45.00,45.00,'Paid'),
(6,5,1234567890,'2024-04-05','M25.50',NULL,'99213',1,120.00,0.00,'Denied'),
(7,6,1234567894,'2024-04-06','R50.9',NULL,'99284',1,350.00,350.00,'Paid'),
(8,7,1234567892,'2024-04-07','N39.0',NULL,'99214',1,180.00,180.00,'Paid'),
(9,8,1234567891,'2024-04-08','K21.9',NULL,'99213',1,120.00,120.00,'Paid'),
(10,9,1234567890,'2024-04-09','Z00.00',NULL,'G0439',1,165.00,165.00,'Paid'),
(11,10,1234567893,'2024-04-10','S72.001A',NULL,'93306',1,450.00,450.00,'Paid'),
(12,2,1234567891,'2024-04-11','I10',NULL,'99213',1,120.00,120.00,'Paid'),
(13,3,1234567892,'2024-04-12','J06.9','R50.9','85025',1,35.00,35.00,'Paid'),
(14,4,1234567893,'2024-04-13','E11.9',NULL,'80053',1,45.00,45.00,'Paid'),
(15,5,1234567890,'2024-04-14','M25.50',NULL,'99214',1,180.00,180.00,'Paid'),
(16,6,1234567894,'2024-04-15','R50.9',NULL,'36415',1,15.00,15.00,'Paid'),
(17,7,1234567892,'2024-04-16','N39.0',NULL,'J0696',1,25.00,25.00,'Paid'),
(18,8,1234567891,'2024-04-17','K21.9',NULL,'99213',1,120.00,120.00,'Paid'),
(19,9,1234567890,'2024-04-18','Z00.00',NULL,'G0439',1,165.00,165.00,'Paid'),
(20,10,1234567893,'2024-04-19','S72.001A',NULL,'93306',1,450.00,450.00,'Paid'),
(21,1,1234567890,'2024-04-20','Z23',NULL,'90715',1,85.00,0.00,'Pending'),
(22,2,1234567891,'2024-04-21','I10',NULL,'99214',1,180.00,0.00,'Pending'),
(23,3,1234567892,'2024-04-22','J06.9',NULL,'99213',1,120.00,0.00,'Pending'),
(24,4,1234567893,'2024-04-23','E11.9','I10','80053',1,45.00,0.00,'Pending'),
(25,5,1234567890,'2024-04-24','M25.50',NULL,'99213',1,120.00,0.00,'Pending'),
(26,6,1234567894,'2024-04-25','R50.9',NULL,'99284',1,350.00,0.00,'Pending'),
(27,7,1234567892,'2024-04-26','N39.0',NULL,'99214',1,180.00,0.00,'Pending'),
(28,8,1234567891,'2024-04-27','K21.9',NULL,'99213',1,120.00,0.00,'Pending'),
(29,9,1234567890,'2024-04-28','Z00.00',NULL,'G0439',1,165.00,0.00,'Pending'),
(30,10,1234567893,'2024-04-29','S72.001A',NULL,'93306',1,450.00,0.00,'Pending');


-- Lets Start learning analysis by quering 

-- "show me every female patient born after 1990."

SELECT first_name, last_name, dob
FROM patients
WHERE gender = 'F' AND dob > '1990-12-31';

 -- "List every encounter with the patient's full name and the provider's name"
 
SELECT 
	e.encounter_id,
    CONCAT(p.first_name, ' ', last_name) AS "Patient Name",
    e.dos AS "Date of Service",
    pr.provider_name AS "Provider Name"
FROM encounters e
JOIN patients p ON e.patient_id = p.patient_id
JOIN providers pr ON e.provider_npi = pr.npi ;


-- "Total paid amount per provider - Highest On Top"

SELECT 
	pr.provider_name As "Provider Name",
    SUM(e.paid_amt) AS "Total Paid Amount"
FROM encounters e 
JOIN providers pr ON e.provider_npi = pr.npi
GROUP BY pr.provider_name 
ORDER BY  "Total Paid Amount" DESC;    
    
 -- "List first_name and last name of every male patient older than 40 today"
 
 SELECT 
	p.first_name AS "First Name",
    p.last_name AS "Last Name"
FROM patients p
WHERE gender = 'M'
AND timestampdiff(YEAR,dob,CURDATE())> 40;   

-- "Show encounter_id, date of service and paid amount for all encounters that were denied"

SELECT 
	e.encounter_id,
    e.dos AS "Date of Service",
    e.paid_amt As "Paid Amount"
from encounters e
WHERE e.status = "Denied";

-- "How many  encounters does each patien have? Show patient full name and count highest count First"

SELECT 
	CONCAT(p.first_name, ' ', p.last_name) AS Full_Name,
    COUNT(e.encounter_id) AS "Total Encounters"
FROM encounters e
JOIN patients p ON e.patient_id = p.patient_id
GROUP BY Full_Name
ORDER BY COUNT(e.encounter_id) DESC;    
 

-- "List every paid encounter with patient name and DOS and paid amount - newest first"

SELECT 
	CONCAT(p.first_name, ' ', p.last_name) AS Patient_Name,
    e.dos AS Date_of_service,
    e.paid_amt AS Paid_amount
FROM encounters e
JOIN patients p ON e.patient_id = p.patient_id
WHERE e.status = "Paid"
ORDER BY Date_of_service DESC;

-- "Total Paid Amount by months - Monthly Trend"

SELECT 
		monthname(dos) AS months,
        SUM(paid_amt) AS Paid_Amount
 FROM encounters
 WHERE status = "Paid"
 GROUP BY months;
 
 
 -- "High Dollars visits;  flags encounters > 300$ as High Cost and show patient and procider name with amount "
 
 SELECT 
	CONCAT(p.first_name, ' ', p.last_name) AS Patient_Name,
    pr.provider_name As Provider_Name,
    e.paid_amt AS paid_amount,
    CASE WHEN e.paid_amt > 300 THEN "High Cost" ELSE "Standard"
    END AS "Cost_Flag"
from encounters e 
JOIN patients p ON e.patient_id = p.patient_id
JOIN providers pr ON e.provider_npi = pr.npi
WHERE e.status = "Paid";  


-- "Total Allowed amount (not paid) for each provider - highest First "

SELECT 
	pr.provider_name AS Provider,
    SUM(e.allowed_amt) As allowed_amount
from encounters e 
JOIN providers pr ON e.provider_npi = pr.npi
group by pr.provider_name
Order by allowed_amount DESC;

-- "Count how many encounters still have status = Pending"

SELECT COUNT(encounter_id)
FROM encounters 
WHERE status = "Pending";

-- "List every encounter in April 2024 that used CPT code 99213 - Show patient full name, Dos and paid amount"

SELECT 
		CONCAT(p.first_name, " ", p.last_name) AS Full_name,
        e.dos AS Date_of_service,
        e.paid_amt as paid_amount
FROM encounters e 
JOIN patients p ON e.patient_id = p.patient_id
WHERE month(e.dos) = 4 AND YEAR(e.dos) = 2024 AND  e.cpt_code = 99213;  

-- "Average paid amount for female patients vs male patients 9two rows)

SELECT 
	p.gender as Gender,
    ROUND(AVG(e.paid_amt),2) as Average_Paid_Amount
FROM encounters e 
JOIN patients p On e.patient_id = p.patient_id
WHERE e.status = "Paid"
GROUP BY Gender;
    
    
    
 -- "Show all encounter for patients who ever has a high cost (> 300) visit??"
 
SELECT e.encounter_id,
       CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
       e.dos,
       e.paid_amt
FROM encounters e
JOIN patients p ON e.patient_id = p.patient_id
WHERE e.patient_id IN (
        SELECT patient_id
        FROM encounters
        WHERE paid_amt > 300
      )
ORDER BY e.dos;


-- "Running Total Window:    List every Paid encounter with patient, amount, and a running total of paid amount ordered by DOS"

SELECT 
	e.encounter_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    e.dos,
    e.paid_amt,
    SUM(e.paid_amt) OVER (ORDER BY e.dos ROWS unbounded preceding) AS Running_total
FROm encounters e 
JOIN patients p ON e.patient_id = p.patient_id
WHERE e.status = "Paid";  


-- "rank Providers by Paid Amount"

SELECT 
	provider_name,
    total_paid,
    RANK() OVER(ORDER BY total_paid DESC) AS Ranking
FROM    
	(SELECT 
		pr.provider_name,
        SUM(e.paid_amt) as Total_paid
	FROM encounters e 
	JOIN providers pr On e.provider_npi = pr.npi
	WHERE e.status = "Paid"
	GROUP BY pr.provider_name
	)
AS Sub;


-- " For each paid encounter show encounter_id, patient_name, paid_amt, and the average paid amount of  that patient's own visits "      
       
SELECT
	encounter_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    e.paid_amt AS paid_amount,
    AVG(e.paid_amt) OVER (PARTITION BY p.patient_id) AS Patient_Avg
FROM encounters e 
JOIN patients p ON e.patient_id = p.patient_id
WHERE e.status = "Paid";


-- "Above Query is not soo good so the coorect version is here 

-- First Filter Paid Encounters by CTE then use Window Functions to get avg of each patient visit
 
WITH paid_enc AS (
    SELECT patient_id, encounter_id, paid_amt
    FROM   encounters
    WHERE  status = 'Paid'
)
SELECT  pe.encounter_id,
        CONCAT(p.first_name,' ',p.last_name) AS patient_name,
        pe.paid_amt,
        AVG(pe.paid_amt) OVER (PARTITION BY pe.patient_id) AS patient_avg
FROM    paid_enc pe
JOIN    patients p ON p.patient_id = pe.patient_id;

-- "List the Latest encounters per Providers - Show provider name, Dos, paid Amt"

SELECT 
	pr.provider_name AS Provider_Name,
    e.dos as DAte_of_service,
    e.paid_amt as Paid_Amount,
    ROW_NUMBER() OVER (PARTITION BY e.provider_npi ORDER BY e.dos DESC) = 1
FROM encounters e 
JOIN providers pr ON e.provider_npi = pr.npi;

-- the above Query is not as efficient 

-- here is the Best version
-- The Question was : List the Latest encounter (Last Dos) per provider with provider name, date of service and amount

WITH ranked AS (
	SELECT pr.provider_name,
		   e.dos,
           e.paid_amt,
		   ROW_NUMBER() OVER (PARTITION BY e.provider_npi ORDER BY e.dos DESC) AS rn
    FROM encounters e 
    JOIN providers pr ON e.provider_npi = pr.npi
)
SELECT provider_name, dos, paid_amt
FROM ranked 
WHERE rn = 1;

-- Rank all encounters by paid amount within each provider - show encounter id, provider name

WITH ranked AS (
		SELECT 
			  e.encounter_id,
              pr.provider_name,
              e.dos,
              e.paid_amt,
              RANK() OVER (PARTITION BY e.provider_npi ORDER BY e.paid_amt DESC) AS RRank
        FROM encounters e 
        JOIN providers pr ON e.provider_npi = pr.npi
 ) 
 SELECT encounter_id, 
        provider_name,
        paid_amt,
        RRank
from ranked;     


-- How many distinct patients has each provider ever seen ? 
       
  SELECT provider_name, 
         Distincted_count
  FROM (
  SELECT 
			 pr.provider_name,
             COUNT(DISTINCT e.patient_id) AS Distincted_count
        FROM encounters e 
        JOIN providers pr On e.provider_npi = pr.npi
        GROUP BY provider_name
) AS D;
  
  
  
  --  Show me the 5 Most Expensive individiual enconters ever billed and tell me how much each of those 5 contributed to the grand total revenue as a percentage
  
  WITH top5 AS (
		SELECT 
			encounter_id,
            patient_id,
            paid_amt
       FROM encounters 
       WHERE status = "Paid"
       ORDER BY paid_amt DESC
       LIMIT 5
 )
 SELECT 
		t.encounter_id,
        CONCAT(p.first_name, ' ', p.last_name) AS Patient_Name,
        t.paid_amt AS Paid_Amount,
        ROUND(t.paid_amt * 100 / SUM(t.paid_amt) OVER (), 2) AS pct_of_Total
 FROM top5 t
 JOIN patients p ON p.patient_id = t.patient_id;
  

 -- List every provider who did not bill any service in the last 30 days (from today)
 
 -- solution # 1
 SELECT 
	pr.provider_name
FROM providers pr 
WHERE npi NOT IN (
			SELECT DISTINCT provider_npi
            FROM encounters 
            WHERE dos >= CURDATE() -  INTERVAL 30 DAY
            );
 
  -- Solution # 2
  
  SELECT 
	pr.provider_name
FROM providers pr
LEFT JOIN encounters e ON e.provider_npi = pr.npi
AND e.dos >= CURDATE() - INTERVAL 30 day
WHERE e.provider_npi IS NULL;
             

 -- For each month of 2024 show the cumulative patients count (distinct patients seen up to that month)
 
WITH months AS (
    SELECT 1 AS month UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
),
monthly AS (
    SELECT MONTH(dos) AS month,
           COUNT(DISTINCT patient_id) AS new_pts
    FROM   encounters
    WHERE  YEAR(dos) = 2024
    GROUP  BY MONTH(dos)
)
SELECT m.month,
       COALESCE(mt.new_pts, 0) AS pts_this_month,
       SUM(COALESCE(mt.new_pts, 0)) OVER (ORDER BY m.month ROWS UNBOUNDED PRECEDING) AS cumulative_pts
FROM   months m
LEFT   JOIN monthly mt ON mt.month = m.month
ORDER BY m.month;
 
 
 -- Flag patients who had both a '99213' and a '99214' visit
 
 WITH patient_cpts AS (
    SELECT patient_id,
           CASE WHEN cpt_code = '99213' THEN 1 END AS has_99213,
           CASE WHEN cpt_code = '99214' THEN 1 END AS has_99214
    FROM   encounters
    WHERE  cpt_code IN ('99213','99214')
)
SELECT DISTINCT
       CONCAT(p.first_name,' ',p.last_name) AS patient_name
FROM   patient_cpts pc
JOIN   patients p ON p.patient_id = pc.patient_id
GROUP  BY pc.patient_id, patient_name
HAVING COUNT(DISTINCT pc.has_99213) = 1   -- saw 99213
   AND COUNT(DISTINCT pc.has_99214) = 1;  -- saw 99214
   
   
 
 -- Create a pivot-style report: rows = providers, columns = JAN, FEB, MAR etc values = Total paid amount per month and 0 if none -- 

SELECT pr.provider_name,
       COALESCE(SUM(CASE WHEN MONTH(e.dos)=1 THEN e.paid_amt END),0) AS Jan_2024,
       COALESCE(SUM(CASE WHEN MONTH(e.dos)=2 THEN e.paid_amt END),0) AS Feb_2024,
       COALESCE(SUM(CASE WHEN MONTH(e.dos)=3 THEN e.paid_amt END),0) AS Mar_2024,
       COALESCE(SUM(CASE WHEN MONTH(e.dos)=4 THEN e.paid_amt END),0) AS Apr_2024,
       SUM(e.paid_amt) AS Total_4_Months
FROM   providers pr
LEFT   JOIN encounters e ON e.provider_npi = pr.npi
                        AND e.status = 'Paid'
                        AND e.dos BETWEEN '2024-01-01' AND '2024-04-30'
GROUP  BY pr.provider_name
ORDER  BY pr.provider_name;
    

