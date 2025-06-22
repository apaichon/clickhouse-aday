-- =============================================
-- ClickHouse Session 4: Advanced Querying - Subqueries
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Subquery Basics
-- =============================================

-- Subquery in WHERE clause
SELECT *
FROM policies
WHERE coverage_amount > (
    SELECT avg(coverage_amount) FROM policies
) 
LIMIT 100;

-- Subquery in FROM clause
SELECT policy_type, avg_coverage
FROM (
    SELECT policy_type, avg(coverage_amount) AS avg_coverage
    FROM policies
    GROUP BY policy_type
) AS type_averages;

-- Subquery in SELECT clause
SELECT 
    policy_type,
    coverage_amount,
    coverage_amount / (SELECT avg(coverage_amount) FROM policies) AS relative_to_avg
FROM policies 
LIMIT 100;

-- =============================================
-- 2. Advanced Subquery Techniques
-- =============================================

-- Correlated Subqueries (rewritten as JOIN for ClickHouse optimization)
-- Find policies above average for their type
SELECT 
    p1.policy_type,
    p1.coverage_amount
FROM policies p1
JOIN (
    SELECT 
        policy_type,
        avg(coverage_amount) as avg_coverage
    FROM policies 
    GROUP BY policy_type
) p2 ON p1.policy_type = p2.policy_type
WHERE p1.coverage_amount > p2.avg_coverage
ORDER BY p1.policy_type, p1.coverage_amount DESC
LIMIT 100;

-- Subqueries with EXISTS (rewritten as JOIN)
-- Find customers who have filed claims
SELECT DISTINCT
    c.customer_id,
    c.first_name,
    c.last_name
FROM customers c
JOIN policies p ON p.customer_id = c.customer_id
JOIN claims cl ON p.policy_id = cl.policy_id
ORDER BY c.customer_id;

-- Subqueries with IN
-- Find policies with approved claims
SELECT 
    policy_id,
    policy_number,
    coverage_amount
FROM policies
WHERE policy_id IN (
    SELECT policy_id
    FROM claims
    WHERE claim_status = 'Approved'
    AND claim_amount > 50000
);

-- Subqueries with ANY/ALL
-- Find claims greater than ANY Universal Life policy premium
SELECT 
    claim_type,
    claim_amount
FROM claims
WHERE claim_amount > ANY (
    SELECT premium_amount
    FROM policies
    WHERE policy_type = 'Universal Life'
) 
LIMIT 100;

-- =============================================
-- 3. Practical Subquery Examples for Insurance Analysis
-- =============================================

-- Top Customers by Coverage by Policy Type
SELECT 
    type_ranking.policy_type,
    type_ranking.customer_id,
    type_ranking.first_name,
    type_ranking.last_name,
    type_ranking.total_coverage
FROM (
    SELECT 
        p.policy_type,
        c.customer_id,
        c.first_name,
        c.last_name,
        sum(p.coverage_amount) AS total_coverage,
        row_number() OVER (
            PARTITION BY p.policy_type 
            ORDER BY sum(p.coverage_amount) DESC
        ) AS type_rank
    FROM policies p
    JOIN customers c ON p.customer_id = c.customer_id
    WHERE p.status = 'Active'
    GROUP BY p.policy_type, c.customer_id, c.first_name, c.last_name
) AS type_ranking
WHERE type_ranking.type_rank <= 3
ORDER BY type_ranking.policy_type, type_ranking.type_rank;

-- Claims Above Daily Average
-- Find claims that exceed the daily average by 50%+
SELECT 
    c1.claim_id,
    c1.policy_id,
    c1.claim_amount,
    c1.claim_type,
    c1.date,
    p.policy_number,
    cu.first_name,
    c2.avg_claim_amount
FROM (
    SELECT 
        claim_id,
        policy_id,
        toDate(reported_date) AS date,
        claim_type,
        claim_amount,
        claim_status
    FROM claims
) c1
JOIN policies p ON c1.policy_id = p.policy_id
JOIN customers cu ON p.customer_id = cu.customer_id
JOIN (
    SELECT 
        avg(claim_amount) * 1.5 as avg_claim_amount,
        claim_type,
        toDate(reported_date) AS date
    FROM claims
    GROUP BY claim_type, date
) c2 ON c1.date = c2.date AND c1.claim_type = c2.claim_type
WHERE c1.claim_amount > c2.avg_claim_amount
LIMIT 100;

-- =============================================
-- 4. Complex Business Analysis with Subqueries
-- =============================================

-- High-Risk Customers Analysis
-- Find customers with claims exceeding 80% of their total coverage
SELECT 
    customer_analysis.customer_id,
    customer_analysis.first_name,
    customer_analysis.last_name,
    customer_analysis.total_coverage,
    customer_analysis.total_claims,
    customer_analysis.claim_ratio
FROM (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        sum(p.coverage_amount) AS total_coverage,
        sum(cl.claim_amount) AS total_claims,
        sum(cl.claim_amount) / sum(p.coverage_amount) AS claim_ratio
    FROM customers c
    JOIN policies p ON c.customer_id = p.customer_id
    JOIN claims cl ON p.policy_id = cl.policy_id
    WHERE p.status = 'Active'
    AND cl.claim_status IN ('Approved', 'Paid')
    GROUP BY c.customer_id, c.first_name, c.last_name
) AS customer_analysis
WHERE customer_analysis.claim_ratio > 0.8
ORDER BY customer_analysis.claim_ratio DESC;

-- Policy Performance by Agent Territory
SELECT 
    territory_stats.territory,
    territory_stats.total_policies,
    territory_stats.total_premiums,
    territory_stats.avg_premium,
    territory_stats.territory_rank
FROM (
    SELECT 
        a.territory,
        count(p.policy_id) AS total_policies,
        sum(p.premium_amount) AS total_premiums,
        avg(p.premium_amount) AS avg_premium,
        rank() OVER (ORDER BY sum(p.premium_amount) DESC) AS territory_rank
    FROM agents a
    JOIN policies p ON a.agent_id = p.agent_id
    WHERE p.status = 'Active'
    GROUP BY a.territory
) AS territory_stats
WHERE territory_stats.territory_rank <= 5
ORDER BY territory_stats.territory_rank;

-- Seasonal Policy Trends
-- Compare current month performance to historical averages
SELECT 
    current_month.month,
    current_month.policy_type,
    current_month.policies_issued,
    current_month.total_premiums,
    historical.avg_monthly_policies,
    historical.avg_monthly_premiums,
    round((current_month.policies_issued - historical.avg_monthly_policies) / historical.avg_monthly_policies * 100, 2) AS policy_growth_percent,
    round((current_month.total_premiums - historical.avg_monthly_premiums) / historical.avg_monthly_premiums * 100, 2) AS premium_growth_percent
FROM (
    SELECT 
        toStartOfMonth(start_date) AS month,
        policy_type,
        count() AS policies_issued,
        sum(premium_amount) AS total_premiums
    FROM policies
    WHERE toStartOfMonth(start_date) = toStartOfMonth(today())
    AND status = 'Active'
    GROUP BY month, policy_type
) AS current_month
JOIN (
    SELECT 
        policy_type,
        avg(monthly_policies) AS avg_monthly_policies,
        avg(monthly_premiums) AS avg_monthly_premiums
    FROM (
        SELECT 
            toStartOfMonth(start_date) AS month,
            policy_type,
            count() AS monthly_policies,
            sum(premium_amount) AS monthly_premiums
        FROM policies
        WHERE start_date >= today() - INTERVAL 12 MONTH
        AND start_date < toStartOfMonth(today())
        AND status = 'Active'
        GROUP BY month, policy_type
    ) AS monthly_data
    GROUP BY policy_type
) AS historical ON current_month.policy_type = historical.policy_type
ORDER BY current_month.policy_type;