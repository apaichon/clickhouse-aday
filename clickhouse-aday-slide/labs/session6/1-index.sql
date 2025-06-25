-- =============================================
-- ClickHouse Session 6: Performance Optimization - Indexes
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Primary Key Analysis
-- =============================================

-- Show current table structures and primary keys
SHOW CREATE TABLE customers;
SHOW CREATE TABLE policies;
SHOW CREATE TABLE claims;
SHOW CREATE TABLE agents;

-- Analyze primary key effectiveness for policies
SELECT 
    partition,
    name,
    rows,
    bytes_on_disk,
    primary_key_bytes_in_memory
FROM system.parts
WHERE database = 'life_insurance' 
  AND table = 'policies'
  AND active = 1
ORDER BY partition;

-- =============================================
-- 2. Time-based Indexing
-- =============================================


CREATE TABLE policies_time_optimized
(
    -- same columns as above
    policy_id UUID,
    customer_id UInt64,
    agent_id UInt32,
    policy_type Enum8('Term Life' = 1, 'Whole Life' = 2, 'Universal Life' = 3, 'Variable Life' = 4, 'Endowment' = 5),
    policy_number String,
    coverage_amount Decimal64(2),
    premium_amount Decimal64(2),
    deductible_amount Decimal64(2),
    effective_date Date,
    end_date Date,
    status Enum8('Active' = 1, 'Lapsed' = 2, 'Terminated' = 3, 'Matured' = 4, 'Pending' = 5),
    created_at DateTime DEFAULT now(),
    updated_at DateTime DEFAULT now(),
    version UInt32 DEFAULT 1
)
ENGINE = ReplacingMergeTree(version)
PARTITION BY (toYYYYMM(effective_date), policy_type)
ORDER BY (effective_date, customer_id, policy_type, policy_id)  -- Time-first ordering
PRIMARY KEY (effective_date, customer_id)  -- Explicit primary key for time-based queries
SETTINGS index_granularity = 8192;

-- Query using optimized primary key
SELECT 
    toDate(effective_date) AS date,
    count() AS policies_issued
FROM policies
WHERE customer_id >= 1001 and customer_id <= 1000000
  AND effective_date >= '2024-01-01'
  AND effective_date < '2024-12-31'
  AND policy_type = 'Term Life' 
GROUP BY date
ORDER BY date;

-- Copy data to time-optimized table
insert into policies_time_optimized
select * from policies;

-- Query using time-optimized table
SELECT 
    toDate(effective_date) AS date,
    count() AS policies_issued
FROM policies_time_optimized
WHERE customer_id >= 1001 and customer_id <= 1000000
  AND effective_date >= '2024-01-01'
  AND effective_date < '2024-12-31'
  AND policy_type = 'Term Life' 
GROUP BY date
ORDER BY date;

-- =============================================
-- 3. Skipping Indexing
-- =============================================

CREATE TABLE claims
(
    claim_id UUID,
    policy_id UUID,
    customer_id UInt64,
    claim_type Enum8('Death' = 1, 'Disability' = 2, 'Maturity' = 3, 'Surrender' = 4, 'Loan' = 5),
    claim_number String,
    incident_date Date,
    reported_date DateTime DEFAULT now(),
    claim_amount Decimal64(2),
    approved_amount Decimal64(2) DEFAULT 0,
    claim_status Enum8('Reported' = 1, 'Under Review' = 2, 'Approved' = 3, 'Denied' = 4, 'Paid' = 5),
    description String,
    adjuster_id UInt32,
    _sign Int8 DEFAULT 1
)
ENGINE = CollapsingMergeTree(_sign)
PARTITION BY (toYYYYMM(reported_date), claim_status)
ORDER BY (claim_id, policy_id, reported_date)
SETTINGS index_granularity = 8192;

ALTER TABLE claims
ADD INDEX claim_status_idx claim_status TYPE set(0) GRANULARITY 4;

SELECT 
    database,
    table,
    name as index_name,
    type,
    granularity
FROM system.data_skipping_indices
WHERE database = 'life_insurance' 
  AND table = 'claims'
ORDER BY name;





