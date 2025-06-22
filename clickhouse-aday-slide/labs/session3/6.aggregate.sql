-- =============================================
-- Basic Aggregations
-- =============================================

-- 1. Count, sum, average
SELECT
    count() AS total_claims,
    sum(claim_amount) AS total_amount,
    avg(claim_amount) AS average_amount
FROM claims;

-- 2. Min, max, statistics for paid claims
SELECT
    min(claim_amount) AS min_amount,
    max(claim_amount) AS max_amount,
    stddevPop(claim_amount) AS std_deviation,
    median(claim_amount) AS median_amount
FROM claims
WHERE claim_status = 'Paid';

-- 3. Group by claim type with multiple aggregates
SELECT
    claim_type,
    count() AS num_claims,
    sum(claim_amount) AS total,
    avg(claim_amount) AS average,
    min(claim_amount) AS minimum,
    max(claim_amount) AS maximum
FROM claims
GROUP BY claim_type;

-- =============================================
-- Advanced Aggregations for Insurance Analysis
-- =============================================

-- 4. Claim status distribution
SELECT 
    claim_status,
    count() AS count
FROM claims
GROUP BY claim_status;

-- 5. Monthly policy issuance
SELECT 
    toYear(effective_date) AS year,
    toMonth(effective_date) AS month,
    policy_type,
    count() AS policy_count,
    sum(coverage_amount) AS monthly_coverage,
    round(avg(premium_amount), 2) AS avg_premium
FROM policies
GROUP BY year, month, policy_type
ORDER BY year, month, policy_type;

-- 6. Claims by customer
SELECT 
    c.customer_id,
    count() AS claim_count,
    sum(c.claim_amount) AS total_claims,
    avg(c.claim_amount) AS avg_claim
FROM claims c
JOIN policies p ON c.policy_id = p.policy_id
GROUP BY c.customer_id
ORDER BY total_claims DESC;

-- 7. Coverage amount categories
SELECT
    multiIf(coverage_amount < 100000, 'Small',
            coverage_amount < 500000, 'Medium',
            coverage_amount < 1000000, 'Large',
            'Very Large') AS coverage_category,
    count() AS count
FROM policies
GROUP BY coverage_category;

-- =============================================
-- Time-based Aggregations
-- =============================================

-- 8. Count, sum, average (repeated for time-based context)
SELECT
    count() AS total_claims,
    sum(claim_amount) AS total_amount,
    avg(claim_amount) AS average_amount
FROM claims;

-- 9. Min, max, statistics for paid claims (repeated)
SELECT
    min(claim_amount) AS min_amount,
    max(claim_amount) AS max_amount,
    stddevPop(claim_amount) AS std_deviation,
    median(claim_amount) AS median_amount
FROM claims
WHERE claim_status = 'Paid';

-- 10. Group by claim type with multiple aggregates (repeated)
SELECT
    claim_type,
    count() AS num_claims,
    sum(claim_amount) AS total,
    avg(claim_amount) AS average,
    min(claim_amount) AS minimum,
    max(claim_amount) AS maximum
FROM claims
GROUP BY claim_type;

-- =============================================
-- Hierarchical and Conditional Aggregations
-- =============================================

-- 11. ROLLUP for hierarchical summaries
SELECT 
    claim_type,
    toYear(reported_date) AS year,
    sum(claim_amount) AS total
FROM claims
GROUP BY claim_type, year
WITH ROLLUP
ORDER BY 
    IF(claim_type = '', 1, 0),
    claim_type,
    IF(year = 0, 1, 0),
    year;

-- 12. Aggregation with HAVING clause
SELECT 
    claim_type,
    claim_status,
    count() AS count,
    sum(claim_amount) AS total
FROM claims
GROUP BY claim_type, claim_status
HAVING count > 10 
   AND total > 100000
ORDER BY 
    claim_type, 
    claim_status;


