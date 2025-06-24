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


CREATE MATERIALIZED VIEW daily_claims_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, claim_type)
AS
SELECT
    toDate(reported_date) AS date,
    claim_type,
    count() AS claim_count,
    sum(claim_amount) AS total_amount,
    min(claim_amount) AS min_amount,
    max(claim_amount) AS max_amount,
    uniq(policy_id) AS unique_policies,
    uniqExact(customer_id) AS unique_customers
FROM claims c
JOIN policies p ON c.policy_id = p.policy_id
GROUP BY date, claim_type;



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


-- More flexible aggregation with state functions
CREATE MATERIALIZED VIEW claims_stats_aggr_mv
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, claim_type)
AS
SELECT
    toDate(reported_date) AS date,
    claim_type,
    countState() AS claim_count,
    sumState(claim_amount) AS sum_amount,
    avgState(claim_amount) AS avg_amount,
    quantilesState(0.5, 0.9, 0.95)(claim_amount) AS amount_quantiles
FROM claims
GROUP BY date, claim_type;

insert into claims_stats_aggr_mv
SELECT
    toDate(reported_date) AS date,
    claim_type,
    countState() AS claim_count,
    sumState(claim_amount) AS sum_amount,
    avgState(claim_amount) AS avg_amount,
    quantilesState(0.5, 0.9, 0.95)(claim_amount) AS amount_quantiles
FROM claims
GROUP BY date, claim_type;

-- Then query with corresponding Merge functions
SELECT
    date,
    claim_type,
    countMerge(claim_count) AS claim_count,
    sumMerge(sum_amount) AS total_amount,
    avgMerge(avg_amount) AS average_amount,
    quantilesMerge(0.5, 0.9, 0.95)(amount_quantiles) AS quantiles
FROM claims_stats_aggr_mv
GROUP BY date, claim_type
ORDER BY date ASC, claim_type ASC;


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


-- =============================================
-- 4. Real-time Materialized Views
-- =============================================


CREATE TABLE policy_summary
(
    date Date,
    policy_count UInt64,
    total_coverage Decimal64(2)
)
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date);

CREATE MATERIALIZED VIEW policy_summary_mv
TO policy_summary
AS
SELECT
    toDate(p.effective_date) AS date,
    count() AS policy_count,
    sum(p.coverage_amount) AS total_coverage
FROM policies p 
WHERE p.policy_type = 'Term Life'
GROUP BY date;


insert into policy_summary
SELECT
    toDate(p.effective_date) AS date,
    count() AS policy_count,
    sum(p.coverage_amount) AS total_coverage
FROM policies p 
WHERE p.policy_type = 'Term Life'
GROUP BY date;


-- =============================================
-- 5. Live Dashboard with Materialized Views
-- =============================================

CREATE MATERIALIZED VIEW regulatory_dashboard_mv
ENGINE = SummingMergeTree()
PARTITION BY toStartOfDay(event_time)
ORDER BY (event_time, dimension)
TTL event_time + INTERVAL 90 DAY
AS
SELECT
    toStartOfHour(reported_date) AS event_time,
    claim_status AS dimension,
    count() AS event_count,
    sum(claim_amount) AS amount
FROM claims
WHERE reported_date BETWEEN now() - INTERVAL 90 DAY AND now()
GROUP BY event_time, dimension
ORDER BY event_time DESC;

INSERT INTO regulatory_dashboard_mv
SELECT
    toStartOfHour(reported_date) AS event_time,
    claim_status AS dimension,
    count() AS event_count,
    sum(claim_amount) AS amount
FROM claims
WHERE reported_date BETWEEN now() - INTERVAL 90 DAY AND now()
GROUP BY event_time, dimension
ORDER BY event_time DESC;

-- Query for regulatory dashboard
SELECT
    event_time,
    dimension,
    sum(event_count) AS count,
    sum(amount) AS total_amount
FROM regulatory_dashboard_mv
WHERE event_time >= now() - INTERVAL 24 HOUR
GROUP BY event_time, dimension
ORDER BY event_time;



-- =============================================
-- 6. Materialized View Maintenance
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