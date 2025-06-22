-- =============================================
-- Claims: Sorting and Limiting
-- =============================================

-- 1. Simple sorting: Top 10 paid claims by amount
SELECT * FROM claims
WHERE claim_status = 'Paid'
ORDER BY claim_amount DESC
LIMIT 10;

-- 2. Order claims by type and amount
SELECT * FROM claims
ORDER BY claim_type ASC, 
         claim_amount DESC
LIMIT 100;

-- 3. Sorting with expressions: Top 100 by claim amount
SELECT 
    claim_id,
    policy_id,
    claim_amount,
    claim_type,
    claim_status
FROM claims
ORDER BY claim_amount DESC
LIMIT 100;

-- 4. Find top 10 largest claims (duplicate query, kept for clarity)
SELECT * FROM claims
ORDER BY claim_amount DESC
LIMIT 10;

-- 5. Get 10 random claims for review
SELECT *
FROM claims
ORDER BY rand()
LIMIT 10;

-- 6. Largest claims by type
SELECT 
    claim_type,
    max(claim_amount) AS max_amount,
    sum(claim_amount) AS total
FROM claims
GROUP BY claim_type
ORDER BY total DESC;

-- =============================================
-- Policies: Sorting and Limiting
-- =============================================

-- 7. Multi-column sorting: Recent policies per customer
SELECT 
    policy_id, customer_id, effective_date, policy_type
FROM policies
ORDER BY customer_id ASC, 
         effective_date DESC
LIMIT 20;

-- 8. High-value policies: Most recent first
SELECT 
    policy_id, 
    customer_id,
    coverage_amount,
    premium_amount,
    effective_date
FROM policies
WHERE coverage_amount > 500000
ORDER BY effective_date DESC
LIMIT 100;