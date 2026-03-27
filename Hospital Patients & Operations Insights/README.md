# 🏥 Hospital Patient & Operations Analytics — SQL (MySQL)

> **End-to-End Hospital Data Analytics using SQL** 40+ production-quality MySQL queries covering data cleaning, patient analytics, department performance, doctor scorecards, financial analysis, clinical insights, and advanced analytics using CTEs, Window Functions, and Subqueries on a dataset of 50,000+ hospital patient records.

---

## 🗂️ Dataset Overview

| Column | Description |
|---|---|
| `available_rooms_in_hospital` | Number of rooms available at time of admission |
| `department` | Hospital department (Gynecology, Anesthesia, Radiotherapy, etc.) |
| `ward_facility_code` | Ward identifier (A, B, D, E, F) |
| `doctor_name` | Attending doctor |
| `staff_available` | Number of staff on duty |
| `patient_id` | Unique patient identifier |
| `patient_age` | Age group — contains dirty data (dates mixed with ranges) |
| `gender` | Female, Male, Other |
| `type_of_admission` | Trauma, Emergency, Urgent |
| `severity_of_illness` | Extreme, Moderate, Minor |
| `health_conditions` | Diabetes, Heart Disease, Asthma, High Blood Pressure, etc. |
| `visitors_with_patient` | Number of visitors accompanying the patient |
| `insurance` | Yes / No |
| `admission_deposit` | Deposit amount collected at admission |
| `stay_in_days` | Total length of hospital stay |

**Total Records:** 50,000+
**Database:** MySQL

---

## 🧹 Data Quality Issues Addressed

- `patient_age` column contains **mixed data** valid age range strings (e.g., `21-30`) mixed with **date values** identified, flagged, and cleaned using a `CREATE VIEW` approach that nullifies invalid entries without deleting raw data
- Duplicate `patient_id` detection
- NULL and empty value audit across all critical columns
- Data completeness percentage reporting

---

## 📊 Queries & Business Insights Covered

### Section 1 — Table Creation
- `CREATE TABLE` with appropriate data types including VARCHAR for dirty age column

### Section 2 — Data Cleaning (Q1–Q5)
| # | Query | Business Question |
|---|---|---|
| Q1 | Inspect dirty age values | What invalid entries exist in Patient Age? |
| Q2 | Quantify dirty records | What % of records have data quality issues? |
| Q3 | Create cleaned view | How do we safely clean data without losing raw records? |
| Q4 | Duplicate patient IDs | Are there duplicate patient records inflating our counts? |
| Q5 | NULL value audit | How complete is our dataset across critical fields? |

### Section 3 — Overview & Summary (Q6–Q10)
| # | Query | Business Question |
|---|---|---|
| Q6 | Hospital KPI summary | What are our top-level operational and financial metrics? |
| Q7 | Patient gender distribution | What is the gender breakdown of admitted patients? |
| Q8 | Patient age group distribution | Which age groups are most frequently admitted? |
| Q9 | Admission type breakdown | What is the split between Trauma, Emergency, and Urgent cases? |
| Q10 | Severity of illness breakdown | What proportion of cases are critical vs moderate vs minor? |

### Section 4 — Department & Ward Analytics (Q11–Q14)
| # | Query | Business Question |
|---|---|---|
| Q11 | Revenue & volume by Department | Which departments generate the most revenue and patient volume? |
| Q12 | Ward Facility performance | How do wards compare on patient load, severity, and revenue? |
| Q13 | Department severity distribution | Which departments handle the most extreme cases? |
| Q14 | Rooms vs patient load | Which departments are at risk of room shortages? |

### Section 5 — Doctor Performance Analytics (Q15–Q17)
| # | Query | Business Question |
|---|---|---|
| Q15 | Top doctors by revenue | Which doctors are driving the most hospital revenue? |
| Q16 | Doctor workload analysis | Are any doctors overloaded relative to available staff? |
| Q17 | Doctors by case severity | Which doctors manage the most critical patient load? |

### Section 6 — Financial Analytics (Q18–Q22)
| # | Query | Business Question |
|---|---|---|
| Q18 | Revenue by Department | What is each department's financial contribution? |
| Q19 | Insurance vs Non-insurance | How do insured and uninsured patients differ financially? |
| Q20 | Revenue by Admission × Severity | Which case combinations drive the highest costs? |
| Q21 | Top 10 highest deposits | Which patients generated the most revenue? |
| Q22 | Revenue by Health Condition | Which chronic conditions generate the most hospital revenue? |

### Section 7 — Patient Stay & Operations (Q23–Q26)
| # | Query | Business Question |
|---|---|---|
| Q23 | Avg stay by Dept & Severity | How long do patients stay across departments and severity levels? |
| Q24 | Long-stay patient detection | Which patients have abnormally long stays requiring case review? |
| Q25 | Visitor load by admission type | How many visitors accompany different admission types? |
| Q26 | Staff vs severity gap analysis | Are staff levels adequate relative to patient severity per ward? |

### Section 8 — Health Conditions & Clinical (Q27–Q29)
| # | Query | Business Question |
|---|---|---|
| Q27 | Most common health conditions | Which conditions are most prevalent across all admissions? |
| Q28 | Condition vs Severity crossanalysis | Which health conditions most frequently lead to extreme severity? |
| Q29 | Gender vs Health Condition | Are there gender-specific health condition patterns? |

### Section 9 — Advanced Analytics (Q30–Q37)
| # | Query | Technique |
|---|---|---|
| Q30 | Doctor revenue leaderboard | **Window Function — RANK()** |
| Q31 | Departments above average revenue | **CTE — Benchmarking** |
| Q32 | Patient risk scoring model | **CTE — Multi-factor CASE WHEN scoring** |
| Q33 | Running revenue total by Dept | **Window Function — SUM() OVER()** |
| Q34 | Deposit quartile segmentation | **Window Function — NTILE(4)** |
| Q35 | Department operational scorecard | **CASE WHEN categorization** |
| Q36 | Patients above dept avg stay | **Correlated Subquery — JOIN** |
| Q37 | Insurance gap by Dept & Condition | **Conditional aggregation** |

### Bonus Queries (Q38–Q40)
| # | Query | Business Question |
|---|---|---|
| Q38 | Full doctor scorecard | One unified clinical + financial view per doctor |
| Q39 | Room crisis detection | Which departments recorded critically low room availability? |
| Q40 | Executive summary | Single-query hospital-wide performance dashboard for leadership |

---

## 💡 Key Business Problems Solved

- 📋 **Data Quality** — Detect, quantify, and clean inconsistent patient age data without data loss
- 🏢 **Department Planning** — Identify overloaded departments with low room availability and high severity cases
- 👨‍⚕️ **Doctor Performance** — Rank doctors by revenue, volume, and critical case load for performance reviews
- 💰 **Financial Intelligence** — Understand revenue drivers by department, condition, admission type, and insurance status
- 🏥 **Clinical Risk Management** — Score and triage high-risk patients using multi-factor risk models
- 📊 **Operational Efficiency** — Flag long-stay outliers, staffing gaps, and room shortage events
- 🔍 **Executive Reporting** — Single-query summary delivering a complete hospital KPI snapshot

---

## 🛠️ SQL Techniques Used

| Technique | Queries |
|---|---|
| `CREATE TABLE` / `CREATE VIEW` | Q1–Q3 |
| `GROUP BY` + Aggregations | Q6–Q22 |
| `CASE WHEN` | Q2, Q3, Q6, Q32, Q35, Q37, Q38, Q40 |
| `Window Functions — RANK(), SUM() OVER(), NTILE()` | Q30, Q33, Q34 |
| `CTEs (WITH clause)` | Q31, Q32 |
| `Subqueries & JOIN` | Q36 |
| `REGEXP` for data validation | Q1, Q2, Q3 |
| `HAVING` clause | Q4, Q39 |
| `CROSS JOIN` | Q31 |
| `LIMIT` for Top-N analysis | Q21, Q24, Q32, Q36 |

---

## ▶️ How to Use

```sql
-- Step 1: Create the table
-- Run the CREATE TABLE statement at the top of the .sql file

-- Step 2: Import the dataset
-- Import the Excel/CSV file into MySQL using MySQL Workbench Import Wizard
-- or use: LOAD DATA INFILE 'hospital_data.csv' INTO TABLE hospital_data ...

-- Step 3: Run cleaning queries first (Q1–Q5)
-- Step 4: Run analytics queries in any order (Q6–Q40)
```

---

## 📁 Files in This Repository

| File | Description |
|---|---|
| `hospital_analytics.sql` | All 40 SQL queries with comments |
| `hospital_data.xlsx` | Raw dataset (50,000+ records) |
| `README.md` | Project documentation |

---

> 📌 **Note:** Dataset contains dummy/sample data for demonstration and learning purposes. All patient names and identifiers are fictional.
