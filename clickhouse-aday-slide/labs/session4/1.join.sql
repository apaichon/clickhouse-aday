-- =============================================
-- ClickHouse Session 4: Advanced Querying - JOIN Operations
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Basic JOIN Types
-- =============================================

-- INNER JOIN - Match policies with their claims
SELECT p.policy_id, p.customer_id, p.policy_number, 
       c.claim_amount, c.claim_type
FROM policies p
INNER JOIN claims c 
ON p.policy_id = c.policy_id
LIMIT 100;

-- LEFT JOIN - Get all policies and any claims
SELECT p.policy_id, p.policy_number, 
       c.claim_amount, c.claim_status
FROM policies p
LEFT JOIN claims c 
ON p.policy_id = c.policy_id
LIMIT 100;

-- RIGHT JOIN - Get all claims and their policies
SELECT p.policy_id, p.policy_number, 
       c.claim_amount, c.claim_status
FROM policies p
RIGHT JOIN claims c 
ON p.policy_id = c.policy_id
LIMIT 100;

-- FULL JOIN - Get all policies and all claims
SELECT p.policy_id, p.policy_number, 
       c.claim_id, c.claim_amount
FROM policies p
FULL JOIN claims c 
ON p.policy_id = c.policy_id
LIMIT 100;

-- =============================================
-- 2. Multi-Table JOINs
-- =============================================

-- Claims data with policy and customer information
SELECT 
    -- Customer information
    cu.customer_id,
    cu.first_name,
    cu.last_name,
    
    -- Policy information
    p.policy_number,
    p.policy_type,
    p.effective_date,
    
    -- Claim information
    c.claim_amount,
    c.claim_type,
    c.claim_status
FROM policies p
JOIN claims c 
    ON p.policy_id = c.policy_id
JOIN customers cu 
    ON p.customer_id = cu.customer_id
WHERE c.claim_status = 'Approved'
  AND c.reported_date >= '2024-01-01 00:00:00'
  AND c.reported_date < '2024-07-01 00:00:00'
ORDER BY c.claim_amount DESC
LIMIT 100;

-- =============================================
-- 3. Advanced JOIN Techniques
-- =============================================

-- CROSS JOIN - All possible combinations of policy types and agents
SELECT pt.policy_type, a.agent_id, a.first_name
FROM 
(SELECT DISTINCT policy_type
 FROM policies) AS pt
CROSS JOIN 
(SELECT agent_id, first_name FROM agents LIMIT 10) AS a;

-- JOIN with USING - Simplified join syntax when column names match
SELECT p.policy_number, p.customer_id, c.claim_amount
FROM policies p
JOIN claims c
USING (policy_id)
LIMIT 100;

-- JOIN with Complex Conditions - Matching claims within policy coverage period
SELECT p.policy_id, p.effective_date, p.policy_number, c.claim_amount, c.incident_date
FROM policies p
JOIN claims c
ON c.policy_id = p.policy_id
   AND c.incident_date >= p.effective_date
LIMIT 100;

-- ARRAY JOIN - Explode beneficiary arrays into rows
SELECT customer_id, beneficiary
FROM customers
ARRAY JOIN splitByChar(',', beneficiaries) AS beneficiary
WHERE length(beneficiary) > 0
LIMIT 100;

-- =============================================
-- 4. Real-World JOIN Queries for Insurance Analysis
-- =============================================

-- Monthly Premium Collection by Agent
SELECT 
    toStartOfMonth(p.effective_date) AS month,
    a.agent_id,
    a.first_name,
    a.last_name,
    count() AS policies_sold,
    sum(p.premium_amount) AS total_premiums
    
FROM policies p
JOIN agents a 
    ON p.agent_id = a.agent_id
    
WHERE p.status = 'Active'
GROUP BY month, a.agent_id, a.first_name, a.last_name
ORDER BY month DESC, total_premiums DESC;

-- Customer Policy History with Claims
SELECT 
    c.first_name,
    c.last_name,
    p.policy_number,
    p.coverage_amount,
    p.premium_amount,
    cl.claim_amount,
    cl.claim_status,
    cl.reported_date
    
FROM customers c
JOIN policies p 
    ON c.customer_id = p.customer_id
LEFT JOIN claims cl 
    ON p.policy_id = cl.policy_id
    
WHERE c.customer_id = 1
ORDER BY cl.reported_date DESC;

-- =============================================
-- 5. Performance Optimization Examples
-- =============================================

-- Using GLOBAL JOIN for distributed queries
SELECT p.policy_number, c.claim_amount
FROM policies p
GLOBAL JOIN claims c ON p.policy_id = c.policy_id
WHERE p.status = 'Active'
LIMIT 100;

-- Filter before joining to reduce dataset size
SELECT 
    p.policy_number,
    p.coverage_amount,
    c.claim_amount
FROM (
    SELECT policy_id, policy_number, coverage_amount
    FROM policies 
    WHERE status = 'Active' 
    AND effective_date >= '2024-01-01'
) p
JOIN (
    SELECT policy_id, claim_amount
    FROM claims 
    WHERE claim_status = 'Approved'
    AND claim_amount > 10000
) c ON p.policy_id = c.policy_id;

-- =============================================
-- 6. Complex Business Logic JOINs
-- =============================================

-- Agent Performance with Territory Analysis
SELECT 
    a.agent_id,
    a.first_name,
    a.last_name,
    a.territory,
    count(p.policy_id) AS policies_sold,
    sum(p.coverage_amount) AS total_coverage,
    sum(p.premium_amount) AS total_premiums,
    count(c.claim_id) AS claims_filed,
    sum(c.claim_amount) AS total_claims,
    round(sum(c.claim_amount) / sum(p.coverage_amount) * 100, 2) AS loss_ratio
FROM agents a
LEFT JOIN policies p ON a.agent_id = p.agent_id AND p.status = 'Active'
LEFT JOIN claims c ON p.policy_id = c.policy_id AND c.claim_status IN ('Approved', 'Paid')
GROUP BY a.agent_id, a.first_name, a.last_name, a.territory
HAVING policies_sold > 0
ORDER BY loss_ratio ASC, total_premiums DESC;

-- Policy and Claims Analysis by Customer Segment
SELECT 
    cu.customer_type,
    p.policy_type,
    count(DISTINCT cu.customer_id) AS unique_customers,
    count(p.policy_id) AS total_policies,
    avg(p.coverage_amount) AS avg_coverage,
    avg(p.premium_amount) AS avg_premium,
    count(c.claim_id) AS total_claims,
    avg(c.claim_amount) AS avg_claim_amount,
    round(count(c.claim_id) / count(p.policy_id) * 100, 2) AS claim_frequency_percent
FROM customers cu
JOIN policies p ON cu.customer_id = p.customer_id
LEFT JOIN claims c ON p.policy_id = c.policy_id
WHERE p.status = 'Active'
GROUP BY cu.customer_type, p.policy_type
ORDER BY cu.customer_type, p.policy_type;

