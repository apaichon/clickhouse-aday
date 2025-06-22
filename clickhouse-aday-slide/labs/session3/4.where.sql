-- =============================================
-- Claims: Basic Filtering
-- =============================================

-- 1. Paid claims with amount > 50000 after 2025-01-01
SELECT * FROM claims 
WHERE claim_status = 'Paid'
  AND claim_amount > 50000
  AND reported_date >= '2025-01-01'
LIMIT 100;

-- 2. Claims in March 2025, Death claims only
SELECT 
    claim_id,
    policy_id,
    claim_amount,
    claim_type,
    claim_status,
    reported_date
FROM claims
WHERE toYYYYMM(reported_date) = 202503
  AND claim_type = 'Death'
LIMIT 100;

-- 3. Claims on a specific day, submitted or processing
SELECT * FROM claims
WHERE formatDateTime(reported_date, '%Y-%m-%d') = '2025-03-15'
  AND (claim_status = 'Reported' OR claim_status = 'Under Review')
LIMIT 100;

-- 4. Finding large pending claims
SELECT * FROM claims
WHERE claim_amount > 100000
  AND claim_status = 'Reported'
ORDER BY claim_amount DESC
LIMIT 100;

-- 5. Finding disability and surrender claims (not denied)
SELECT *
FROM claims
WHERE claim_type IN ('Disability', 'Surrender')
  AND claim_amount > 10000
  AND claim_status != 'Denied'
ORDER BY claim_amount DESC
LIMIT 100;

-- =============================================
-- Policies: Filtering and Pattern Matching
-- =============================================

-- 6. Policies of type Term or Universal in 2025
SELECT * FROM policies
WHERE policy_type IN ('Term', 'Universal')
  AND effective_date BETWEEN '2025-01-01' AND '2025-12-31';

-- 7. Policies with policy numbers containing 'LIFE' or high coverage
SELECT * FROM policies
WHERE policy_number LIKE '%LIFE%'
   OR coverage_amount > 750000;

-- =============================================
-- Policies and Claims: Joins and Context
-- =============================================

-- 8. Time-based filtering with policy context (today's claims for customer 1001)
SELECT p.*, c.claim_amount, c.claim_type
FROM policies p
LEFT JOIN claims c ON p.policy_id = c.policy_id
WHERE p.customer_id = 1001
  AND toDate(c.reported_date) = today()
LIMIT 100;
