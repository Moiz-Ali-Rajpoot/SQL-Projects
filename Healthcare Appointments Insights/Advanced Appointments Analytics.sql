-- SQL Scheme Creation

-- ============================================================
-- APPOINTMENTS ANALYTICS DATABASE SCHEMA
-- Healthcare Appointment Management System
-- ============================================================

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
    
    -- Computed columns for analysis
    duration_minutes INT GENERATED ALWAYS AS (
        TIMESTAMPDIFF(MINUTE, 
            CONCAT(appointment_date, ' ', app_start_time),
            CONCAT(appointment_date, ' ', app_end_time)
        )
    ) STORED
);

-- Create indexes for performance
CREATE INDEX idx_date ON appointments(appointment_date);
CREATE INDEX idx_provider ON appointments(provider_name);
CREATE INDEX idx_status ON appointments(appointment_status);
CREATE INDEX idx_location ON appointments(service_location);
CREATE INDEX idx_category ON appointments(reason_category);



												-- ************************************************

												-- SECTION 1: OPERATIONAL DASHBOARD QUERIES

												-- ************************************************


-- ============================================================
-- QUERY 1: Daily Appointment Summary Dashboard
-- Question: What is today's appointment overview by status?
-- Use Case: Morning huddle reports for clinic managers
-- ============================================================

SELECT 
    appointment_date,
    COUNT(*) AS total_appointments,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN appointment_status = 'Rescheduled' THEN 1 ELSE 0 END) AS rescheduled,
    SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_shows,
    SUM(CASE WHEN appointment_status = 'Pending' THEN 1 ELSE 0 END) AS pending,
    -- Completion rate percentage
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS completion_rate_pct
FROM appointments
WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
GROUP BY appointment_date
ORDER BY appointment_date DESC;


-- ============================================================
-- QUERY 2: Real-Time Provider Schedule Utilization
-- Question: Which providers have the busiest schedules today?
-- Use Case: Resource allocation and overtime planning
-- ============================================================

SELECT 
    provider_name,
    service_location,
    COUNT(*) AS total_slots,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS seen_patients,
    SUM(CASE WHEN appointment_status IN ('Cancelled', 'No Show') THEN 1 ELSE 0 END) AS lost_slots,
    ROUND(AVG(duration_minutes), 0) AS avg_appt_duration_min,
    -- Calculate utilization rate (completed / total scheduled)
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS utilization_rate_pct,
    -- Total booked hours
    ROUND(SUM(duration_minutes) / 60.0, 2) AS total_hours_booked
FROM appointments
WHERE appointment_date = CURDATE()
GROUP BY provider_name, service_location
ORDER BY total_slots DESC;


-- ============================================================
-- QUERY 3: Appointment Status Transition Analysis
-- Question: How many appointments changed from scheduled to cancelled/rescheduled?
-- Use Case: Identifying patterns in appointment disruptions
-- Advanced: Window functions to track status changes over time
-- ============================================================

WITH daily_status AS (
    SELECT 
        appointment_date,
        appointment_status,
        COUNT(*) AS status_count,
        LAG(COUNT(*)) OVER (
            PARTITION BY appointment_status 
            ORDER BY appointment_date
        ) AS prev_day_count
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 14 DAY
    GROUP BY appointment_date, appointment_status
)
SELECT 
    appointment_date,
    appointment_status,
    status_count,
    prev_day_count,
    status_count - COALESCE(prev_day_count, 0) AS day_over_day_change,
    -- Flag significant changes (>20% variance)
    CASE 
        WHEN prev_day_count > 0 AND ABS(status_count - prev_day_count) > prev_day_count * 0.2 
        THEN 'Significant Change' 
        ELSE 'Normal Variance' 
    END AS change_alert
FROM daily_status
ORDER BY appointment_date DESC, status_count DESC;




												-- ************************************************

												-- SECTION 2: PATIENT BEHAVIOR & RETENTION ANALYSIS

												-- ************************************************



-- ============================================================
-- QUERY 4: Patient No-Show Risk Scoring
-- Question: Which patients are most likely to no-show based on history?
-- Use Case: Pre-appointment confirmation calls prioritization
-- Advanced: Risk scoring algorithm using historical behavior
-- ============================================================

WITH patient_history AS (
    SELECT 
        patient_name,
        patient_dob,
        COUNT(*) AS total_appointments,
        SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_show_count,
        SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellation_count,
        SUM(CASE WHEN appointment_status = 'Rescheduled' THEN 1 ELSE 0 END) AS reschedule_count,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed_count,
        MAX(appointment_date) AS last_appointment_date,
        DATEDIFF(CURDATE(), MAX(appointment_date)) AS days_since_last_visit
    FROM appointments
    GROUP BY patient_name, patient_dob
    HAVING total_appointments >= 2  -- Minimum history for scoring
)
SELECT 
    patient_name,
    patient_dob,
    TIMESTAMPDIFF(YEAR, patient_dob, CURDATE()) AS patient_age,
    total_appointments,
    -- Calculate reliability score (0-100, higher is better)
    ROUND(
        (completed_count * 100.0 / total_appointments) - 
        (no_show_count * 25.0) - 
        (cancellation_count * 10.0) - 
        (reschedule_count * 5.0),
        2
    ) AS reliability_score,
    -- Risk categorization
    CASE 
        WHEN no_show_count >= 2 OR 
             (no_show_count * 100.0 / total_appointments) > 30 
        THEN 'HIGH RISK'
        WHEN cancellation_count >= 3 OR 
             (cancellation_count * 100.0 / total_appointments) > 25 
        THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS no_show_risk_category,
    days_since_last_visit,
    -- Flag patients who haven't been seen in 90+ days
    CASE WHEN days_since_last_visit > 90 THEN 'Lapsed Patient' ELSE 'Active' END AS patient_status
FROM patient_history
ORDER BY reliability_score ASC, no_show_count DESC
LIMIT 50;  -- Top 50 at-risk patients


-- ============================================================
-- QUERY 5: Patient Lifetime Value & Visit Frequency
-- Question: What is the value and frequency pattern of each patient?
-- Use Case: Identifying VIP patients and retention campaigns
-- ============================================================

WITH patient_metrics AS (
    SELECT 
        patient_name,
        patient_dob,
        COUNT(*) AS total_visits,
        MIN(appointment_date) AS first_visit,
        MAX(appointment_date) AS last_visit,
        DATEDIFF(MAX(appointment_date), MIN(appointment_date)) AS patient_tenure_days,
        ROUND(AVG(duration_minutes), 0) AS avg_visit_duration,
        COUNT(DISTINCT provider_name) AS providers_seen,
        COUNT(DISTINCT reason_category) AS service_categories_used
    FROM appointments
    WHERE appointment_status = 'Checked Out'
    GROUP BY patient_name, patient_dob
)
SELECT 
    patient_name,
    patient_dob,
    total_visits,
    first_visit,
    last_visit,
    patient_tenure_days,
    -- Calculate visit frequency (visits per month)
    ROUND(
        total_visits / NULLIF(patient_tenure_days / 30.0, 0), 
        2
    ) AS visits_per_month,
    avg_visit_duration,
    providers_seen,
    service_categories_used,
    -- Patient tier classification
    CASE 
        WHEN total_visits >= 10 AND patient_tenure_days > 365 THEN 'VIP (Loyal)'
        WHEN total_visits >= 5 THEN 'Regular'
        WHEN total_visits >= 2 THEN 'Occasional'
        ELSE 'New'
    END AS patient_tier,
    -- Recency score (higher = more recent activity)
    CASE 
        WHEN DATEDIFF(CURDATE(), last_visit) <= 30 THEN 'Recently Active'
        WHEN DATEDIFF(CURDATE(), last_visit) <= 90 THEN 'Moderately Active'
        ELSE 'Inactive'
    END AS recency_status
FROM patient_metrics
ORDER BY total_visits DESC, last_visit DESC;


-- ============================================================
-- QUERY 6: Pediatric vs Adult Appointment Patterns
-- Question: Do children and adults have different no-show/cancellation rates?
-- Use Case: Tailoring reminder strategies by demographic
-- ============================================================

SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(YEAR, patient_dob, appointment_date) < 18 THEN 'Pediatric (<18)'
        WHEN TIMESTAMPDIFF(YEAR, patient_dob, appointment_date) BETWEEN 18 AND 64 THEN 'Adult (18-64)'
        ELSE 'Senior (65+)'
    END AS age_group,
    COUNT(*) AS total_appointments,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_shows,
    SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
    ROUND(
        SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS no_show_rate_pct,
    ROUND(
        SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate_pct,
    ROUND(AVG(duration_minutes), 0) AS avg_duration_min,
    -- Most common service category by age group
    (
        SELECT reason_category 
        FROM appointments a2 
        WHERE a2.appointment_id = (
            SELECT appointment_id 
            FROM appointments a3 
            WHERE TIMESTAMPDIFF(YEAR, a3.patient_dob, a3.appointment_date) = 
                  TIMESTAMPDIFF(YEAR, appointments.patient_dob, appointments.appointment_date)
            GROUP BY reason_category 
            ORDER BY COUNT(*) DESC 
            LIMIT 1
        )
        LIMIT 1
    ) AS top_service_category
FROM appointments
WHERE patient_dob IS NOT NULL
GROUP BY age_group
ORDER BY no_show_rate_pct DESC;



												-- ************************************************

												-- SECTION 3: PROVIDER PERFORMANCE & PRODUCTIVITY

												-- ************************************************


-- ============================================================
-- QUERY 7: Provider Productivity Scorecard
-- Question: Which providers are most productive and efficient?
-- Use Case: Performance reviews and bonus calculations
-- Advanced: Multi-dimensional scoring with efficiency metrics
-- ============================================================

WITH provider_stats AS (
    SELECT 
        provider_name,
        service_location,
        COUNT(*) AS total_appointments,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed_visits,
        SUM(CASE WHEN appointment_status IN ('Cancelled', 'No Show') THEN 1 ELSE 0 END) AS lost_appointments,
        SUM(duration_minutes) AS total_minutes_delivered,
        ROUND(AVG(duration_minutes), 0) AS avg_actual_duration,
        COUNT(DISTINCT patient_name) AS unique_patients_seen,
        COUNT(DISTINCT reason_category) AS service_diversity
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 90 DAY
    GROUP BY provider_name, service_location
)
SELECT 
    provider_name,
    service_location,
    total_appointments,
    completed_visits,
    -- Efficiency metrics
    ROUND(completed_visits * 100.0 / NULLIF(total_appointments, 0), 2) AS completion_rate_pct,
    ROUND(lost_appointments * 100.0 / NULLIF(total_appointments, 0), 2) AS attrition_rate_pct,
    -- Productivity score (0-100)
    ROUND(
        (completed_visits * 0.4) +                    -- 40% weight: volume
        (completed_visits * 100.0 / total_appointments * 0.3) +  -- 30% weight: reliability
        (LEAST(total_minutes_delivered / 60, 40) * 0.2) +         -- 20% weight: hours (cap at 40)
        (service_diversity * 2 * 0.1),                          -- 10% weight: versatility
        2
    ) AS productivity_score,
    ROUND(total_minutes_delivered / 60.0, 1) AS total_hours,
    unique_patients_seen,
    service_diversity,
    -- Performance tier
    CASE 
        WHEN completed_visits >= 50 AND (completed_visits * 100.0 / total_appointments) >= 85 
        THEN '⭐ Top Performer'
        WHEN completed_visits >= 30 AND (completed_visits * 100.0 / total_appointments) >= 75 
        THEN '✅ Meeting Targets'
        WHEN (completed_visits * 100.0 / total_appointments) < 60 
        THEN '⚠️ Needs Improvement'
        ELSE '📊 Average'
    END AS performance_tier
FROM provider_stats
ORDER BY productivity_score DESC;


-- ============================================================
-- QUERY 8: Provider Schedule Density Analysis
-- Question: Are providers overbooked or underutilized by hour?
-- Use Case: Optimizing scheduling templates and identifying bottlenecks
-- Advanced: Time-slot analysis using datetime functions
-- ============================================================

WITH hourly_slots AS (
    SELECT 
        provider_name,
        appointment_date,
        HOUR(app_start_time) AS hour_of_day,
        COUNT(*) AS appointments_scheduled,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
        SUM(duration_minutes) AS total_minutes_booked,
        -- Calculate concurrent appointments (simplified)
        GROUP_CONCAT(DISTINCT appointment_reason) AS services_in_hour
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
      AND app_start_time IS NOT NULL
    GROUP BY provider_name, appointment_date, HOUR(app_start_time)
)
SELECT 
    provider_name,
    hour_of_day,
    COUNT(DISTINCT appointment_date) AS days_with_slots,
    ROUND(AVG(appointments_scheduled), 1) AS avg_daily_appts,
    MAX(appointments_scheduled) AS max_concurrent_appts,
    ROUND(AVG(total_minutes_booked), 0) AS avg_minutes_booked,
    -- Utilization assessment
    CASE 
        WHEN AVG(total_minutes_booked) > 50 THEN 'High Utilization'
        WHEN AVG(total_minutes_booked) > 30 THEN 'Moderate Utilization'
        ELSE 'Low Utilization'
    END AS utilization_level,
    -- Peak hour identification
    CASE 
        WHEN hour_of_day BETWEEN 9 AND 11 THEN 'Morning Peak'
        WHEN hour_of_day BETWEEN 14 AND 16 THEN 'Afternoon Peak'
        WHEN hour_of_day BETWEEN 12 AND 13 THEN 'Lunch Period'
        ELSE 'Standard Hours'
    END AS time_period_category
FROM hourly_slots
GROUP BY provider_name, hour_of_day
HAVING days_with_slots >= 5  -- Filter for statistical significance
ORDER BY provider_name, hour_of_day;


-- ============================================================
-- QUERY 9: Provider Specialization vs Demand Mismatch
-- Question: Are providers seeing patients outside their optimal specialty?
-- Use Case: Workforce planning and specialization training needs
-- ============================================================

WITH provider_specialty_demand AS (
    SELECT 
        provider_name,
        reason_category,
        COUNT(*) AS volume,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
        ROUND(
            SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ) AS success_rate
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 90 DAY
    GROUP BY provider_name, reason_category
),
provider_primary_specialty AS (
    SELECT 
        provider_name,
        reason_category AS primary_specialty,
        volume AS specialty_volume
    FROM provider_specialty_demand ps1
    WHERE volume = (
        SELECT MAX(volume) 
        FROM provider_specialty_demand ps2 
        WHERE ps2.provider_name = ps1.provider_name
    )
    GROUP BY provider_name, reason_category, volume
)
SELECT 
    psd.provider_name,
    pps.primary_specialty,
    psd.reason_category AS service_provided,
    psd.volume,
    psd.success_rate,
    -- Calculate divergence from primary specialty
    ABS(psd.volume - pps.specialty_volume) AS volume_divergence,
    CASE 
        WHEN psd.reason_category != pps.primary_specialty AND psd.volume > 5 
        THEN 'Cross-Training Opportunity'
        WHEN psd.reason_category = pps.primary_specialty AND psd.volume > 20 
        THEN 'Core Competency'
        ELSE 'Occasional Service'
    END AS service_classification
FROM provider_specialty_demand psd
JOIN provider_primary_specialty pps ON psd.provider_name = pps.provider_name
ORDER BY psd.provider_name, psd.volume DESC;




												-- ************************************************

												-- SECTION 4: SERVICE LINE & REVENUE OPTIMIZATION

												-- ************************************************

-- ============================================================
-- QUERY 10: Service Category Profitability Analysis
-- Question: Which service lines have the best completion rates and volume?
-- Use Case: Resource allocation and service line expansion decisions
-- ============================================================

SELECT 
    reason_category,
    COUNT(*) AS total_booked,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_show,
    SUM(CASE WHEN appointment_status = 'Rescheduled' THEN 1 ELSE 0 END) AS rescheduled,
    -- Financial impact estimation (assuming $X per completed visit)
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 150, 
        2
    ) AS estimated_revenue_completed,
    ROUND(
        SUM(CASE WHEN appointment_status IN ('Cancelled', 'No Show') THEN 1 ELSE 0 END) * 150, 
        2
    ) AS estimated_revenue_lost,
    -- Key performance indicators
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS conversion_rate_pct,
    ROUND(AVG(duration_minutes), 0) AS avg_duration_min,
    ROUND(
        SUM(duration_minutes) / 60.0 * 
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS productive_hours_per_slot,
    -- Trend indicator (compare to previous month)
    CASE 
        WHEN COUNT(*) > (
            SELECT COUNT(*) FROM appointments a2 
            WHERE a2.reason_category = appointments.reason_category
            AND a2.appointment_date BETWEEN CURDATE() - INTERVAL 60 DAY AND CURDATE() - INTERVAL 30 DAY
        ) THEN '📈 Growing'
        ELSE '📉 Stable/Declining'
    END AS volume_trend
FROM appointments
WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
GROUP BY reason_category
ORDER BY conversion_rate_pct DESC, total_booked DESC;


-- ============================================================
-- QUERY 11: Appointment Duration Accuracy Analysis
-- Question: Are we booking the right amount of time for each service?
-- Use Case: Scheduling template optimization
-- Advanced: Variance analysis between scheduled and actual
-- ============================================================

WITH duration_analysis AS (
    SELECT 
        reason_category,
        appointment_reason,
        duration_minutes AS actual_duration,
        -- Extract scheduled duration from appointment_time string (e.g., "2:30 AM - 3:30 AM")
        CASE 
            WHEN appointment_time LIKE '%-%' THEN
                TIMESTAMPDIFF(MINUTE,
                    STR_TO_DATE(SUBSTRING_INDEX(appointment_time, '-', 1), '%h:%i %p'),
                    STR_TO_DATE(SUBSTRING_INDEX(appointment_time, '-', -1), '%h:%i %p')
                )
            ELSE NULL 
        END AS scheduled_duration
    FROM appointments
    WHERE appointment_status = 'Checked Out'
      AND duration_minutes IS NOT NULL
)
SELECT 
    reason_category,
    COUNT(*) AS sample_size,
    ROUND(AVG(actual_duration), 0) AS avg_actual_duration,
    ROUND(AVG(scheduled_duration), 0) AS avg_scheduled_duration,
    ROUND(AVG(actual_duration - scheduled_duration), 0) AS avg_variance_min,
    -- Variance categories
    SUM(CASE WHEN actual_duration > scheduled_duration THEN 1 ELSE 0 END) AS overruns,
    SUM(CASE WHEN actual_duration < scheduled_duration * 0.8 THEN 1 ELSE 0 END) AS underruns,
    ROUND(
        SUM(CASE WHEN ABS(actual_duration - scheduled_duration) > 10 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS significant_variance_pct,
    -- Recommendation
    CASE 
        WHEN AVG(actual_duration) > AVG(scheduled_duration) + 10 THEN 'Increase slot duration'
        WHEN AVG(actual_duration) < AVG(scheduled_duration) - 10 THEN 'Decrease slot duration'
        ELSE 'Duration optimal'
    END AS scheduling_recommendation
FROM duration_analysis
WHERE scheduled_duration IS NOT NULL
GROUP BY reason_category
HAVING sample_size >= 10
ORDER BY avg_variance_min DESC;


-- ============================================================
-- QUERY 12: Location Performance Comparison
-- Question: Which service locations are performing best operationally?
-- Use Case: Multi-location practice management and benchmarking
-- ============================================================

SELECT 
    service_location,
    COUNT(*) AS total_appointments,
    COUNT(DISTINCT provider_name) AS provider_count,
    COUNT(DISTINCT reason_category) AS service_diversity,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS completion_rate_pct,
    ROUND(
        SUM(CASE WHEN appointment_status IN ('Cancelled', 'No Show') THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS attrition_rate_pct,
    ROUND(AVG(duration_minutes), 0) AS avg_appointment_length,
    -- Efficiency per provider
    ROUND(
        COUNT(*) / COUNT(DISTINCT provider_name), 
        1
    ) AS appointments_per_provider,
    -- Location health score (0-100)
    ROUND(
        (SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) * 0.5 +
        (LEAST(COUNT(DISTINCT reason_category), 10) * 5) +
        (CASE WHEN COUNT(*) / COUNT(DISTINCT provider_name) > 20 THEN 25 ELSE 15 END),
        2
    ) AS location_health_score,
    CASE 
        WHEN COUNT(*) > 100 AND 
             SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 80 
        THEN '🏆 High Performer'
        WHEN SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) < 60 
        THEN '⚠️ Needs Attention'
        ELSE '✅ Standard Performance'
    END AS location_status
FROM appointments
WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
GROUP BY service_location
ORDER BY completion_rate_pct DESC;




												-- ************************************************

												-- SECTION 5: TIME-SERIES & TREND ANALYSIS

												-- ************************************************


-- ============================================================
-- QUERY 13: Weekly Trend Analysis with Moving Averages
-- Question: What are the week-over-week trends in appointments?
-- Use Case: Seasonal planning and capacity forecasting
-- Advanced: Window functions for trend smoothing
-- ============================================================

WITH weekly_metrics AS (
    SELECT 
        YEAR(appointment_date) AS year,
        WEEK(appointment_date) AS week_number,
        DATE(DATE_SUB(appointment_date, INTERVAL WEEKDAY(appointment_date) DAY)) AS week_start,
        COUNT(*) AS total_appointments,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
        SUM(CASE WHEN appointment_status IN ('Cancelled', 'No Show') THEN 1 ELSE 0 END) AS lost
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 180 DAY
    GROUP BY YEAR(appointment_date), WEEK(appointment_date), 
             DATE(DATE_SUB(appointment_date, INTERVAL WEEKDAY(appointment_date) DAY))
)
SELECT 
    year,
    week_number,
    week_start,
    total_appointments,
    completed,
    lost,
    ROUND(completed * 100.0 / NULLIF(total_appointments, 0), 2) AS completion_rate,
    -- 4-week moving average
    ROUND(AVG(total_appointments) OVER (
        ORDER BY year, week_number 
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 0) AS moving_avg_4wk,
    -- Week-over-week growth
    total_appointments - LAG(total_appointments) OVER (ORDER BY year, week_number) AS wow_change,
    ROUND(
        (total_appointments - LAG(total_appointments) OVER (ORDER BY year, week_number)) * 100.0 / 
        NULLIF(LAG(total_appointments) OVER (ORDER BY year, week_number), 0),
        2
    ) AS wow_growth_pct,
    -- Trend direction
    CASE 
        WHEN total_appointments > AVG(total_appointments) OVER (ORDER BY year, week_number ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) 
        THEN 'Above Trend'
        ELSE 'Below Trend'
    END AS trend_position
FROM weekly_metrics
ORDER BY year DESC, week_number DESC;


-- ============================================================
-- QUERY 14: Day-of-Week Pattern Analysis
-- Question: Which days of the week have the best/worst performance?
-- Use Case: Optimizing operating hours and staffing schedules
-- ============================================================

SELECT 
    DAYNAME(appointment_date) AS day_of_week,
    COUNT(*) AS total_appointments,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_shows,
    SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS completion_rate_pct,
    ROUND(
        SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS no_show_rate_pct,
    ROUND(AVG(duration_minutes), 0) AS avg_duration,
    -- Rank by performance
    RANK() OVER (ORDER BY SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) DESC) AS performance_rank,
    -- Day classification
    CASE 
        WHEN DAYOFWEEK(appointment_date) IN (1, 7) THEN 'Weekend'
        WHEN DAYOFWEEK(appointment_date) IN (2, 3) THEN 'Early Week'
        WHEN DAYOFWEEK(appointment_date) IN (4, 5) THEN 'Mid Week'
        ELSE 'Late Week'
    END AS week_segment
FROM appointments
WHERE appointment_date >= CURDATE() - INTERVAL 90 DAY
GROUP BY DAYNAME(appointment_date), DAYOFWEEK(appointment_date)
ORDER BY DAYOFWEEK(appointment_date);


-- ============================================================
-- QUERY 15: Seasonal Demand Forecasting
-- Question: Can we predict busy periods based on historical data?
-- Use Case: Annual budgeting and temporary staffing planning
-- Advanced: Year-over-year comparison with growth rates
-- ============================================================

WITH monthly_comparison AS (
    SELECT 
        MONTH(appointment_date) AS month_num,
        MONTHNAME(appointment_date) AS month_name,
        YEAR(appointment_date) AS year_num,
        COUNT(*) AS appointment_count,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed_count
    FROM appointments
    GROUP BY MONTH(appointment_date), MONTHNAME(appointment_date), YEAR(appointment_date)
),
pivoted AS (
    SELECT 
        month_num,
        month_name,
        MAX(CASE WHEN year_num = 2024 THEN appointment_count END) AS y2024_volume,
        MAX(CASE WHEN year_num = 2025 THEN appointment_count END) AS y2025_volume,
        MAX(CASE WHEN year_num = 2024 THEN completed_count END) AS y2024_completed,
        MAX(CASE WHEN year_num = 2025 THEN completed_count END) AS y2025_completed
    FROM monthly_comparison
    GROUP BY month_num, month_name
)
SELECT 
    month_name,
    y2024_volume,
    y2025_volume,
    y2024_completed,
    y2025_completed,
    -- Year-over-year growth
    CASE 
        WHEN y2024_volume > 0 THEN 
            ROUND((y2025_volume - y2024_volume) * 100.0 / y2024_volume, 2)
        ELSE NULL 
    END AS yoy_growth_pct,
    -- Seasonal classification
    CASE 
        WHEN month_num IN (12, 1, 2) THEN 'Winter'
        WHEN month_num IN (3, 4, 5) THEN 'Spring'
        WHEN month_num IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END AS season,
    -- Busyness indicator
    CASE 
        WHEN y2025_volume > (SELECT AVG(y2025_volume) FROM pivoted WHERE y2025_volume IS NOT NULL) * 1.2 THEN '🔥 Peak Season'
        WHEN y2025_volume < (SELECT AVG(y2025_volume) FROM pivoted WHERE y2025_volume IS NOT NULL) * 0.8 THEN '❄️ Slow Season'
        ELSE '📊 Normal Volume'
    END AS season_status
FROM pivoted
ORDER BY month_num;



												-- ************************************************

												-- SECTION 6: ADVANCED ANALYTICS & PREDICTIVE INSIGHTS

												-- ************************************************



-- ============================================================
-- QUERY 16: Cancellation Root Cause Analysis
-- Question: What patterns exist in cancellations by lead time?
-- Use Case: Reducing cancellations through targeted interventions
-- Advanced: Lead time analysis and predictive indicators
-- ============================================================

WITH cancellation_timing AS (
    SELECT 
        appointment_id,
        appointment_date,
        appointment_status,
        reason_category,
        provider_name,
        -- Calculate days between booking and appointment (simulated)
        -- In real scenario, you'd have created_date column
        DATEDIFF(appointment_date, CURDATE()) AS days_until_appointment,
        CASE 
            WHEN HOUR(app_start_time) < 9 THEN 'Early Morning'
            WHEN HOUR(app_start_time) < 12 THEN 'Morning'
            WHEN HOUR(app_start_time) < 15 THEN 'Afternoon'
            ELSE 'Evening'
        END AS time_of_day
    FROM appointments
    WHERE appointment_status IN ('Cancelled', 'Rescheduled')
)
SELECT 
    time_of_day,
    reason_category,
    COUNT(*) AS cancellation_count,
    ROUND(AVG(ABS(days_until_appointment)), 0) AS avg_lead_time_days,
    -- Cancellation velocity (how far in advance)
    CASE 
        WHEN AVG(ABS(days_until_appointment)) <= 1 THEN 'Last Minute'
        WHEN AVG(ABS(days_until_appointment)) <= 7 THEN 'Short Notice'
        ELSE 'Advance Notice'
    END AS notice_category,
    -- Provider impact
    provider_name,
    COUNT(DISTINCT provider_name) AS providers_affected,
    -- Recommendations
    CASE 
        WHEN time_of_day = 'Early Morning' AND COUNT(*) > 10 
        THEN 'Consider eliminating early slots'
        WHEN reason_category = 'Nutrition / MNT' AND COUNT(*) > 5 
        THEN 'Review nutrition counseling process'
        ELSE 'Monitor pattern'
    END AS recommended_action
FROM cancellation_timing
GROUP BY time_of_day, reason_category, provider_name
ORDER BY cancellation_count DESC;


-- ============================================================
-- QUERY 17: Patient Flow Bottleneck Analysis
-- Question: Where are the bottlenecks in the patient journey?
-- Use Case: Process improvement and wait time reduction
-- Advanced: Cohort analysis with status progression
-- ============================================================

WITH appointment_journey AS (
    SELECT 
        patient_name,
        patient_dob,
        appointment_date,
        app_start_time,
        appointment_status,
        reason_category,
        provider_name,
        LAG(appointment_status) OVER (
            PARTITION BY patient_name, patient_dob 
            ORDER BY appointment_date, app_start_time
        ) AS prev_status,
        LAG(appointment_date) OVER (
            PARTITION BY patient_name, patient_dob 
            ORDER BY appointment_date, app_start_time
        ) AS prev_date
    FROM appointments
    ORDER BY patient_name, patient_dob, appointment_date
)
SELECT 
    reason_category,
    prev_status,
    appointment_status AS current_status,
    COUNT(*) AS transition_count,
    ROUND(AVG(DATEDIFF(appointment_date, prev_date)), 1) AS avg_days_between_visits,
    -- Journey health score
    CASE 
        WHEN prev_status = 'Checked Out' AND appointment_status = 'Checked Out' THEN '✅ Regular Care'
        WHEN prev_status = 'Cancelled' AND appointment_status = 'Cancelled' THEN '❌ Chronic Canceller'
        WHEN prev_status = 'No Show' AND appointment_status = 'No Show' THEN '⚠️ Engagement Issue'
        WHEN prev_status = 'Rescheduled' AND appointment_status = 'Rescheduled' THEN '🔄 Scheduling Difficulty'
        ELSE '🆕 New Pattern'
    END AS patient_journey_status,
    -- Risk of patient churn
    CASE 
        WHEN DATEDIFF(CURDATE(), MAX(appointment_date)) > 60 
             AND appointment_status != 'Checked Out' 
        THEN 'High Churn Risk'
        ELSE 'Active'
    END AS churn_risk
FROM appointment_journey
WHERE prev_status IS NOT NULL
GROUP BY reason_category, prev_status, appointment_status
ORDER BY transition_count DESC;


-- ============================================================
-- QUERY 18: Capacity Utilization Heat Map Data
-- Question: When is the clinic at maximum capacity?
-- Use Case: Visual heat maps for scheduling optimization
-- ============================================================

SELECT 
    DAYNAME(appointment_date) AS day_name,
    HOUR(app_start_time) AS hour_slot,
    COUNT(*) AS appointment_count,
    COUNT(DISTINCT provider_name) AS providers_working,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN appointment_status IN ('Cancelled', 'No Show') THEN 1 ELSE 0 END) AS open_slots,
    -- Heat intensity classification
    CASE 
        WHEN COUNT(*) >= 15 THEN '🔴 High (15+)'
        WHEN COUNT(*) >= 8 THEN '🟡 Medium (8-14)'
        ELSE '🟢 Low (<8)'
    END AS traffic_intensity,
    -- Utilization efficiency
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        0
    ) AS efficiency_pct,
    -- Recommended action
    CASE 
        WHEN COUNT(*) >= 15 AND 
             SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) < 70 
        THEN 'Add overflow provider'
        WHEN COUNT(*) < 5 AND HOUR(app_start_time) BETWEEN 9 AND 16 
        THEN 'Consider closing slot'
        ELSE 'Optimal'
    END AS scheduling_recommendation
FROM appointments
WHERE app_start_time IS NOT NULL
  AND appointment_date >= CURDATE() - INTERVAL 60 DAY
GROUP BY DAYNAME(appointment_date), DAYOFWEEK(appointment_date), HOUR(app_start_time)
HAVING appointment_count >= 3  -- Filter noise
ORDER BY DAYOFWEEK(appointment_date), hour_slot;



												-- ************************************************

												-- SECTION 7: COMPLIANCE & QUALITY METRICS

												-- ************************************************


-- ============================================================
-- QUERY 19: Pediatric Appointment Compliance (Vaccination/Wellness)
-- Question: Are pediatric patients maintaining their care schedules?
-- Use Case: Quality metrics for pediatric care compliance
-- Advanced: Age-appropriate visit frequency analysis
-- ============================================================

WITH pediatric_patients AS (
    SELECT 
        patient_name,
        patient_dob,
        TIMESTAMPDIFF(MONTH, patient_dob, CURDATE()) AS age_months,
        TIMESTAMPDIFF(YEAR, patient_dob, CURDATE()) AS age_years,
        COUNT(*) AS total_visits_6mo,
        MAX(appointment_date) AS last_visit,
        COUNT(DISTINCT reason_category) AS visit_types
    FROM appointments
    WHERE TIMESTAMPDIFF(YEAR, patient_dob, appointment_date) < 18
      AND appointment_date >= CURDATE() - INTERVAL 6 MONTH
    GROUP BY patient_name, patient_dob
)
SELECT 
    CASE 
        WHEN age_months < 12 THEN 'Infant (0-12mo)'
        WHEN age_years < 3 THEN 'Toddler (1-3y)'
        WHEN age_years < 6 THEN 'Preschool (3-6y)'
        WHEN age_years < 12 THEN 'School Age (6-12y)'
        ELSE 'Adolescent (12-18y)'
    END AS age_group,
    COUNT(*) AS patient_count,
    ROUND(AVG(total_visits_6mo), 1) AS avg_visits_6mo,
    ROUND(AVG(DATEDIFF(CURDATE(), last_visit)), 0) AS avg_days_since_visit,
    SUM(CASE WHEN total_visits_6mo >= 2 THEN 1 ELSE 0 END) AS compliant_patients,
    -- Compliance rate by age group
    ROUND(
        SUM(CASE WHEN total_visits_6mo >= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS compliance_rate_pct,
    -- Risk assessment
    CASE 
        WHEN age_months < 12 AND total_visits_6mo < 4 THEN '⚠️ High Risk - Missed Vaccines'
        WHEN age_years < 3 AND total_visits_6mo < 2 THEN '⚠️ Development Check Needed'
        WHEN DATEDIFF(CURDATE(), last_visit) > 90 THEN '⚠️ Overdue for Visit'
        ELSE '✅ On Track'
    END AS compliance_status
FROM pediatric_patients
GROUP BY age_group
ORDER BY age_months;


-- ============================================================
-- QUERY 20: Same-Day Appointment Availability Analysis
-- Question: How often are same-day slots used and for what?
-- Use Case: Urgent care capacity planning
-- ============================================================

WITH same_day_analysis AS (
    SELECT 
        appointment_date,
        patient_name,
        appointment_reason,
        reason_category,
        provider_name,
        appointment_status,
        app_start_time,
        -- Determine if urgent (based on reason keywords)
        CASE 
            WHEN appointment_reason LIKE '%urgent%' 
                 OR appointment_reason LIKE '%pain%' 
                 OR appointment_reason LIKE '%injury%' 
                 OR appointment_reason LIKE '%sick%' 
            THEN 'Urgent'
            ELSE 'Routine'
        END AS urgency_level
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
)
SELECT 
    urgency_level,
    reason_category,
    COUNT(*) AS volume,
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed,
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS completion_rate,
    -- Peak hours for same-day
    CASE 
        WHEN HOUR(app_start_time) BETWEEN 8 AND 10 THEN 'Morning Rush'
        WHEN HOUR(app_start_time) BETWEEN 14 AND 16 THEN 'Afternoon Rush'
        ELSE 'Standard Hours'
    END AS arrival_pattern,
    COUNT(DISTINCT provider_name) AS providers_used
FROM same_day_analysis
GROUP BY urgency_level, reason_category, arrival_pattern
ORDER BY urgency_level, volume DESC;


-- ============================================================
-- QUERY 21: Appointment Clustering & Overbooking Detection
-- Question: Are providers overbooked or are there dangerous clusters?
-- Use Case: Preventing provider burnout and ensuring quality care
-- Advanced: Density analysis using time windows
-- ============================================================

WITH provider_schedule AS (
    SELECT 
        provider_name,
        appointment_date,
        app_start_time,
        app_end_time,
        duration_minutes,
        appointment_status,
        LAG(app_end_time) OVER (
            PARTITION BY provider_name, appointment_date 
            ORDER BY app_start_time
        ) AS prev_end_time,
        -- Calculate gap or overlap with previous appointment
        TIMESTAMPDIFF(MINUTE, 
            LAG(app_end_time) OVER (PARTITION BY provider_name, appointment_date ORDER BY app_start_time),
            app_start_time
        ) AS minutes_from_prev
    FROM appointments
    WHERE app_start_time IS NOT NULL 
      AND app_end_time IS NOT NULL
)
SELECT 
    provider_name,
    appointment_date,
    COUNT(*) AS daily_appointments,
    SUM(CASE WHEN minutes_from_prev < 0 THEN 1 ELSE 0 END) AS overlapping_appointments,
    SUM(CASE WHEN minutes_from_prev >= 0 AND minutes_from_prev < 15 THEN 1 ELSE 0 END) AS tight_turnovers,
    ROUND(AVG(CASE WHEN minutes_from_prev > 0 THEN minutes_from_prev END), 0) AS avg_gap_minutes,
    -- Overbooking risk score
    CASE 
        WHEN SUM(CASE WHEN minutes_from_prev < 0 THEN 1 ELSE 0 END) > 0 THEN '🔴 Critical - Overlaps Detected'
        WHEN SUM(CASE WHEN minutes_from_prev >= 0 AND minutes_from_prev < 15 THEN 1 ELSE 0 END) > 3 THEN '🟡 Warning - Tight Schedule'
        ELSE '🟢 Adequate Buffer'
    END AS schedule_health,
    -- Productivity vs Safety balance
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        0
    ) AS completion_rate
FROM provider_schedule
GROUP BY provider_name, appointment_date
HAVING daily_appointments >= 5
ORDER BY overlapping_appointments DESC, daily_appointments DESC;


												-- ************************************************

												-- SECTION 8: STRATEGIC BUSINESS INTELLIGENCE

												-- ************************************************


-- ============================================================
-- QUERY 22: Net Promoter Score Proxy (Patient Satisfaction Indicator)
-- Question: Which patients are likely promoters vs detractors?
-- Use Case: Targeted satisfaction surveys and retention
-- Advanced: Composite scoring based on multiple behavioral indicators
-- ============================================================

WITH patient_satisfaction_signals AS (
    SELECT 
        patient_name,
        patient_dob,
        COUNT(*) AS total_visits,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS successful_visits,
        SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_shows,
        SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
        SUM(CASE WHEN appointment_status = 'Rescheduled' THEN 1 ELSE 0 END) AS reschedules,
        COUNT(DISTINCT provider_name) AS provider_switches,
        ROUND(AVG(duration_minutes), 0) AS avg_visit_length,
        MAX(appointment_date) AS last_visit,
        MIN(appointment_date) AS first_visit,
        DATEDIFF(MAX(appointment_date), MIN(appointment_date)) AS relationship_length_days
    FROM appointments
    GROUP BY patient_name, patient_dob
    HAVING total_visits >= 2
)
SELECT 
    patient_name,
    patient_dob,
    total_visits,
    -- Calculate satisfaction proxy score (-100 to +100)
    ROUND(
        (successful_visits * 10) +                           -- Positive: completed visits
        (relationship_length_days / 30 * 5) +               -- Positive: loyalty duration
        (CASE WHEN provider_switches = 1 THEN 10 ELSE 0 END) -  -- Positive: provider consistency
        (no_shows * 25) -                                    -- Negative: no-shows
        (cancellations * 10) -                               -- Negative: cancellations
        (reschedules * 5) -                                  -- Negative: reschedules
        (CASE WHEN DATEDIFF(CURDATE(), last_visit) > 60 THEN 20 ELSE 0 END),  -- Negative: lapse
        2
    ) AS satisfaction_proxy_score,
    -- NPS-style categorization
    CASE 
        WHEN satisfaction_proxy_score >= 50 THEN 'Promoter (9-10)'
        WHEN satisfaction_proxy_score >= 0 THEN 'Passive (7-8)'
        ELSE 'Detractor (0-6)'
    END AS nps_category,
    -- Action recommendations
    CASE 
        WHEN satisfaction_proxy_score >= 50 THEN 'Request testimonial/referral'
        WHEN satisfaction_proxy_score >= 0 THEN 'Engage with loyalty program'
        ELSE 'Immediate retention outreach'
    END AS recommended_action,
    last_visit,
    DATEDIFF(CURDATE(), last_visit) AS days_since_last_visit
FROM patient_satisfaction_signals
ORDER BY satisfaction_proxy_score DESC;


-- ============================================================
-- QUERY 23: Market Share by Service Category
-- Question: What is our market penetration for each service line?
-- Use Case: Competitive analysis and service expansion decisions
-- ============================================================

WITH service_market AS (
    SELECT 
        reason_category,
        service_location,
        COUNT(*) AS location_volume,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed_volume
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 90 DAY
    GROUP BY reason_category, service_location
),
totals AS (
    SELECT 
        reason_category,
        SUM(location_volume) AS total_category_volume,
        SUM(completed_volume) AS total_completed
    FROM service_market
    GROUP BY reason_category
)
SELECT 
    sm.reason_category,
    sm.service_location,
    sm.location_volume,
    sm.completed_volume,
    t.total_category_volume,
    -- Market share by location
    ROUND(sm.location_volume * 100.0 / t.total_category_volume, 2) AS location_market_share_pct,
    -- Performance comparison
    ROUND(sm.completed_volume * 100.0 / sm.location_volume, 2) AS location_conversion_rate,
    ROUND(t.total_completed * 100.0 / t.total_category_volume, 2) AS overall_conversion_rate,
    -- Gap analysis
    CASE 
        WHEN sm.completed_volume * 100.0 / sm.location_volume > t.total_completed * 100.0 / t.total_category_volume 
        THEN 'Above Average'
        ELSE 'Below Average'
    END AS performance_vs_category,
    -- Strategic importance
    CASE 
        WHEN sm.location_volume > t.total_category_volume * 0.4 THEN 'Hub Location'
        WHEN sm.location_volume > t.total_category_volume * 0.2 THEN 'Major Site'
        ELSE 'Satellite'
    END AS location_strategic_role
FROM service_market sm
JOIN totals t ON sm.reason_category = t.reason_category
ORDER BY sm.reason_category, location_market_share_pct DESC;


-- ============================================================
-- QUERY 24: Revenue Leakage Analysis
-- Question: Where are we losing potential revenue?
-- Use Case: Financial performance improvement initiatives
-- Advanced: Opportunity cost calculations
-- ============================================================

WITH financial_analysis AS (
    SELECT 
        appointment_date,
        appointment_status,
        reason_category,
        provider_name,
        duration_minutes,
        -- Assume average reimbursement rates by category (customize these)
        CASE 
            WHEN reason_category = 'Speech-Language Pathology' THEN 120
            WHEN reason_category = 'Occupational Therapy' THEN 110
            WHEN reason_category = 'Nutrition / MNT' THEN 90
            WHEN reason_category LIKE '%Autism%' THEN 200
            ELSE 100  -- Default rate
        END AS estimated_reimbursement,
        CASE 
            WHEN appointment_status = 'Checked Out' THEN 'Realized'
            WHEN appointment_status IN ('Cancelled', 'No Show') THEN 'Lost'
            ELSE 'At Risk'
        END AS revenue_status
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
)
SELECT 
    reason_category,
    revenue_status,
    COUNT(*) AS appointment_count,
    SUM(estimated_reimbursement) AS financial_impact,
    ROUND(AVG(duration_minutes), 0) AS avg_duration,
    -- Daily averages
    ROUND(COUNT(*) / 30.0, 1) AS avg_daily_count,
    ROUND(SUM(estimated_reimbursement) / 30.0, 2) AS avg_daily_revenue,
    -- Cumulative impact
    SUM(SUM(estimated_reimbursement)) OVER (
        PARTITION BY reason_category 
        ORDER BY revenue_status
    ) AS cumulative_category_impact,
    -- Recovery opportunity
    CASE 
        WHEN revenue_status = 'Lost' THEN 
            ROUND(SUM(estimated_reimbursement) * 0.3, 2)  -- Assume 30% recoverable
        ELSE 0 
    END AS recoverable_revenue_estimate
FROM financial_analysis
GROUP BY reason_category, revenue_status
ORDER BY reason_category, 
         FIELD(revenue_status, 'Realized', 'At Risk', 'Lost');


-- ============================================================
-- QUERY 25: Provider Patient Panel Size & Accessibility
-- Question: Are providers carrying appropriate patient loads?
-- Use Case: Ensuring equitable access and preventing burnout
-- ============================================================

WITH provider_panels AS (
    SELECT 
        provider_name,
        service_location,
        COUNT(DISTINCT patient_name) AS unique_patients,
        COUNT(*) AS total_appointments,
        COUNT(DISTINCT reason_category) AS services_offered,
        ROUND(AVG(DATEDIFF(CURDATE(), appointment_date)), 0) AS avg_recency_days,
        -- New patient ratio (simplified - first visit in period)
        SUM(CASE WHEN appointment_date = (
            SELECT MIN(appointment_date) 
            FROM appointments a2 
            WHERE a2.patient_name = appointments.patient_name
        ) THEN 1 ELSE 0 END) AS new_patient_visits
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 90 DAY
    GROUP BY provider_name, service_location
)
SELECT 
    provider_name,
    service_location,
    unique_patients,
    total_appointments,
    services_offered,
    ROUND(total_appointments / 90.0, 1) AS avg_daily_patients,
    -- Panel size classification (general guidelines)
    CASE 
        WHEN unique_patients > 150 THEN 'Large Panel (150+)'
        WHEN unique_patients > 80 THEN 'Medium Panel (80-150)'
        ELSE 'Small Panel (<80)'
    END AS panel_size_category,
    -- Accessibility score (lower is better)
    ROUND(avg_recency_days / unique_patients * 10, 2) AS accessibility_index,
    new_patient_visits,
    ROUND(new_patient_visits * 100.0 / total_appointments, 2) AS new_patient_pct,
    -- Capacity assessment
    CASE 
        WHEN unique_patients > 200 THEN '🔴 Overcapacity - Consider referral restrictions'
        WHEN unique_patients < 50 AND total_appointments > 100 THEN '🟡 High frequency - Specialized care?'
        WHEN new_patient_visits < 5 THEN '🔵 Established practice - Low growth'
        ELSE '🟢 Balanced panel'
    END AS capacity_status
FROM provider_panels
ORDER BY unique_patients DESC;


												-- ************************************************

												-- SECTION 9: ADVANCED SQL TECHNIQUES

												-- ************************************************


-- ============================================================
-- QUERY 26: Recursive CTE for Follow-up Chain Analysis
-- Question: What is the typical patient journey through multiple visits?
-- Use Case: Care pathway optimization and protocol development
-- Advanced: Recursive Common Table Expressions
-- ============================================================

WITH RECURSIVE visit_chain AS (
    -- Anchor: First visit for each patient
    SELECT 
        patient_name,
        patient_dob,
        appointment_date,
        app_start_time,
        appointment_status,
        reason_category,
        1 AS visit_number,
        CAST(reason_category AS CHAR(255)) AS care_pathway
    FROM appointments a1
    WHERE appointment_date = (
        SELECT MIN(appointment_date) 
        FROM appointments a2 
        WHERE a2.patient_name = a1.patient_name
    )
    
    UNION ALL
    
    -- Recursive: Subsequent visits
    SELECT 
        a.patient_name,
        a.patient_dob,
        a.appointment_date,
        a.app_start_time,
        a.appointment_status,
        a.reason_category,
        vc.visit_number + 1,
        CONCAT(vc.care_pathway, ' -> ', a.reason_category)
    FROM appointments a
    INNER JOIN visit_chain vc ON a.patient_name = vc.patient_name
    WHERE a.appointment_date > vc.appointment_date
      AND vc.visit_number < 5  -- Limit recursion depth
)
SELECT 
    care_pathway,
    visit_number,
    COUNT(*) AS patient_count,
    ROUND(AVG(DATEDIFF(
        LEAD(appointment_date) OVER (PARTITION BY patient_name ORDER BY visit_number),
        appointment_date
    )), 0) AS avg_days_to_next_visit,
    -- Common pathways (top 10)
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS pathway_popularity_rank
FROM visit_chain
GROUP BY care_pathway, visit_number
HAVING patient_count >= 3  -- Filter rare paths
ORDER BY patient_count DESC, visit_number
LIMIT 20;


-- ============================================================
-- QUERY 27: Window Functions for Running Totals & Percentiles
-- Question: How do providers rank against peers in real-time?
-- Use Case: Gamification and performance dashboards
-- ============================================================

WITH daily_provider_stats AS (
    SELECT 
        appointment_date,
        provider_name,
        COUNT(*) AS daily_appointments,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS daily_completed,
        SUM(duration_minutes) / 60.0 AS daily_hours
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
    GROUP BY appointment_date, provider_name
)
SELECT 
    appointment_date,
    provider_name,
    daily_appointments,
    daily_completed,
    -- Running total for month
    SUM(daily_completed) OVER (
        PARTITION BY provider_name 
        ORDER BY appointment_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS mtd_completed,
    -- Percentile rank among all providers that day
    ROUND(
        PERCENT_RANK() OVER (
            ORDER BY daily_completed
        ) * 100, 
        0
    ) AS percentile_rank,
    -- Rank for the day
    RANK() OVER (ORDER BY daily_completed DESC) AS daily_rank,
    -- Comparison to provider's own average
    daily_completed - AVG(daily_completed) OVER (PARTITION BY provider_name) AS vs_own_avg,
    -- 3-day moving average
    ROUND(AVG(daily_completed) OVER (
        PARTITION BY provider_name 
        ORDER BY appointment_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1) AS moving_avg_3day
FROM daily_provider_stats
ORDER BY appointment_date DESC, daily_completed DESC;


-- ============================================================
-- QUERY 28: Pivot Table Simulation (Cross-Tabulation)
-- Question: What is the matrix of service categories vs appointment status?
-- Use Case: Comprehensive operational reports
-- ============================================================

SELECT 
    reason_category,
    -- Pivot counts by status
    SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS checked_out,
    SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_show,
    SUM(CASE WHEN appointment_status = 'Rescheduled' THEN 1 ELSE 0 END) AS rescheduled,
    SUM(CASE WHEN appointment_status = 'Pending' THEN 1 ELSE 0 END) AS pending,
    -- Totals
    COUNT(*) AS total,
    -- Percentage distribution
    ROUND(
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        1
    ) AS pct_completed,
    -- Status diversity index (higher = more varied outcomes)
    ROUND(
        (COUNT(DISTINCT appointment_status) * 100.0 / 5),  -- 5 possible statuses
        0
    ) AS status_diversity_index
FROM appointments
WHERE appointment_date >= CURDATE() - INTERVAL 90 DAY
GROUP BY reason_category
ORDER BY total DESC;


-- ============================================================
-- QUERY 29: Gap Analysis for Care Continuity
-- Question: Which patients have gaps in their recommended care schedules?
-- Use Case: Care coordination and population health management
-- Advanced: Date arithmetic for care gap identification
-- ============================================================

WITH care_gaps AS (
    SELECT 
        patient_name,
        patient_dob,
        reason_category,
        appointment_date,
        app_start_time,
        appointment_status,
        LAG(appointment_date) OVER (
            PARTITION BY patient_name, reason_category 
            ORDER BY appointment_date
        ) AS prev_visit_date,
        -- Calculate gap between visits for same service
        DATEDIFF(appointment_date, 
            LAG(appointment_date) OVER (
                PARTITION BY patient_name, reason_category 
                ORDER BY appointment_date
            )
        ) AS days_since_last_service
    FROM appointments
    WHERE appointment_status = 'Checked Out'
)
SELECT 
    patient_name,
    patient_dob,
    reason_category,
    COUNT(*) AS total_visits,
    ROUND(AVG(days_since_last_service), 0) AS avg_gap_days,
    MAX(days_since_last_service) AS max_gap_days,
    -- Recommended frequency by service (customize based on clinical guidelines)
    CASE 
        WHEN reason_category = 'Speech-Language Pathology' THEN 30
        WHEN reason_category = 'Occupational Therapy' THEN 14
        WHEN reason_category = 'Nutrition / MNT' THEN 90
        ELSE 60
    END AS recommended_frequency_days,
    -- Gap analysis
    CASE 
        WHEN AVG(days_since_last_service) > 
             CASE 
                WHEN reason_category = 'Speech-Language Pathology' THEN 45
                WHEN reason_category = 'Occupational Therapy' THEN 21
                ELSE 90
             END 
        THEN '⚠️ Extended Gap - Outreach Needed'
        WHEN MAX(days_since_last_service) > 120 
        THEN '🔴 Longest Gap >4 Months'
        ELSE '✅ On Schedule'
    END AS continuity_status,
    -- Next visit due estimation
    DATE_ADD(MAX(appointment_date), INTERVAL 
        CASE 
            WHEN reason_category = 'Speech-Language Pathology' THEN 30
            WHEN reason_category = 'Occupational Therapy' THEN 14
            ELSE 60
        END DAY
    ) AS next_visit_due
FROM care_gaps
WHERE days_since_last_service IS NOT NULL
GROUP BY patient_name, patient_dob, reason_category
HAVING total_visits >= 2
ORDER BY max_gap_days DESC;


-- ============================================================
-- QUERY 30: Advanced Time Intelligence (Business Hours Analysis)
-- Question: Are we optimizing our operating hours based on demand?
-- Use Case: Hours of operation optimization
-- ============================================================

WITH hourly_demand AS (
    SELECT 
        HOUR(app_start_time) AS hour_of_day,
        DAYOFWEEK(appointment_date) AS day_num,
        DAYNAME(appointment_date) AS day_name,
        COUNT(*) AS demand,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS actual_visits,
        COUNT(DISTINCT provider_name) AS providers_available
    FROM appointments
    WHERE app_start_time IS NOT NULL
      AND appointment_date >= CURDATE() - INTERVAL 90 DAY
    GROUP BY HOUR(app_start_time), DAYOFWEEK(appointment_date), DAYNAME(appointment_date)
),
hourly_stats AS (
    SELECT 
        hour_of_day,
        day_name,
        day_num,
        demand,
        actual_visits,
        providers_available,
        -- Calculate efficiency
        ROUND(actual_visits * 100.0 / NULLIF(demand, 0), 2) AS conversion_rate,
        -- Demand concentration
        ROUND(demand * 100.0 / SUM(demand) OVER (PARTITION BY day_name), 2) AS pct_of_daily_volume
    FROM hourly_demand
)
SELECT 
    day_name,
    hour_of_day,
    demand,
    actual_visits,
    conversion_rate,
    pct_of_daily_volume,
    -- Business case for extended hours
    CASE 
        WHEN hour_of_day < 8 AND demand >= 5 THEN 'Consider early opening'
        WHEN hour_of_day > 17 AND demand >= 5 THEN 'Consider evening hours'
        WHEN demand = 0 AND hour_of_day BETWEEN 12 AND 14 THEN 'Lunch closure viable'
        ELSE 'Current hours appropriate'
    END AS hours_recommendation,
    -- Staffing ratio suggestion
    ROUND(demand / 4.0, 0) AS suggested_provider_count  -- Assume 4 appointments per provider per hour
FROM hourly_stats
WHERE hour_of_day BETWEEN 6 AND 20  -- Business hours focus
ORDER BY day_num, hour_of_day;


-- ============================================================
-- BONUS QUERY 31: Complete Executive Summary Dashboard
-- Question: One query to rule them all - comprehensive KPIs
-- Use Case: Executive reporting and board presentations
-- ============================================================

WITH 
date_range AS (
    SELECT 
        MIN(appointment_date) AS period_start,
        MAX(appointment_date) AS period_end,
        COUNT(DISTINCT appointment_date) AS operating_days
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
),
volume_metrics AS (
    SELECT 
        COUNT(*) AS total_appointments_scheduled,
        SUM(CASE WHEN appointment_status = 'Checked Out' THEN 1 ELSE 0 END) AS completed_visits,
        SUM(CASE WHEN appointment_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancellations,
        SUM(CASE WHEN appointment_status = 'No Show' THEN 1 ELSE 0 END) AS no_shows,
        SUM(CASE WHEN appointment_status = 'Rescheduled' THEN 1 ELSE 0 END) AS reschedules,
        COUNT(DISTINCT patient_name) AS unique_patients,
        COUNT(DISTINCT provider_name) AS active_providers,
        COUNT(DISTINCT service_location) AS active_locations
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
),
financial_estimates AS (
    SELECT 
        ROUND(SUM(CASE WHEN appointment_status = 'Checked Out' THEN 100 ELSE 0 END), 2) AS realized_revenue,
        ROUND(SUM(CASE WHEN appointment_status IN ('Cancelled', 'No Show') THEN 100 ELSE 0 END), 2) AS lost_revenue_opportunity
    FROM appointments
    WHERE appointment_date >= CURDATE() - INTERVAL 30 DAY
)
SELECT 
    -- Period info
    dr.period_start,
    dr.period_end,
    dr.operating_days,
    
    -- Volume KPIs
    vm.total_appointments_scheduled,
    vm.completed_visits,
    vm.cancellations,
    vm.no_shows,
    vm.reschedules,
    
    -- Rates
    ROUND(vm.completed_visits * 100.0 / vm.total_appointments_scheduled, 2) AS completion_rate_pct,
    ROUND(vm.cancellations * 100.0 / vm.total_appointments_scheduled, 2) AS cancellation_rate_pct,
    ROUND(vm.no_shows * 100.0 / vm.total_appointments_scheduled, 2) AS no_show_rate_pct,
    
    -- Capacity metrics
    vm.unique_patients,
    vm.active_providers,
    vm.active_locations,
    ROUND(vm.total_appointments_scheduled / dr.operating_days, 1) AS avg_daily_volume,
    ROUND(vm.completed_visits / vm.active_providers / dr.operating_days, 1) AS avg_visits_per_provider_per_day,
    
    -- Financial estimates
    fe.realized_revenue,
    fe.lost_revenue_opportunity,
    ROUND(fe.realized_revenue * 100.0 / (fe.realized_revenue + fe.lost_revenue_opportunity), 2) AS revenue_capture_rate_pct,
    
    -- Health score (0-100 composite)
    ROUND(
        (vm.completed_visits * 100.0 / vm.total_appointments_scheduled) * 0.4 +
        (100 - (vm.no_shows * 100.0 / vm.total_appointments_scheduled)) * 0.3 +
        (vm.unique_patients * 10.0 / vm.completed_visits) * 0.2 +
        (fe.realized_revenue * 100.0 / (fe.realized_revenue + fe.lost_revenue_opportunity)) * 0.1,
        2
    ) AS overall_clinic_health_score,
    
    -- Trend indicators (vs previous month - simulated)
    CASE 
        WHEN vm.completed_visits > 500 THEN '📈 High Volume'
        WHEN vm.completion_rate_pct > 85 THEN '✅ High Quality'
        WHEN vm.no_show_rate_pct > 15 THEN '⚠️ Attendance Issue'
        ELSE '📊 Standard Operations'
    END AS operational_status
    
FROM date_range dr
CROSS JOIN volume_metrics vm
CROSS JOIN financial_estimates fe;

