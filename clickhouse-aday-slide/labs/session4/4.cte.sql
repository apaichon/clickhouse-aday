-- =============================================
-- ClickHouse Session 4: Advanced Querying - Common Table Expressions (CTEs)
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. CTE Basics
-- =============================================

-- Basic WITH clause example
WITH avg_by_policy_type AS (
    SELECT policy_type, avg(premium_amount) AS avg_premium
    FROM policies
    GROUP BY policy_type
)

SELECT 
    p.policy_type,
    p.premium_amount,
    a.avg_premium,
    p.premium_amount - a.avg_premium AS diff_from_avg
FROM policies p
JOIN avg_by_policy_type a ON p.policy_type = a.policy_type
WHERE p.status = 'Active'
  AND p.premium_amount > a.avg_premium * 1.5
ORDER BY p.policy_type, diff_from_avg DESC
LIMIT 100;

-- =============================================
-- 2. Multiple CTEs and CTE Chaining
-- =============================================

-- Multiple CTEs - Daily policy and claims metrics
WITH daily_policies AS (
    SELECT 
        toDate(start_date) AS date, 
        count() AS policies_issued,
        sum(premium_amount) AS daily_premiums
    FROM policies
    WHERE status = 'Active'
    GROUP BY date
),

daily_claims AS (
    SELECT 
        toDate(reported_date) AS date, 
        count() AS claims_reported,
        sum(claim_amount) AS daily_claims_amount
    FROM claims
    GROUP BY date
)

-- Combine the CTEs to get daily metrics
SELECT 
    dp.date,
    dp.policies_issued,
    COALESCE(dc.claims_reported, 0) AS claims_reported,
    dp.daily_premiums,
    COALESCE(dc.daily_claims_amount, 0) AS daily_claims_amount,
    CASE WHEN dp.policies_issued > 0 
         THEN dc.claims_reported / dp.policies_issued 
         ELSE 0 END AS claims_to_policy_ratio
FROM daily_policies dp
LEFT JOIN daily_claims dc ON dp.date = dc.date
WHERE dp.date >= '2024-01-01'
  AND dp.date <= '2024-01-31'
ORDER BY dp.date;

-- Chained CTEs - Customer categorization analysis
WITH customer_policies AS (
    SELECT 
        customer_id, 
        coverage_amount, 
        premium_amount, 
        policy_type
    FROM policies
    WHERE status = 'Active'
),

customer_totals AS (
    SELECT 
        customer_id,
        sum(coverage_amount) AS total_coverage,
        count() AS policy_count,
        avg(premium_amount) AS avg_premium
    FROM customer_policies
    GROUP BY customer_id
)

-- Categorize customers
SELECT 
    c.first_name,
    c.last_name,
    t.total_coverage,
    t.policy_count,
    t.avg_premium,
    multiIf(
        t.total_coverage < 100000, 'Low Coverage',
        t.total_coverage < 500000, 'Medium Coverage',
        'High Coverage'
    ) AS coverage_category
FROM customer_totals t
JOIN customers c ON t.customer_id = c.customer_id
ORDER BY t.total_coverage DESC
LIMIT 100;

-- =============================================
-- 3. Real-World CTE Examples for Insurance Analytics
-- =============================================

-- Monthly Policy Performance Trends
WITH monthly_by_type AS (
    SELECT 
        toStartOfMonth(start_date) AS month,
        policy_type,
        count() AS policies_issued,
        sum(coverage_amount) AS total_coverage,
        sum(premium_amount) AS total_premiums
    FROM policies
    WHERE status = 'Active'
    GROUP BY month, policy_type
),

monthly_with_previous AS (
    SELECT 
        m1.month,
        m1.policy_type,
        m1.policies_issued,
        m1.total_coverage,
        m1.total_premiums,
        anyLast(m1.total_premiums) OVER (
            PARTITION BY m1.policy_type 
            ORDER BY m1.month
            ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
        ) AS prev_month_premiums,
        anyLast(m1.policies_issued) OVER (
            PARTITION BY m1.policy_type 
            ORDER BY m1.month
            ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
        ) AS prev_month_count
    FROM monthly_by_type m1
    ORDER BY m1.month, m1.policy_type
)

-- Calculate growth rates
SELECT 
    month,
    policy_type,
    policies_issued,
    total_premiums,
    prev_month_premiums,
    CASE 
        WHEN prev_month_premiums > 0 
        THEN round((total_premiums - prev_month_premiums) / prev_month_premiums * 100, 1)
        ELSE NULL
    END AS premium_growth,
    CASE 
        WHEN prev_month_count > 0 
        THEN round((policies_issued - prev_month_count) / prev_month_count * 100, 1)
        ELSE NULL
    END AS policy_count_growth
FROM monthly_with_previous
WHERE prev_month_premiums IS NOT NULL
ORDER BY month DESC, policy_type;

-- Customer Risk Cohort Analysis
WITH customer_first_policy AS (
    SELECT 
        customer_id,
        min(toStartOfMonth(p.start_date)) AS first_policy_month
    FROM policies p
    WHERE p.status = 'Active'
    GROUP BY p.customer_id
),

customer_policies_by_month AS (
    SELECT 
        cfp.first_policy_month AS cohort,
        toStartOfMonth(p.start_date) AS policy_month,
        count(DISTINCT p.customer_id) AS customer_count,
        sum(p.coverage_amount) AS total_coverage
    FROM policies p
    JOIN customer_first_policy cfp ON p.customer_id = cfp.customer_id
    WHERE p.status = 'Active'
    GROUP BY cohort, policy_month
)

-- Calculate month number from cohort start
SELECT 
    cohort,
    policy_month,
    dateDiff('month', cohort, policy_month) AS month_number,
    customer_count,
    total_coverage,
    total_coverage / customer_count AS avg_coverage_per_customer
FROM customer_policies_by_month
ORDER BY cohort, policy_month;

-- =============================================
-- 4. Advanced CTE Patterns for Complex Analysis
-- =============================================

-- Agent Performance Analysis with Territory Benchmarking
WITH agent_performance AS (
    SELECT 
        a.agent_id,
        a.first_name,
        a.last_name,
        a.territory,
        count(p.policy_id) AS policies_sold,
        sum(p.premium_amount) AS total_premiums,
        sum(p.coverage_amount) AS total_coverage,
        count(c.claim_id) AS claims_filed,
        sum(c.claim_amount) AS total_claims
    FROM agents a
    LEFT JOIN policies p ON a.agent_id = p.agent_id AND p.status = 'Active'
    LEFT JOIN claims c ON p.policy_id = c.policy_id AND c.claim_status IN ('Approved', 'Paid')
    GROUP BY a.agent_id, a.first_name, a.last_name, a.territory
),

territory_benchmarks AS (
    SELECT 
        territory,
        avg(total_premiums) AS territory_avg_premiums,
        avg(policies_sold) AS territory_avg_policies,
        avg(CASE WHEN total_coverage > 0 THEN total_claims / total_coverage ELSE 0 END) AS territory_avg_loss_ratio
    FROM agent_performance
    WHERE policies_sold > 0
    GROUP BY territory
)

SELECT 
    ap.agent_id,
    ap.first_name,
    ap.last_name,
    ap.territory,
    ap.policies_sold,
    ap.total_premiums,
    tb.territory_avg_premiums,
    round((ap.total_premiums - tb.territory_avg_premiums) / tb.territory_avg_premiums * 100, 2) AS premium_vs_territory_avg,
    CASE WHEN ap.total_coverage > 0 THEN round(ap.total_claims / ap.total_coverage * 100, 2) ELSE 0 END AS loss_ratio,
    round(tb.territory_avg_loss_ratio * 100, 2) AS territory_avg_loss_ratio,
    CASE 
        WHEN ap.total_premiums > tb.territory_avg_premiums * 1.2 THEN 'Top Performer'
        WHEN ap.total_premiums > tb.territory_avg_premiums * 0.8 THEN 'Average Performer'
        ELSE 'Below Average'
    END AS performance_category
FROM agent_performance ap
JOIN territory_benchmarks tb ON ap.territory = tb.territory
WHERE ap.policies_sold > 0
ORDER BY ap.total_premiums DESC;

-- Policy Lifecycle and Claims Pattern Analysis
WITH policy_lifecycle AS (
    SELECT 
        p.policy_id,
        p.customer_id,
        p.policy_type,
        p.start_date,
        p.coverage_amount,
        p.premium_amount,
        dateDiff('month', p.start_date, today()) AS policy_age_months,
        CASE 
            WHEN dateDiff('month', p.start_date, today()) <= 12 THEN 'New (0-12 months)'
            WHEN dateDiff('month', p.start_date, today()) <= 36 THEN 'Established (1-3 years)'
            ELSE 'Mature (3+ years)'
        END AS policy_age_category
    FROM policies p
    WHERE p.status = 'Active'
),

claims_by_policy_age AS (
    SELECT 
        pl.policy_age_category,
        pl.policy_type,
        count(DISTINCT pl.policy_id) AS total_policies,
        count(c.claim_id) AS total_claims,
        sum(c.claim_amount) AS total_claim_amount,
        avg(c.claim_amount) AS avg_claim_amount
    FROM policy_lifecycle pl
    LEFT JOIN claims c ON pl.policy_id = c.policy_id AND c.claim_status IN ('Approved', 'Paid')
    GROUP BY pl.policy_age_category, pl.policy_type
)

SELECT 
    policy_age_category,
    policy_type,
    total_policies,
    total_claims,
    total_claim_amount,
    avg_claim_amount,
    round(CASE WHEN total_policies > 0 THEN total_claims / total_policies * 100 ELSE 0 END, 2) AS claim_frequency_percent,
    round(CASE WHEN total_policies > 0 THEN total_claim_amount / total_policies ELSE 0 END, 2) AS avg_claim_per_policy
FROM claims_by_policy_age
ORDER BY policy_age_category, policy_type;