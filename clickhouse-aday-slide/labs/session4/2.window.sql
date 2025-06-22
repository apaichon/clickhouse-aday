-- =============================================
-- ClickHouse Session 4: Advanced Querying - Window Functions
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Window Functions Basics
-- =============================================

-- Basic window function example
SELECT 
    policy_type,
    start_date,
    premium_amount,
    sum(premium_amount) OVER (
        PARTITION BY policy_type 
        ORDER BY start_date
    ) AS running_premium_total,
   
    row_number() OVER (
        PARTITION BY policy_type
        ORDER BY start_date
    ) AS policy_sequence,
        
    avg(premium_amount) OVER (
        PARTITION BY policy_type
    ) AS type_avg_premium,
        
    avg(premium_amount) OVER () AS overall_avg_premium
    
FROM policies
WHERE status = 'Active'
  AND start_date >= '2024-01-01'
ORDER BY policy_type, start_date
LIMIT 100;

-- =============================================
-- 2. Ranking and Row Position Window Functions
-- =============================================

-- Ranking Functions
SELECT 
    policy_type,
    coverage_amount,
    -- Regular rank (with gaps)
    rank() OVER (
        PARTITION BY policy_type 
        ORDER BY coverage_amount DESC
    ) AS coverage_rank,
    
    -- Dense rank (no gaps)
    dense_rank() OVER (
        PARTITION BY policy_type 
        ORDER BY coverage_amount DESC
    ) AS dense_coverage_rank,
    
    -- Percentile rank
    percent_rank() OVER (
        PARTITION BY policy_type 
        ORDER BY coverage_amount
    ) AS percentile
    
FROM policies
WHERE status = 'Active' 
  AND start_date >= '2024-01-01'
LIMIT 100;

-- Row Position Functions
SELECT 
    policy_type,
    start_date,
    premium_amount,
    -- Row number
    row_number() OVER (
        PARTITION BY policy_type 
        ORDER BY start_date
    ) AS row_num,
    
    -- Previous row's premium (using lag equivalent)
    anyLast(premium_amount) OVER (
        PARTITION BY policy_type 
        ORDER BY start_date
        ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
    ) AS previous_premium,
    
    -- Next row's premium (using lead equivalent)
    any(premium_amount) OVER (
        PARTITION BY policy_type 
        ORDER BY start_date
        ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING
    ) AS next_premium
    
FROM policies
WHERE status = 'Active' 
  AND start_date >= '2024-01-01'
ORDER BY policy_type, start_date
LIMIT 100;

-- =============================================
-- 3. Window Functions for Time Series Analysis
-- =============================================

-- Running Aggregates
SELECT 
    toDate(start_date) AS date,
    policy_type,
    premium_amount,
    -- Running sum (cumulative premiums)
    sum(premium_amount) OVER (
        PARTITION BY policy_type 
        ORDER BY toDate(start_date)
    ) AS running_premium_total,
    
    -- Daily total
    sum(premium_amount) OVER (
        PARTITION BY policy_type, toDate(start_date)
    ) AS daily_premium_total
    
FROM policies
WHERE status = 'Active' 
  AND start_date >= '2024-01-01' 
ORDER BY policy_type, date
LIMIT 100;

-- Moving Averages
SELECT 
    toDate(start_date) AS date,
    policy_type,
    premium_amount,
    -- 7-day moving average of premiums
    avg(premium_amount) OVER (
        PARTITION BY policy_type 
        ORDER BY toDate(start_date)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7day,
    
    -- Alternative moving average calculation
    avg(premium_amount) OVER (
        PARTITION BY policy_type 
        ORDER BY toDate(start_date)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7day_alt

FROM policies
WHERE status = 'Active' 
  AND toDate(start_date) >= '2024-01-01'
  AND toDate(start_date) <= '2024-01-07'
ORDER BY policy_type, date;

-- =============================================
-- 4. Practical Window Function Examples for Insurance Analysis
-- =============================================

-- Policy Issuance Trend Analysis
SELECT 
    toDate(p.start_date) AS date,
    p.policy_type,
    count() AS policies_issued,
    sum(p.premium_amount) AS daily_premium_total,
    
    -- 7-day moving average of daily totals
    avg(sum(p.premium_amount)) OVER (
        PARTITION BY p.policy_type 
        ORDER BY toDate(p.start_date)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7day,
    
    -- Month-to-date running total
    sum(sum(p.premium_amount)) OVER (
        PARTITION BY p.policy_type, toStartOfMonth(toDate(p.start_date))
        ORDER BY toDate(p.start_date)
    ) AS month_to_date_total
    
FROM policies p
WHERE status = 'Active' 
  AND toDate(start_date) >= '2024-01-01'
  AND toDate(start_date) <= '2024-01-31'
GROUP BY 
    toDate(p.start_date),
    p.policy_type
ORDER BY p.policy_type, date;

-- Customer Policy Pattern Analysis
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    p.coverage_amount,
    p.start_date,
    -- Difference from customer's average
    p.coverage_amount - avg(p.coverage_amount) OVER (
        PARTITION BY c.customer_id
    ) AS diff_from_customer_avg,
    
    -- Rank of policies per customer
    rank() OVER (
        PARTITION BY c.customer_id 
        ORDER BY p.coverage_amount DESC
    ) AS coverage_rank_for_customer,
    
    -- Days since previous policy
    dateDiff('day',
        anyLast(p.start_date) OVER (
            PARTITION BY c.customer_id 
            ORDER BY p.start_date
            ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
        ),
        p.start_date
    ) AS days_since_previous_policy

FROM policies p
JOIN customers c ON p.customer_id = c.customer_id
WHERE p.status = 'Active' 
  AND toDate(p.start_date) >= '2024-01-01'
ORDER BY c.customer_id, p.start_date
LIMIT 100;

-- =============================================
-- 5. Advanced Window Function Patterns
-- =============================================

-- Claims Analysis with Window Functions
SELECT 
    c.claim_type,
    c.reported_date,
    c.claim_amount,
    p.policy_type,
    
    -- Running total of claims by type
    sum(c.claim_amount) OVER (
        PARTITION BY c.claim_type
        ORDER BY c.reported_date
    ) AS running_claim_total,
    
    -- Rank claims within policy type
    dense_rank() OVER (
        PARTITION BY p.policy_type
        ORDER BY c.claim_amount DESC
    ) AS claim_rank_in_policy_type,
    
    -- Compare to average claim for this type
    c.claim_amount - avg(c.claim_amount) OVER (
        PARTITION BY c.claim_type
    ) AS diff_from_type_avg,
    
    -- Days between claims for same policy
    dateDiff('day',
        anyLast(c.reported_date) OVER (
            PARTITION BY c.policy_id
            ORDER BY c.reported_date
            ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
        ),
        c.reported_date
    ) AS days_since_last_claim

FROM claims c
JOIN policies p ON c.policy_id = p.policy_id
WHERE c.claim_status IN ('Approved', 'Paid')
ORDER BY c.claim_type, c.reported_date
LIMIT 100;

-- Agent Performance Ranking
SELECT 
    a.agent_id,
    a.first_name,
    a.last_name,
    a.territory,
    count(p.policy_id) AS policies_sold,
    sum(p.premium_amount) AS total_premiums,
    
    -- Rank agents by premium volume
    rank() OVER (
        ORDER BY sum(p.premium_amount) DESC
    ) AS premium_rank,
    
    -- Rank within territory
    rank() OVER (
        PARTITION BY a.territory
        ORDER BY sum(p.premium_amount) DESC
    ) AS territory_rank,
    
    -- Running total of premiums by territory
    sum(sum(p.premium_amount)) OVER (
        PARTITION BY a.territory
        ORDER BY sum(p.premium_amount) DESC
        ROWS UNBOUNDED PRECEDING
    ) AS territory_running_total,
    
    -- Percentage of territory total
    round(sum(p.premium_amount) / sum(sum(p.premium_amount)) OVER (
        PARTITION BY a.territory
    ) * 100, 2) AS territory_percentage

FROM agents a
LEFT JOIN policies p ON a.agent_id = p.agent_id AND p.status = 'Active'
WHERE p.policy_id IS NOT NULL
GROUP BY a.agent_id, a.first_name, a.last_name, a.territory
ORDER BY premium_rank;


