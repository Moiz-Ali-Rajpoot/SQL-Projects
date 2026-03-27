-- ============================================================
-- SECTION 1: TABLE CREATION
-- ============================================================

CREATE TABLE hospital_data (
    available_rooms       INT,
    department            VARCHAR(100),
    ward_facility_code    VARCHAR(5),
    doctor_name           VARCHAR(100),
    staff_available       INT,
    patient_id            INT,
    patient_age           VARCHAR(20),   -- kept VARCHAR due to dirty data
    gender                VARCHAR(20),
    type_of_admission     VARCHAR(50),
    severity_of_illness   VARCHAR(50),
    health_conditions     VARCHAR(100),
    visitors_with_patient INT,
    insurance             VARCHAR(5),
    admission_deposit     DECIMAL(12,2),
    stay_in_days          INT
);


-- ============================================================
-- SECTION 2: DATA CLEANING
-- ============================================================

-- Q1: Inspect dirty Patient Age values (dates mixed with age ranges)
-- Business Purpose: Identify all invalid/inconsistent age entries before analysis
SELECT 
    patient_age,
    COUNT(*) AS occurrences
FROM hospital_data
WHERE patient_age NOT REGEXP '^[0-9]{2}-[0-9]{2}$'  -- Not in expected "21-30" format
GROUP BY patient_age
ORDER BY occurrences DESC;


-- Q2: Flag all records with dirty/invalid Patient Age
-- Business Purpose: Quantify how many records are affected by data quality issues
SELECT 
    COUNT(*) AS total_records,
    SUM(CASE WHEN patient_age NOT REGEXP '^[0-9]{2}-[0-9]{2}$' THEN 1 ELSE 0 END) AS dirty_age_records,
    ROUND(
        SUM(CASE WHEN patient_age NOT REGEXP '^[0-9]{2}-[0-9]{2}$' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS dirty_percentage
FROM hospital_data;


-- Q3: Create a cleaned view replacing dirty age values with NULL
-- Business Purpose: Build a reliable base for all age-based analytics without deleting raw data
CREATE OR REPLACE VIEW hospital_clean AS
SELECT 
    available_rooms,
    department,
    ward_facility_code,
    doctor_name,
    staff_available,
    patient_id,
    CASE 
        WHEN patient_age REGEXP '^[0-9]{2}-[0-9]{2}$' THEN patient_age
        ELSE NULL  -- Nullify dates and invalid formats
    END AS patient_age_clean,
    gender,
    type_of_admission,
    severity_of_illness,
    health_conditions,
    visitors_with_patient,
    insurance,
    admission_deposit,
    stay_in_days
FROM hospital_data;


-- Q4: Check for duplicate Patient IDs
-- Business Purpose: Ensure patient records are unique; duplicates may distort financial totals
SELECT 
    patient_id,
    COUNT(*) AS record_count
FROM hospital_data
GROUP BY patient_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- Q5: Check for NULL or empty values across critical columns
-- Business Purpose: Assess overall data completeness before building reports
SELECT
    SUM(CASE WHEN patient_id IS NULL THEN 1 ELSE 0 END)           AS null_patient_id,
    SUM(CASE WHEN department IS NULL OR department = '' THEN 1 ELSE 0 END) AS null_department,
    SUM(CASE WHEN doctor_name IS NULL OR doctor_name = '' THEN 1 ELSE 0 END) AS null_doctor,
    SUM(CASE WHEN gender IS NULL OR gender = '' THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN admission_deposit IS NULL THEN 1 ELSE 0 END)     AS null_deposit,
    SUM(CASE WHEN stay_in_days IS NULL THEN 1 ELSE 0 END)          AS null_stay
FROM hospital_data;


-- ============================================================
-- SECTION 3: OVERVIEW & SUMMARY ANALYTICS
-- ============================================================

-- Q6: Full hospital summary — top-level KPIs
-- Business Purpose: Give leadership a one-line snapshot of total operations
SELECT
    COUNT(*)                            AS total_records,
    COUNT(DISTINCT patient_id)          AS unique_patients,
    COUNT(DISTINCT doctor_name)         AS total_doctors,
    COUNT(DISTINCT department)          AS total_departments,
    ROUND(AVG(stay_in_days), 2)         AS avg_stay_days,
    ROUND(AVG(admission_deposit), 2)    AS avg_admission_deposit,
    ROUND(SUM(admission_deposit), 2)    AS total_revenue,
    SUM(CASE WHEN insurance = 'Yes' THEN 1 ELSE 0 END) AS insured_patients,
    SUM(CASE WHEN insurance = 'No'  THEN 1 ELSE 0 END) AS uninsured_patients
FROM hospital_data;


-- Q7: Patient distribution by Gender
-- Business Purpose: Understand demographic composition of patient intake
SELECT 
    gender,
    COUNT(*) AS total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM hospital_data
GROUP BY gender
ORDER BY total_patients DESC;


-- Q8: Patient distribution by Age Group
-- Business Purpose: Identify which age segments are most frequently admitted
SELECT 
    patient_age_clean AS age_group,
    COUNT(*) AS total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM hospital_clean
WHERE patient_age_clean IS NOT NULL
GROUP BY patient_age_clean
ORDER BY total_patients DESC;


-- Q9: Admission type breakdown
-- Business Purpose: Understand the split between Trauma, Emergency, and Urgent cases
SELECT 
    type_of_admission,
    COUNT(*) AS total_cases,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(AVG(admission_deposit), 2) AS avg_deposit,
    ROUND(AVG(stay_in_days), 2)      AS avg_stay_days
FROM hospital_data
GROUP BY type_of_admission
ORDER BY total_cases DESC;


-- Q10: Severity of illness breakdown
-- Business Purpose: Measure what proportion of cases are critical vs moderate vs minor
SELECT 
    severity_of_illness,
    COUNT(*) AS total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(AVG(stay_in_days), 2)      AS avg_stay_days,
    ROUND(AVG(admission_deposit), 2) AS avg_deposit
FROM hospital_data
GROUP BY severity_of_illness
ORDER BY total_patients DESC;


-- ============================================================
-- SECTION 4: DEPARTMENT & WARD ANALYTICS
-- ============================================================

-- Q11: Patient volume and revenue by Department
-- Business Purpose: Identify highest-traffic and highest-revenue departments
SELECT 
    department,
    COUNT(*) AS total_patients,
    ROUND(SUM(admission_deposit), 2)  AS total_revenue,
    ROUND(AVG(admission_deposit), 2)  AS avg_deposit,
    ROUND(AVG(stay_in_days), 2)       AS avg_stay_days,
    ROUND(AVG(available_rooms), 2)    AS avg_available_rooms
FROM hospital_data
GROUP BY department
ORDER BY total_revenue DESC;


-- Q12: Ward Facility Code performance comparison
-- Business Purpose: Compare wards by patient load, severity, and revenue
SELECT 
    ward_facility_code,
    COUNT(*) AS total_patients,
    ROUND(SUM(admission_deposit), 2)  AS total_revenue,
    ROUND(AVG(stay_in_days), 2)       AS avg_stay_days,
    SUM(CASE WHEN severity_of_illness = 'Extreme' THEN 1 ELSE 0 END) AS extreme_cases
FROM hospital_data
GROUP BY ward_facility_code
ORDER BY total_patients DESC;


-- Q13: Department-wise severity distribution
-- Business Purpose: Understand which departments handle the most critical cases
SELECT 
    department,
    severity_of_illness,
    COUNT(*) AS total_cases
FROM hospital_data
GROUP BY department, severity_of_illness
ORDER BY department, total_cases DESC;


-- Q14: Available rooms vs patient load by Department
-- Business Purpose: Detect departments where room availability may be critically low
SELECT 
    department,
    ROUND(AVG(available_rooms), 1)  AS avg_available_rooms,
    COUNT(*)                         AS total_admissions,
    ROUND(AVG(staff_available), 1)  AS avg_staff
FROM hospital_data
GROUP BY department
ORDER BY avg_available_rooms ASC;


-- ============================================================
-- SECTION 5: DOCTOR PERFORMANCE ANALYTICS
-- ============================================================

-- Q15: Top doctors by patient volume and total revenue generated
-- Business Purpose: Identify highest-performing doctors driving hospital revenue
SELECT 
    doctor_name,
    COUNT(*)                          AS total_patients,
    ROUND(SUM(admission_deposit), 2)  AS total_revenue,
    ROUND(AVG(admission_deposit), 2)  AS avg_deposit_per_patient,
    ROUND(AVG(stay_in_days), 2)       AS avg_patient_stay,
    COUNT(DISTINCT department)        AS departments_covered
FROM hospital_data
GROUP BY doctor_name
ORDER BY total_revenue DESC;


-- Q16: Doctor workload — patients per doctor per department
-- Business Purpose: Detect overloaded doctors and flag potential burnout risks
SELECT 
    doctor_name,
    department,
    COUNT(*) AS patient_count,
    ROUND(AVG(staff_available), 1) AS avg_staff_support,
    ROUND(AVG(stay_in_days), 2)    AS avg_stay_days
FROM hospital_data
GROUP BY doctor_name, department
ORDER BY patient_count DESC;


-- Q17: Doctor performance by severity of cases handled
-- Business Purpose: Understand which doctors are managing the most critical patient load
SELECT 
    doctor_name,
    SUM(CASE WHEN severity_of_illness = 'Extreme'  THEN 1 ELSE 0 END) AS extreme_cases,
    SUM(CASE WHEN severity_of_illness = 'Moderate' THEN 1 ELSE 0 END) AS moderate_cases,
    SUM(CASE WHEN severity_of_illness = 'Minor'    THEN 1 ELSE 0 END) AS minor_cases,
    COUNT(*) AS total_cases
FROM hospital_data
GROUP BY doctor_name
ORDER BY extreme_cases DESC;


-- ============================================================
-- SECTION 6: FINANCIAL ANALYTICS
-- ============================================================

-- Q18: Total and average admission deposit by Department
-- Business Purpose: Financial planning — identify revenue contribution per department
SELECT 
    department,
    ROUND(SUM(admission_deposit), 2)    AS total_revenue,
    ROUND(AVG(admission_deposit), 2)    AS avg_deposit,
    ROUND(MIN(admission_deposit), 2)    AS min_deposit,
    ROUND(MAX(admission_deposit), 2)    AS max_deposit,
    COUNT(*)                            AS total_patients
FROM hospital_data
GROUP BY department
ORDER BY total_revenue DESC;


-- Q19: Insurance vs Non-Insurance patient financial comparison
-- Business Purpose: Understand revenue and stay differences between insured and uninsured patients
SELECT 
    insurance,
    COUNT(*)                            AS total_patients,
    ROUND(SUM(admission_deposit), 2)    AS total_revenue,
    ROUND(AVG(admission_deposit), 2)    AS avg_deposit,
    ROUND(AVG(stay_in_days), 2)         AS avg_stay_days
FROM hospital_data
GROUP BY insurance
ORDER BY total_revenue DESC;


-- Q20: Revenue segmentation by Admission Type and Severity
-- Business Purpose: Understand which case combinations drive the highest costs
SELECT 
    type_of_admission,
    severity_of_illness,
    COUNT(*)                            AS total_cases,
    ROUND(SUM(admission_deposit), 2)    AS total_revenue,
    ROUND(AVG(admission_deposit), 2)    AS avg_deposit,
    ROUND(AVG(stay_in_days), 2)         AS avg_stay_days
FROM hospital_data
GROUP BY type_of_admission, severity_of_illness
ORDER BY total_revenue DESC;


-- Q21: High-value patients — Top 10 highest admission deposits
-- Business Purpose: Identify high-revenue cases for premium care resource allocation
SELECT 
    patient_id,
    doctor_name,
    department,
    type_of_admission,
    severity_of_illness,
    health_conditions,
    stay_in_days,
    admission_deposit
FROM hospital_data
ORDER BY admission_deposit DESC
LIMIT 10;


-- Q22: Revenue by Health Condition
-- Business Purpose: Understand which chronic conditions generate the most hospital revenue
SELECT 
    health_conditions,
    COUNT(*)                            AS total_patients,
    ROUND(SUM(admission_deposit), 2)    AS total_revenue,
    ROUND(AVG(admission_deposit), 2)    AS avg_deposit,
    ROUND(AVG(stay_in_days), 2)         AS avg_stay_days
FROM hospital_data
WHERE health_conditions IS NOT NULL AND health_conditions != ''
GROUP BY health_conditions
ORDER BY total_revenue DESC;


-- ============================================================
-- SECTION 7: PATIENT STAY & OPERATIONAL ANALYTICS
-- ============================================================

-- Q23: Average length of stay by Department and Severity
-- Business Purpose: Optimize bed allocation and predict discharge timelines
SELECT 
    department,
    severity_of_illness,
    ROUND(AVG(stay_in_days), 2)  AS avg_stay,
    MAX(stay_in_days)            AS max_stay,
    MIN(stay_in_days)            AS min_stay,
    COUNT(*)                     AS total_patients
FROM hospital_data
GROUP BY department, severity_of_illness
ORDER BY avg_stay DESC;


-- Q24: Long-stay patients (above average) — potential resource drain analysis
-- Business Purpose: Flag patients with unusually long stays for case review
SELECT 
    patient_id,
    doctor_name,
    department,
    severity_of_illness,
    health_conditions,
    stay_in_days,
    admission_deposit
FROM hospital_data
WHERE stay_in_days > (SELECT AVG(stay_in_days) FROM hospital_data)
ORDER BY stay_in_days DESC
LIMIT 20;


-- Q25: Visitor analysis — average visitors by Admission Type
-- Business Purpose: Understand visitor load per admission type for facility planning
SELECT 
    type_of_admission,
    ROUND(AVG(visitors_with_patient), 2) AS avg_visitors,
    MAX(visitors_with_patient)           AS max_visitors,
    COUNT(*)                             AS total_patients
FROM hospital_data
GROUP BY type_of_admission
ORDER BY avg_visitors DESC;


-- Q26: Staff availability vs patient severity — staffing gap analysis
-- Business Purpose: Identify wards where staff levels are insufficient for patient severity
SELECT 
    department,
    ward_facility_code,
    severity_of_illness,
    ROUND(AVG(staff_available), 1)  AS avg_staff,
    COUNT(*)                        AS total_patients,
    ROUND(COUNT(*) / AVG(staff_available), 1) AS patients_per_staff_ratio
FROM hospital_data
WHERE staff_available > 0
GROUP BY department, ward_facility_code, severity_of_illness
ORDER BY patients_per_staff_ratio DESC;


-- ============================================================
-- SECTION 8: HEALTH CONDITIONS & CLINICAL ANALYTICS
-- ============================================================

-- Q27: Most common health conditions across all patients
-- Business Purpose: Drive resource planning and specialist allocation by condition prevalence
SELECT 
    health_conditions,
    COUNT(*) AS total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(AVG(stay_in_days), 2)       AS avg_stay,
    ROUND(AVG(admission_deposit), 2)  AS avg_deposit
FROM hospital_data
WHERE health_conditions IS NOT NULL AND health_conditions != ''
GROUP BY health_conditions
ORDER BY total_patients DESC;


-- Q28: Health condition vs Severity of Illness cross-analysis
-- Business Purpose: Identify which conditions most frequently lead to extreme severity cases
SELECT 
    health_conditions,
    severity_of_illness,
    COUNT(*) AS total_cases,
    ROUND(AVG(stay_in_days), 2) AS avg_stay
FROM hospital_data
WHERE health_conditions IS NOT NULL AND health_conditions != ''
GROUP BY health_conditions, severity_of_illness
ORDER BY health_conditions, total_cases DESC;


-- Q29: Gender vs Health Condition distribution
-- Business Purpose: Detect gender-specific health condition patterns for targeted care programs
SELECT 
    gender,
    health_conditions,
    COUNT(*) AS total_patients,
    ROUND(AVG(stay_in_days), 2) AS avg_stay_days
FROM hospital_data
WHERE health_conditions IS NOT NULL AND health_conditions != ''
GROUP BY gender, health_conditions
ORDER BY gender, total_patients DESC;


-- ============================================================
-- SECTION 9: ADVANCED ANALYTICS (CTEs, Window Functions, Subqueries)
-- ============================================================

-- Q30: Rank doctors by total revenue using Window Function (RANK)
-- Business Purpose: Create a performance leaderboard of doctors by revenue contribution
SELECT 
    doctor_name,
    department,
    total_revenue,
    total_patients,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY total_patients DESC) AS volume_rank
FROM (
    SELECT 
        doctor_name,
        department,
        ROUND(SUM(admission_deposit), 2) AS total_revenue,
        COUNT(*) AS total_patients
    FROM hospital_data
    GROUP BY doctor_name, department
) AS doctor_summary;


-- Q31: CTE — Identify departments performing above average revenue
-- Business Purpose: Benchmark departments against hospital-wide average revenue
WITH dept_revenue AS (
    SELECT 
        department,
        ROUND(SUM(admission_deposit), 2) AS total_revenue,
        COUNT(*) AS total_patients
    FROM hospital_data
    GROUP BY department
),
avg_revenue AS (
    SELECT ROUND(AVG(total_revenue), 2) AS hospital_avg_revenue
    FROM dept_revenue
)
SELECT 
    d.department,
    d.total_revenue,
    d.total_patients,
    a.hospital_avg_revenue,
    CASE 
        WHEN d.total_revenue > a.hospital_avg_revenue THEN 'Above Average'
        ELSE 'Below Average'
    END AS performance_flag
FROM dept_revenue d
CROSS JOIN avg_revenue a
ORDER BY d.total_revenue DESC;


-- Q32: CTE — Patient risk scoring based on severity, stay, and health condition
-- Business Purpose: Triage high-risk patients by combining multiple clinical indicators
WITH risk_score AS (
    SELECT 
        patient_id,
        doctor_name,
        department,
        severity_of_illness,
        health_conditions,
        stay_in_days,
        admission_deposit,
        CASE severity_of_illness
            WHEN 'Extreme'  THEN 3
            WHEN 'Moderate' THEN 2
            WHEN 'Minor'    THEN 1
            ELSE 0
        END +
        CASE WHEN stay_in_days > 20 THEN 2 ELSE 0 END +
        CASE WHEN health_conditions IN ('Diabetes', 'Heart disease') THEN 2 ELSE 0 END +
        CASE WHEN insurance = 'No' THEN 1 ELSE 0 END
        AS risk_score
    FROM hospital_data
)
SELECT *,
    CASE 
        WHEN risk_score >= 6 THEN 'Critical Risk'
        WHEN risk_score >= 4 THEN 'High Risk'
        WHEN risk_score >= 2 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS risk_category
FROM risk_score
ORDER BY risk_score DESC
LIMIT 25;


-- Q33: Running total of revenue by Department using Window Function
-- Business Purpose: Track cumulative revenue contribution as departments are ranked
SELECT 
    department,
    total_revenue,
    SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS running_total_revenue,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER(), 2) AS revenue_share_pct
FROM (
    SELECT 
        department,
        ROUND(SUM(admission_deposit), 2) AS total_revenue
    FROM hospital_data
    GROUP BY department
) AS dept_totals
ORDER BY total_revenue DESC;


-- Q34: Percentile bucketing of patients by Admission Deposit using NTILE
-- Business Purpose: Segment patients into deposit quartiles for financial analysis
SELECT 
    patient_id,
    department,
    doctor_name,
    admission_deposit,
    NTILE(4) OVER (ORDER BY admission_deposit) AS deposit_quartile,
    CASE NTILE(4) OVER (ORDER BY admission_deposit)
        WHEN 1 THEN 'Low Deposit (Bottom 25%)'
        WHEN 2 THEN 'Mid-Low Deposit'
        WHEN 3 THEN 'Mid-High Deposit'
        WHEN 4 THEN 'High Deposit (Top 25%)'
    END AS deposit_segment
FROM hospital_data
ORDER BY admission_deposit DESC
LIMIT 30;


-- Q35: Department monthly/operational summary with CASE WHEN categorization
-- Business Purpose: Classify departments by operational load for resource prioritization
SELECT 
    department,
    COUNT(*) AS total_patients,
    ROUND(AVG(stay_in_days), 2) AS avg_stay,
    ROUND(AVG(available_rooms), 1) AS avg_rooms,
    ROUND(SUM(admission_deposit), 2) AS total_revenue,
    CASE 
        WHEN COUNT(*) > 10000 THEN 'High Volume'
        WHEN COUNT(*) BETWEEN 5000 AND 10000 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END AS volume_category,
    CASE 
        WHEN AVG(available_rooms) < 2 THEN 'Critical Room Shortage'
        WHEN AVG(available_rooms) BETWEEN 2 AND 4 THEN 'Low Availability'
        ELSE 'Adequate Rooms'
    END AS room_status
FROM hospital_data
GROUP BY department
ORDER BY total_patients DESC;


-- Q36: Subquery — Patients who stayed longer than their department's average
-- Business Purpose: Flag outlier long-stay patients within each department
SELECT 
    h.patient_id,
    h.doctor_name,
    h.department,
    h.severity_of_illness,
    h.stay_in_days,
    dept_avg.avg_dept_stay,
    ROUND(h.stay_in_days - dept_avg.avg_dept_stay, 2) AS days_above_avg
FROM hospital_data h
JOIN (
    SELECT department, ROUND(AVG(stay_in_days), 2) AS avg_dept_stay
    FROM hospital_data
    GROUP BY department
) AS dept_avg ON h.department = dept_avg.department
WHERE h.stay_in_days > dept_avg.avg_dept_stay
ORDER BY days_above_avg DESC
LIMIT 20;


-- Q37: Insurance coverage rate by Department and Health Condition
-- Business Purpose: Identify which departments and conditions have highest uninsured patient risk
SELECT 
    department,
    health_conditions,
    COUNT(*) AS total_patients,
    SUM(CASE WHEN insurance = 'Yes' THEN 1 ELSE 0 END) AS insured,
    SUM(CASE WHEN insurance = 'No'  THEN 1 ELSE 0 END) AS uninsured,
    ROUND(SUM(CASE WHEN insurance = 'No' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS uninsured_rate_pct
FROM hospital_data
WHERE health_conditions IS NOT NULL AND health_conditions != ''
GROUP BY department, health_conditions
ORDER BY uninsured_rate_pct DESC;


-- ============================================================
-- BONUS QUERIES
-- ============================================================

-- Q38: Full operational scorecard per Doctor
-- Business Purpose: One unified view of each doctor's clinical and financial performance
SELECT 
    doctor_name,
    COUNT(*)                                                            AS total_patients,
    ROUND(SUM(admission_deposit), 2)                                    AS total_revenue,
    ROUND(AVG(admission_deposit), 2)                                    AS avg_deposit,
    ROUND(AVG(stay_in_days), 2)                                         AS avg_stay,
    SUM(CASE WHEN severity_of_illness = 'Extreme'  THEN 1 ELSE 0 END)  AS extreme_cases,
    SUM(CASE WHEN insurance = 'Yes' THEN 1 ELSE 0 END)                 AS insured_patients,
    SUM(CASE WHEN insurance = 'No'  THEN 1 ELSE 0 END)                 AS uninsured_patients,
    ROUND(AVG(visitors_with_patient), 1)                               AS avg_visitors,
    ROUND(AVG(staff_available), 1)                                     AS avg_staff_support
FROM hospital_data
GROUP BY doctor_name
ORDER BY total_revenue DESC;


-- Q39: Room availability crisis detection — Departments with critically low rooms
-- Business Purpose: Alert hospital management to departments at risk of room shortage
SELECT 
    department,
    ward_facility_code,
    MIN(available_rooms)           AS min_rooms_recorded,
    ROUND(AVG(available_rooms), 1) AS avg_available_rooms,
    COUNT(*)                       AS admissions_in_period,
    SUM(CASE WHEN available_rooms <= 1 THEN 1 ELSE 0 END) AS critical_low_room_events
FROM hospital_data
GROUP BY department, ward_facility_code
HAVING critical_low_room_events > 0
ORDER BY critical_low_room_events DESC;


-- Q40: Final executive summary — Complete hospital performance overview
-- Business Purpose: Single-query executive dashboard for leadership reporting
SELECT
    COUNT(*)                                                              AS total_admissions,
    COUNT(DISTINCT patient_id)                                            AS unique_patients,
    COUNT(DISTINCT doctor_name)                                           AS total_doctors,
    COUNT(DISTINCT department)                                            AS total_departments,
    ROUND(SUM(admission_deposit), 2)                                      AS total_revenue,
    ROUND(AVG(admission_deposit), 2)                                      AS avg_deposit_per_patient,
    ROUND(AVG(stay_in_days), 2)                                           AS avg_length_of_stay,
    SUM(CASE WHEN severity_of_illness = 'Extreme'  THEN 1 ELSE 0 END)    AS extreme_cases,
    SUM(CASE WHEN severity_of_illness = 'Moderate' THEN 1 ELSE 0 END)    AS moderate_cases,
    SUM(CASE WHEN severity_of_illness = 'Minor'    THEN 1 ELSE 0 END)    AS minor_cases,
    SUM(CASE WHEN insurance = 'Yes' THEN 1 ELSE 0 END)                   AS insured_patients,
    SUM(CASE WHEN insurance = 'No'  THEN 1 ELSE 0 END)                   AS uninsured_patients,
    SUM(CASE WHEN type_of_admission = 'Emergency' THEN 1 ELSE 0 END)     AS emergency_admissions,
    SUM(CASE WHEN type_of_admission = 'Trauma'    THEN 1 ELSE 0 END)     AS trauma_admissions,
    SUM(CASE WHEN type_of_admission = 'Urgent'    THEN 1 ELSE 0 END)     AS urgent_admissions,
    ROUND(AVG(available_rooms), 1)                                        AS avg_available_rooms,
    ROUND(AVG(staff_available), 1)                                        AS avg_staff_per_admission
FROM hospital_data;