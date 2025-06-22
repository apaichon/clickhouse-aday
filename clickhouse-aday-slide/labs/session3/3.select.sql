-- =============================================
-- Basic Selects
-- =============================================

-- 1. Select all columns, limit 5
SELECT *
FROM policies
LIMIT 5;

-- 2. Select specific columns, limit 10
SELECT 
    policy_id,
    customer_id,
    agent_id,
    policy_type,
    start_date
FROM policies
LIMIT 10;

-- 3. Select specific columns, offset 2, limit 1 (LIMIT offset, count is MySQL syntax; in ClickHouse use LIMIT count OFFSET offset)
SELECT 
    policy_id,
    customer_id,
    agent_id,
    policy_type,
    start_date
FROM policies
LIMIT 1 OFFSET 2;

-- =============================================
-- Life Insurance Data Queries
-- =============================================

-- 4. Get all active policies
SELECT 
    policy_id, 
    customer_id, 
    policy_number,
    policy_type,
    coverage_amount,
    premium_amount
FROM policies
WHERE status = 'Active';

-- 5. Find policies with high coverage amounts
SELECT 
    policy_id, 
    customer_id, 
    agent_id, 
    policy_type, 
    coverage_amount,
    premium_amount
FROM policies
WHERE coverage_amount > 500000;

-- 6. Get claims data (updated for new claims structure)
SELECT 
    claim_id,
    policy_id,
    customer_id,
    claim_type,
    claim_number,
    claim_amount,
    approved_amount,
    claim_status,
    incident_date,
    reported_date
FROM claims
LIMIT 10;

-- 7. Policies of type Term Life or Universal Life in 2025
SELECT * FROM policies
WHERE policy_type IN ('Term Life', 'Universal Life')
  AND start_date BETWEEN '2025-01-01' AND '2025-12-31';

-- 8. Multi-column sorting: Recent policies per customer
SELECT 
    policy_id, customer_id, start_date, policy_type
FROM policies
ORDER BY customer_id ASC, 
         start_date DESC
LIMIT 20;

-- 9. High-value policies: Most recent first
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

-- =============================================
-- Updated Queries for Current Table Structure
-- =============================================

-- 10. Get policy details with version information (ReplacingMergeTree)
SELECT 
    policy_id,
    policy_number,
    customer_id,
    policy_type,
    coverage_amount,
    premium_amount,
    deductible_amount,
    status,
    effective_date,
    end_date,
    version,
    created_at,
    updated_at
FROM policies
WHERE status = 'Active'
LIMIT 10;

-- 11. Get claims with complete information (CollapsingMergeTree)
SELECT 
    claim_id,
    policy_id,
    customer_id,
    claim_type,
    claim_number,
    incident_date,
    reported_date,
    claim_amount,
    approved_amount,
    claim_status,
    description,
    adjuster_id
FROM claims
WHERE claim_status IN ('Reported', 'Under Review', 'Approved')
  AND _sign = 1
LIMIT 10;

-- 12. Join policies with claims (updated column names)
SELECT 
    p.policy_number,
    p.customer_id,
    p.policy_type,
    p.coverage_amount,
    c.claim_number,
    c.claim_amount,
    c.approved_amount,
    c.claim_type,
    c.claim_status,
    c.reported_date
FROM policies p
LEFT JOIN claims c ON p.policy_id = c.policy_id AND c._sign = 1
WHERE p.status = 'Active'
LIMIT 10;

-- 13. Get customers with their policies
SELECT 
    cust.customer_id,
    cust.first_name,
    cust.last_name,
    cust.email,
    p.policy_number,
    p.policy_type,
    p.coverage_amount,
    p.status
FROM customers cust
JOIN policies p ON cust.customer_id = p.customer_id
WHERE cust._sign = 1 AND p.status = 'Active'
LIMIT 10;

-- 14. Get agents with their policy counts
SELECT 
    a.agent_id,
    a.first_name,
    a.last_name,
    a.territory,
    count(p.policy_id) as policy_count,
    sum(p.coverage_amount) as total_coverage
FROM agents a
LEFT JOIN policies p ON a.agent_id = p.agent_id
WHERE a._sign = 1 AND a.is_active = 1
GROUP BY a.agent_id, a.first_name, a.last_name, a.territory
ORDER BY policy_count DESC
LIMIT 10;

-- 15. Claims analysis with policy information
SELECT 
    c.claim_number,
    c.claim_type,
    c.claim_status,
    c.claim_amount,
    c.approved_amount,
    p.policy_type,
    p.coverage_amount,
    round(c.claim_amount / p.coverage_amount * 100, 2) as claim_ratio_percent
FROM claims c
JOIN policies p ON c.policy_id = p.policy_id
WHERE c._sign = 1 
  AND c.claim_status IN ('Approved', 'Paid')
ORDER BY claim_ratio_percent DESC
LIMIT 10;

-- =============================================
-- Table Structure and Data Verification
-- =============================================

-- 16. Examine table structures
DESCRIBE TABLE policies;
DESCRIBE TABLE claims;
DESCRIBE TABLE customers;
DESCRIBE TABLE agents;

-- 17. Get count of rows in each table (considering CollapsingMergeTree)
SELECT 'policies' as table_name, count() as row_count
FROM policies
UNION ALL
SELECT 'claims' as table_name, count() as row_count
FROM claims
WHERE _sign = 1
UNION ALL
SELECT 'customers' as table_name, count() as row_count
FROM customers
WHERE _sign = 1
UNION ALL
SELECT 'agents' as table_name, count() as row_count
FROM agents
WHERE _sign = 1;

-- 18. Policy status distribution
SELECT 
    status,
    count() as policy_count,
    sum(coverage_amount) as total_coverage
FROM policies
GROUP BY status
ORDER BY policy_count DESC;

-- 19. Claims status distribution
SELECT 
    claim_status,
    count() as claim_count,
    sum(claim_amount) as total_claim_amount,
    sum(approved_amount) as total_approved_amount
FROM claims
WHERE _sign = 1
GROUP BY claim_status
ORDER BY claim_count DESC;

-- 20. Recent claims activity
SELECT 
    claim_id,
    claim_number,
    claim_type,
    claim_amount,
    claim_status,
    reported_date,
    description
FROM claims
WHERE _sign = 1
  AND reported_date >= today() - INTERVAL 30 DAY
ORDER BY reported_date DESC
LIMIT 10;