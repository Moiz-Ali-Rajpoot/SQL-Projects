# 🏥 Healthcare Appointments Analytics SQL Project

![MySQL](https://img.shields.io/badge/MySQL-8.0-blue.svg)
![Analytics](https://img.shields.io/badge/Analytics-Advanced-green.svg)
![Healthcare](https://img.shields.io/badge/Domain-Healthcare-red.svg)

## 📋 Project Overview

This repository contains a comprehensive SQL analytics suite for healthcare appointment data analysis. It transforms raw appointment scheduling data into actionable business intelligence through 30+ production-ready SQL queries covering operational metrics, patient behavior analysis, provider performance, and strategic insights.

### 🎯 Key Objectives
- **Operational Excellence**: Monitor daily performance and identify bottlenecks
- **Patient Retention**: Predict no-shows and identify at-risk patients
- **Provider Optimization**: Balance workloads and maximize utilization
- **Financial Intelligence**: Track revenue capture and identify leakage
- **Strategic Planning**: Forecast demand and optimize service lines

---

## 🗃️ Database Schema

### Table Structure
```sql
CREATE TABLE appointments (
    appointment_id INT PRIMARY KEY,
    appointment_date DATE NOT NULL,
    appointment_time VARCHAR(50),
    app_start_time TIME,
    app_end_time TIME,
    patient_name VARCHAR(255) NOT NULL,
    patient_dob DATE,
    provider_name VARCHAR(255) NOT NULL,
    service_location VARCHAR(255),
    appointment_reason VARCHAR(255),
    appointment_status VARCHAR(50),
    reason_category VARCHAR(100),
    duration_minutes INT GENERATED ALWAYS AS (
        TIMESTAMPDIFF(MINUTE, 
            CONCAT(appointment_date, ' ', app_start_time),
            CONCAT(appointment_date, ' ', app_end_time)
        )
    ) STORED
);
```

### Index Strategy
| Index Name | Column(s) | Purpose |
|------------|-----------|---------|
| `idx_date` | `appointment_date` | Time-series query optimization, date filtering |
| `idx_provider` | `provider_name` | Provider performance analysis, workload balancing |
| `idx_status` | `appointment_status` | Status aggregation, completion rate calculations |
| `idx_location` | `service_location` | Multi-location benchmarking, market share analysis |
| `idx_category` | `reason_category` | Service line profitability, specialization tracking |

> **Performance Note**: These indexes support the 30+ analytical queries by enabling fast filtering on high-cardinality dimensions and preventing full table scans on date range queries.

---

## 📊 Query Categories & Business Value

### 1️⃣ Operational Dashboard Queries (1-3)
**Purpose**: Real-time operational monitoring for clinic managers

| Query | Business Question | Key Insight |
|-------|----------------|-------------|
| **Daily Summary** | What is today's appointment overview? | Completion rates, cancellation alerts |
| **Provider Utilization** | Who has the busiest schedules? | Overtime planning, resource allocation |
| **Status Transitions** | How many appointments changed status? | Pattern detection in disruptions |

**Advanced Techniques Used**:
- Conditional aggregation (`CASE WHEN` for status pivoting)
- Window functions (`LAG()` for day-over-day trends)
- Date arithmetic for rolling periods

**Sample Output**:
```sql
-- Daily KPI Dashboard
appointment_date | total_appointments | completion_rate_pct | change_alert
2025-01-02       | 45               | 82.50               | Normal Variance
2025-01-03       | 38               | 65.00               | Significant Change ⚠️
```

---

### 2️⃣ Patient Behavior & Retention Analysis (4-6)
**Purpose**: Predict no-shows and identify at-risk patients

| Query | Algorithm | Actionable Output |
|-------|-----------|-------------------|
| **No-Show Risk Scoring** | Weighted historical behavior score | Priority list for confirmation calls |
| **Patient Lifetime Value** | Visit frequency × tenure × diversity | VIP identification, churn prediction |
| **Demographic Patterns** | Age cohort comparison | Tailored reminder strategies |

**Risk Scoring Formula**:
```sql
Reliability Score = 
    (Completed % × 100) - 
    (No-Shows × 25) - 
    (Cancellations × 10) - 
    (Reschedules × 5)
```

**Risk Categories**:
- 🔴 **HIGH RISK**: 2+ no-shows or >30% no-show rate
- 🟡 **MEDIUM RISK**: 3+ cancellations or >25% cancellation rate  
- 🟢 **LOW RISK**: Reliable attendance history

---

### 3️⃣ Provider Performance & Productivity (7-9)
**Purpose**: Optimize provider productivity and prevent burnout

| Query | Metric | Usage |
|-------|--------|-------|
| **Productivity Scorecard** | Composite 0-100 score | Performance reviews, bonus calculations |
| **Schedule Density** | Hourly slot analysis | Bottleneck identification |
| **Specialization Match** | Volume vs. primary specialty | Training needs assessment |

**Productivity Score Formula**:
```sql
Score = (Completed_Visits × 0.40) +           -- Volume (40%)
        (Completion_Rate × 0.30) +            -- Reliability (30%)
        (Hours_Worked × 0.20) +               -- Capacity (20%)
        (Service_Diversity × 2 × 0.10)          -- Versatility (10%)
```

**Performance Tiers**:
- ⭐ **Top Performer**: 50+ visits, 85%+ completion rate
- ✅ **Meeting Targets**: 30+ visits, 75%+ completion rate  
- ⚠️ **Needs Improvement**: <60% completion rate

---

### 4️⃣ Service Line & Revenue Optimization (10-12)
**Purpose**: Maximize profitability and operational efficiency

| Query | Financial Impact | Decision Support |
|-------|-----------------|----------------|
| **Category Profitability** | Revenue realization vs. leakage | Service expansion/contraction |
| **Duration Accuracy** | Scheduled vs. actual variance | Template optimization |
| **Location Benchmarking** | Multi-site performance comparison | Resource reallocation |

**Revenue Calculation** (Customizable rates):
```sql
Estimated_Revenue = 
    SUM(CASE status 
        WHEN 'Checked Out' THEN service_rate 
        ELSE 0 
    END)
```

**Key Insight Example**:
> "Occupational Therapy shows 12-minute average overruns. Increasing slot duration from 60→75 minutes could improve completion rates by 8% and capture $15K additional monthly revenue."

---

### 5️⃣ Time-Series & Trend Analysis (13-15)
**Purpose**: Forecast demand and optimize scheduling

| Query | Technique | Strategic Use |
|-------|-----------|---------------|
| **Weekly Trends** | 4-week moving average | Staffing level planning |
| **Day-of-Week Patterns** | Performance ranking by weekday | Operating hours optimization |
| **Seasonal Forecasting** | Year-over-year comparison | Annual budgeting, temp staffing |

**Trend Indicators**:
- 📈 **Growing**: Volume > 4-week average
- 📉 **Stable/Declining**: Volume < 4-week average
- 🔥 **Peak Season**: >20% above annual average
- ❄️ **Slow Season**: >20% below annual average

---

### 6️⃣ Advanced Analytics & Predictive Insights (16-18)
**Purpose**: Deep-dive diagnostic analysis

| Query | Complexity | Insight Depth |
|-------|------------|---------------|
| **Cancellation Root Cause** | Lead time + timing analysis | Intervention targeting |
| **Patient Flow Bottlenecks** | Journey mapping with CTEs | Process improvement |
| **Capacity Heat Map** | Hour×Day matrix | Visual scheduling optimization |

**Heat Map Classifications**:
- 🔴 **High (15+)**: Maximum capacity, consider overflow provider
- 🟡 **Medium (8-14)**: Standard operations, monitor closely  
- 🟢 **Low (<8)**: Underutilized, consider slot reduction

---

### 7️⃣ Compliance & Quality Metrics (19-21)
**Purpose**: Clinical quality assurance and regulatory compliance

| Query | Quality Measure | Compliance Area |
|-------|---------------|-----------------|
| **Pediatric Compliance** | Visit frequency by age group | Vaccination schedules, well-child visits |
| **Same-Day Access** | Urgent appointment availability | Patient satisfaction, access metrics |
| **Overbooking Detection** | Concurrent appointment analysis | Provider burnout prevention, safety |

**Compliance Thresholds**:
- Infants (<12mo): 4+ visits/6 months required
- Toddlers (1-3y): 2+ visits/6 months required  
- Gap >90 days: ⚠️ Overdue for visit

---

### 8️⃣ Strategic Business Intelligence (22-25)
**Purpose**: Executive decision support and board reporting

| Query | Business Intelligence | Output Format |
|-------|----------------------|-------------|
| **NPS Proxy Scoring** | Patient satisfaction prediction | Promoter/Passive/Detractor classification |
| **Market Share Analysis** | Service penetration by location | Strategic role assignment (Hub/Major/Satellite) |
| **Revenue Leakage** | Opportunity cost quantification | Recoverable revenue estimates |
| **Panel Size Management** | Patient load vs. accessibility | Capacity alerts |

**NPS-Style Categories**:
- 😊 **Promoter (9-10)**: Score ≥50 → Request testimonials/referrals
- 😐 **Passive (7-8)**: Score 0-49 → Loyalty program engagement  
- 😞 **Detractor (0-6)**: Score <0 → Immediate retention outreach

---

### 9️⃣ Advanced SQL Techniques Showcase (26-31)
**Purpose**: Demonstrate sophisticated SQL capabilities for technical stakeholders

| Query | SQL Technique | Complexity Level |
|-------|-------------|------------------|
| **Follow-up Chain Analysis** | Recursive CTE (`WITH RECURSIVE`) | ⭐⭐⭐⭐⭐ |
| **Running Totals & Percentiles** | Advanced window functions | ⭐⭐⭐⭐ |
| **Pivot Table Simulation** | Cross-tabulation with `CASE` | ⭐⭐⭐ |
| **Care Gap Analysis** | `LAG()` for date differences | ⭐⭐⭐⭐ |
| **Business Hours Analysis** | Time intelligence | ⭐⭐⭐ |
| **Executive Summary** | Single-query KPI dashboard | ⭐⭐⭐⭐ |

---

## 🚀 Implementation Guide

### Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| MySQL | 8.0+ | Window functions, CTE support |
| MariaDB | 10.5+ | Alternative compatible engine |
| Data Volume | 1K+ rows | Meaningful statistical analysis |

### Step-by-Step Setup

#### 1. Database Creation
```sql
-- Create dedicated analytics database
CREATE DATABASE healthcare_analytics;
USE healthcare_analytics;
```

#### 2. Table & Index Creation
```sql
-- Execute the schema creation SQL (provided above)
-- Then create performance indexes:
CREATE INDEX idx_date ON appointments(appointment_date);
CREATE INDEX idx_provider ON appointments(provider_name);
CREATE INDEX idx_status ON appointments(appointment_status);
CREATE INDEX idx_location ON appointments(service_location);
CREATE INDEX idx_category ON appointments(reason_category);
```

#### 3. Data Import from Excel
```sql
-- Method A: Using MySQL Workbench Import Wizard
-- 1. Save Excel as CSV
-- 2. Table Data Import Wizard → Select CSV → Map columns

-- Method B: Using LOAD DATA INFILE (faster for large datasets)
LOAD DATA INFILE '/path/to/appointments.csv'
INTO TABLE appointments
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(appointment_id, appointment_date, appointment_time, @start, @end, 
 patient_name, patient_dob, provider_name, service_location, 
 appointment_reason, appointment_status, reason_category)
SET app_start_time = STR_TO_DATE(@start, '%h:%i:%s %p'),
    app_end_time = STR_TO_DATE(@end, '%h:%i:%s %p');
```

#### 4. Query Execution Order
1. **Start with Operational Queries (1-3)**: Validate data quality
2. **Run Patient Analysis (4-6)**: Identify immediate retention risks  
3. **Execute Provider Reports (7-9)**: Share with clinical managers
4. **Schedule Strategic Queries (13-15)**: Weekly/monthly cycles
5. **Deploy Advanced Analytics (16-31)**: As needed for deep dives

---

## 📈 Sample Use Cases

### Use Case 1: Morning Huddle Report (5 minutes)
**Run Query 1**: Daily Appointment Summary
```sql
-- Output: Today's completion rate, cancellations, no-shows
-- Action: Front desk prioritizes high-risk patient confirmations
```

### Use Case 2: Weekly Provider Review (15 minutes)
**Run Queries 7 + 8**: Provider Scorecard + Schedule Density
```sql
-- Output: Productivity rankings, overbooking alerts
-- Action: Adjust schedules for next week, address bottlenecks
```

### Use Case 3: Monthly Board Report (30 minutes)
**Run Queries 22 + 25 + 31**: NPS + Panel Size + Executive Summary
```sql
-- Output: Satisfaction trends, capacity metrics, financial impact
-- Action: Strategic planning for expansion or service line changes
```

---

## 🔧 Customization Guide

### Adapting to Your Data

| Scenario | Modification Required |
|----------|---------------------|
| **Different date format** | Update `STR_TO_DATE()` format strings |
| **Additional status values** | Add `CASE WHEN` conditions in aggregations |
| **Currency/location changes** | Adjust reimbursement rates in Query 24 |
| **New service categories** | Update `reason_category` references |
| **Pediatric age thresholds** | Modify `TIMESTAMPDIFF()` comparisons |

---

## 📊 Expected Query Performance

| Query Category | Rows Examined | Execution Time | Optimization |
|---------------|---------------|----------------|--------------|
| Operational (1-3) | 1K-10K | <100ms | Date index |
| Patient Analysis (4-6) | Full table | 200-500ms | Composite scan |
| Provider Reports (7-9) | 5K-50K | 100-300ms | Provider + date index |
| Time-Series (13-15) | 10K-100K | 300-800ms | Partitioning recommended |
| Advanced Analytics (26-31) | Full table | 500ms-2s | CTE optimization |

> **Scaling Tip**: For datasets >100K rows, consider partitioning by `appointment_date` (monthly) or implementing materialized views for frequently accessed aggregations.

---

## 🛠️ Troubleshooting Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `NULL duration_minutes` | Missing start/end times | Add data validation in ETL |
| Slow query performance | Missing indexes | Verify index creation |
| Incorrect age calculations | Date format mismatches | Standardize `patient_dob` format |
| Status mismatches | Case sensitivity | Use `LOWER()` or standardize inputs |
| Time calculation errors | AM/PM format issues | Use 24-hour time or consistent formatting |

---

## 📚 Additional Resources

### SQL Techniques Documentation
- [MySQL Window Functions](https://dev.mysql.com/doc/refman/8.0/en/window-functions.html)
- [Recursive CTEs](https://dev.mysql.com/doc/refman/8.0/en/with.html)
- [Performance Optimization](https://dev.mysql.com/doc/refman/8.0/en/optimization-indexes.html)

### Healthcare Analytics Context
- Patient no-show prediction research
- Provider productivity benchmarking standards
- Healthcare revenue cycle management

---
