-- =============================================
-- 1. Policy Issuance Trends by Type
-- =============================================

-- Monthly policy issuance trends by type
SELECT 
    toStartOfMonth(effective_date) AS month,
    policy_type,
    count() AS policy_count,
    sum(coverage_amount) AS monthly_coverage,
    round(avg(premium_amount), 2) AS average_premium
FROM policies
GROUP BY month, policy_type
ORDER BY month DESC, policy_type;

-- =============================================
-- 2. Customer Risk Profile Statistics
-- =============================================

-- Insert policies with known UUIDs for customer risk statistics
INSERT INTO life_insurance.policies (
    policy_id, customer_id, agent_id, policy_type, policy_number,
    coverage_amount, premium_amount, deductible_amount, effective_date, end_date,
    status, created_at, updated_at, version
) VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 1001, 201, 'Term Life', 'LIFE-2025-013', 600000.00, 1440.00, 0.00, toDate('2025-03-01'), toDate('2045-03-01'), 'Active', now(), now(), 1),
    ('550e8400-e29b-41d4-a716-446655440001', 1002, 201, 'Whole Life', 'LIFE-2025-014', 300000.00, 2700.00, 0.00, toDate('2025-03-15'), toDate('2045-03-15'), 'Active', now(), now(), 1),
    ('550e8400-e29b-41d4-a716-446655440002', 1003, 202, 'Universal Life', 'LIFE-2025-015', 800000.00, 3840.00, 0.00, toDate('2025-04-01'), toDate('2045-04-01'), 'Active', now(), now(), 1);

-- Insert claims with matching policy_ids
INSERT INTO life_insurance.claims (
    claim_id, policy_id, customer_id, claim_type, claim_number,
    incident_date, reported_date, claim_amount, approved_amount,
    claim_status, description, adjuster_id, _sign
) VALUES
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440000', 1001, 'Death', 'CLM-RISK-001', toDate('2025-03-20'), now(), 600000.00, 600000.00, 'Paid', 'Death benefit claim paid', 301, 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440001', 1002, 'Disability', 'CLM-RISK-002', toDate('2025-03-25'), now(), 50000.00, 0.00, 'Under Review', 'Disability claim under review', 302, 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440002', 1003, 'Surrender', 'CLM-RISK-003', toDate('2025-04-10'), now(), 75000.00, 75000.00, 'Paid', 'Policy surrender completed', 303, 1);

-- Customer risk profile statistics query
SELECT 
    p.customer_id,
    uniq(p.agent_id) AS agents_worked_with,
    count(c.claim_id) AS claim_count,
    sum(c.claim_amount) AS total_claims,
    max(c.claim_amount) AS largest_claim,
    min(c.reported_date) AS first_claim,
    max(c.reported_date) AS last_claim,
    sum(p.coverage_amount) AS total_coverage,
    sum(p.premium_amount) AS total_premiums
FROM policies p
LEFT JOIN claims c ON p.policy_id = c.policy_id AND c._sign = 1
GROUP BY p.customer_id
HAVING claim_count > 0
ORDER BY total_claims DESC;

-- =============================================
-- 3. Claims Processing Efficiency by Month
-- =============================================

SELECT 
    toStartOfMonth(reported_date) AS month,
    claim_status,
    count() AS count,
    round(count() / sum(count()) OVER (PARTITION BY month) * 100, 2) AS percentage
FROM claims
GROUP BY month, claim_status
ORDER BY month DESC, claim_status;

-- =============================================
-- 4. Find High-Value Claims for Review
-- =============================================

-- Insert policies for high-value claim review
INSERT INTO life_insurance.policies VALUES
    ('550e8400-e29b-41d4-a716-446655440003', 3001, 301, 'Term Life', 'LIFE-2025-016', 1500000.00, 7200.00, 0.00, '2025-01-01', 'Active', now(), now(), 1),
    ('550e8400-e29b-41d4-a716-446655440004', 3002, 302, 'Whole Life', 'LIFE-2025-017', 2000000.00, 12000.00, 0.00, '2025-02-01', 'Active', now(), now(), 1),
    ('550e8400-e29b-41d4-a716-446655440005', 3003, 303, 'Universal Life', 'LIFE-2025-018', 1800000.00, 8640.00, 0.00, '2025-03-01', 'Active', now(), now(), 1);

-- Insert matching claims with correct column count (13 columns)
INSERT INTO life_insurance.claims VALUES
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440003', 3001, 'Death', 'CLM-2025-001', '2025-02-28', now(), 1500000.00, 0.00, 'Reported', 'Death benefit claim for policy holder', 401, 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440004', 3002, 'Disability', 'CLM-2025-002', '2025-03-04', now(), 850000.00, 0.00, 'Reported', 'Disability claim - permanent disability', 402, 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440005', 3003, 'Death', 'CLM-2025-003', '2025-03-09', now(), 725000.00, 0.00, 'Reported', 'Death benefit claim for accidental death', 403, 1);

-- Query: Find high-value claims for review
SELECT 
    c.claim_id,
    p.customer_id,
    p.agent_id,
    p.policy_number,
    c.claim_amount,
    c.claim_type,
    c.claim_status,
    c.reported_date,
    p.coverage_amount,
    p.policy_type
FROM claims c
JOIN policies p ON c.policy_id = p.policy_id
WHERE c.claim_amount > 500000
  AND c.claim_status = 'Reported'
ORDER BY c.claim_amount DESC;

-- =============================================
-- 5. Query Log Analysis (System Table)
-- =============================================

SELECT 
    query_id,
    query,
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%claims%'
  AND event_time > now() - INTERVAL 1 HOUR
ORDER BY query_duration_ms DESC
LIMIT 10;

-- =============================================
-- 6. Policy Portfolio Analysis
-- =============================================

-- Policy portfolio analysis by agent
SELECT 
    p.agent_id,
    count(p.policy_id) AS policy_count,
    sum(p.coverage_amount) AS total_coverage,
    avg(p.premium_amount) AS avg_premium,
    uniq(p.customer_id) AS unique_customers,
    count(c.claim_id) AS total_claims,
    sum(c.claim_amount) AS total_claim_amount,
    round(sum(c.claim_amount) / sum(p.coverage_amount) * 100, 2) AS claim_ratio_percent
FROM policies p
LEFT JOIN claims c ON p.policy_id = c.policy_id
WHERE p.status = 'Active'
GROUP BY p.agent_id
ORDER BY total_coverage DESC;

-- =============================================
-- 7. Claims Ratio Analysis by Policy Type
-- =============================================

SELECT 
    p.policy_type,
    count(DISTINCT p.policy_id) AS total_policies,
    count(c.claim_id) AS total_claims,
    round(count(c.claim_id) / count(DISTINCT p.policy_id) * 100, 2) AS claims_ratio_percent,
    sum(p.coverage_amount) AS total_coverage,
    sum(c.claim_amount) AS total_claims_paid,
    round(sum(c.claim_amount) / sum(p.coverage_amount) * 100, 2) AS payout_ratio_percent
FROM policies p
LEFT JOIN claims c ON p.policy_id = c.policy_id
GROUP BY p.policy_type
ORDER BY claims_ratio_percent DESC;



