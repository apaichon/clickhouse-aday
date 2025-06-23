-- =============================================
-- ClickHouse Session 6: Performance Optimization - Materialized Views
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Basic Materialized Views
-- =============================================

-- Daily policy issuance summary
CREATE MATERIALIZED VIEW daily_policy_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(policy_date)
ORDER BY (policy_date, policy_type, agent_id)
AS
SELECT 
    toDate(effective_date) as policy_date,
    policy_type,
    agent_id,
    count() as policies_issued,
    sum(coverage_amount) as total_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE status = 'Active'
GROUP BY policy_date, policy_type, agent_id;

-- Monthly claims summary
CREATE MATERIALIZED VIEW monthly_claims_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(claim_month)
ORDER BY (claim_month, claim_type, claim_status)
AS
SELECT 
    toStartOfMonth(reported_date) as claim_month,
    claim_type,
    claim_status,
    count() as claims_count,
    sum(claim_amount) as total_claim_amount,
    sum(approved_amount) as total_approved_amount
FROM claims
WHERE _sign > 0
GROUP BY claim_month, claim_type, claim_status;

-- =============================================
-- 2. Real-time Analytics Materialized Views
-- =============================================

-- Customer risk profile view
CREATE MATERIALIZED VIEW customer_risk_profile
ENGINE = ReplacingMergeTree()
PARTITION BY toYYYYMM(last_updated)
ORDER BY customer_id
AS
SELECT 
    p.customer_id,
    count(p.policy_id) as total_policies,
    sum(p.coverage_amount) as total_coverage,
    sum(p.premium_amount) as total_premiums,
    count(c.claim_id) as total_claims,
    sum(c.claim_amount) as total_claim_amount,
    CASE 
        WHEN sum(p.coverage_amount) > 0 
        THEN sum(c.claim_amount) / sum(p.coverage_amount) * 100
        ELSE 0 
    END as claim_ratio_percent,
    now() as last_updated
FROM policies p
LEFT JOIN claims c ON p.policy_id = c.policy_id AND c._sign > 0
WHERE p.status = 'Active'
GROUP BY p.customer_id;

-- Agent performance dashboard
CREATE MATERIALIZED VIEW agent_performance_dashboard
ENGINE = ReplacingMergeTree()
PARTITION BY toYYYYMM(last_updated)
ORDER BY agent_id
AS
SELECT 
    a.agent_id,
    a.first_name,
    a.last_name,
    a.territory,
    count(p.policy_id) as policies_sold,
    sum(p.premium_amount) as total_premiums,
    avg(p.coverage_amount) as avg_coverage,
    uniq(p.customer_id) as unique_customers,
    sum(p.premium_amount) * a.commission_rate as estimated_commission,
    now() as last_updated
FROM agents a
LEFT JOIN policies p ON a.agent_id = p.agent_id AND p.status = 'Active'
WHERE a._sign > 0 AND a.is_active = 1
GROUP BY a.agent_id, a.first_name, a.last_name, a.territory, a.commission_rate;

-- =============================================
-- 3. Aggregation Materialized Views
-- =============================================

-- Policy type performance summary
CREATE MATERIALIZED VIEW policy_type_performance
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(summary_date)
ORDER BY (summary_date, policy_type)
AS
SELECT 
    toDate(effective_date) as summary_date,
    policy_type,
    count() as policies_issued,
    sum(coverage_amount) as total_coverage,
    sum(premium_amount) as total_premiums,
    avg(coverage_amount) as avg_coverage,
    avg(premium_amount) as avg_premium
FROM policies
WHERE status IN ('Active', 'Pending')
GROUP BY summary_date, policy_type;

-- Claims processing efficiency
CREATE MATERIALIZED VIEW claims_processing_efficiency
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(processing_date)
ORDER BY (processing_date, claim_type, adjuster_id)
AS
SELECT 
    toDate(reported_date) as processing_date,
    claim_type,
    adjuster_id,
    count() as claims_processed,
    sum(claim_amount) as total_claimed,
    sum(approved_amount) as total_approved,
    avg(dateDiff('day', reported_date, now())) as avg_processing_days,
    sum(CASE WHEN claim_status = 'Approved' THEN 1 ELSE 0 END) as approved_count,
    sum(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) as denied_count
FROM claims
WHERE _sign > 0
GROUP BY processing_date, claim_type, adjuster_id;

-- =============================================
-- 4. Querying Materialized Views
-- =============================================

-- Query daily policy summary
SELECT 
    policy_date,
    policy_type,
    sum(policies_issued) as total_policies,
    sum(total_coverage) as total_coverage,
    sum(total_premiums) as total_premiums
FROM daily_policy_summary
WHERE policy_date >= today() - INTERVAL 30 DAY
GROUP BY policy_date, policy_type
ORDER BY policy_date DESC, policy_type;

-- Query monthly claims trends
SELECT 
    claim_month,
    claim_type,
    sum(claims_count) as total_claims,
    sum(total_claim_amount) as total_amount,
    sum(total_approved_amount) as approved_amount,
    sum(total_approved_amount) / sum(total_claim_amount) * 100 as approval_rate
FROM monthly_claims_summary
WHERE claim_month >= toStartOfMonth(today()) - INTERVAL 12 MONTH
GROUP BY claim_month, claim_type
ORDER BY claim_month DESC, claim_type;

-- Query customer risk profiles
SELECT 
    customer_id,
    total_policies,
    total_coverage,
    total_premiums,
    total_claims,
    total_claim_amount,
    claim_ratio_percent
FROM customer_risk_profile
WHERE claim_ratio_percent > 50  -- High-risk customers
ORDER BY claim_ratio_percent DESC
LIMIT 100;

-- Query agent performance
SELECT 
    territory,
    sum(policies_sold) as total_policies,
    sum(total_premiums) as territory_premiums,
    avg(avg_coverage) as avg_coverage_per_agent,
    sum(estimated_commission) as total_commissions
FROM agent_performance_dashboard
GROUP BY territory
ORDER BY territory_premiums DESC;

-- =============================================
-- 5. Materialized View Maintenance
-- =============================================

-- Check materialized view status
SELECT 
    database,
    table,
    engine,
    total_rows,
    total_bytes
FROM system.tables
WHERE database = 'life_insurance'
  AND engine LIKE '%MaterializedView%'
ORDER BY table;

-- Monitor materialized view performance
SELECT 
    table,
    sum(rows) as total_rows,
    sum(bytes_on_disk) as total_size,
    max(modification_time) as last_modified
FROM system.parts
WHERE database = 'life_insurance'
  AND table IN (
    'daily_policy_summary',
    'monthly_claims_summary',
    'customer_risk_profile',
    'agent_performance_dashboard'
  )
  AND active = 1
GROUP BY table
ORDER BY table;

-- =============================================
-- 6. Cleanup (Optional)
-- =============================================

-- Drop materialized views if needed
-- DROP VIEW IF EXISTS daily_policy_summary;
-- DROP VIEW IF EXISTS monthly_claims_summary;
-- DROP VIEW IF EXISTS customer_risk_profile;
-- DROP VIEW IF EXISTS agent_performance_dashboard;
-- DROP VIEW IF EXISTS policy_type_performance;
-- DROP VIEW IF EXISTS claims_processing_efficiency;