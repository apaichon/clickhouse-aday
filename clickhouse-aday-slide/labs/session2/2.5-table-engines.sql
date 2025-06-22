-- ================================================
-- ClickHouse MergeTree Engines - Life Insurance Management System
-- ================================================

-- Create database for life insurance management
CREATE DATABASE IF NOT EXISTS life_insurance;
USE life_insurance;

-- ================================================
-- 1. REPLACINGMERGETREE ENGINE
-- ================================================
-- Use Case: Policy master data with version control for policy updates
-- Best for: Managing versioned records where you need latest version only

-- Create Policy Master Table
DROP TABLE IF EXISTS policies;
CREATE TABLE policies
(
    policy_id UUID,
    customer_id UInt64,
    agent_id UInt32,
    policy_type Enum8('Term Life' = 1, 'Whole Life' = 2, 'Universal Life' = 3, 'Variable Life' = 4, 'Endowment' = 5),
    policy_number String,
    coverage_amount Decimal64(2),
    premium_amount Decimal64(2),
    deductible_amount Decimal64(2),
    start_date Date,
    end_date Date,
    status Enum8('Active' = 1, 'Lapsed' = 2, 'Terminated' = 3, 'Matured' = 4, 'Pending' = 5),
    created_at DateTime DEFAULT now(),
    updated_at DateTime DEFAULT now(),
    version UInt32 DEFAULT 1
)
ENGINE = ReplacingMergeTree(version)
PARTITION BY (toYYYYMM(start_date), policy_type)
ORDER BY (policy_id, customer_id, start_date)
SETTINGS index_granularity = 8192;

-- Insert Policy Data and Updates
-- Initial policy creation
INSERT INTO policies (policy_id, customer_id, agent_id, policy_type, policy_number, coverage_amount, premium_amount, deductible_amount, start_date, end_date, status, created_at, updated_at, version) VALUES
('550e8400-e29b-41d4-a716-446655440000', 
 1001, 101, 'Term Life', 'LIFE-2025-001', 500000.00, 1200.00, 0.00, 
 '2025-01-01', '2045-01-01', 'Active', '2025-01-01 10:00:00', '2025-01-01 10:00:00', 1);

-- Premium update after underwriting review
INSERT INTO policies (policy_id, customer_id, agent_id, policy_type, policy_number, coverage_amount, premium_amount, deductible_amount, start_date, end_date, status, created_at, updated_at, version) VALUES
('550e8400-e29b-41d4-a716-446655440000', 
 1001, 101, 'Term Life', 'LIFE-2025-001', 500000.00, 1350.00, 0.00, 
 '2025-01-01', '2045-01-01', 'Active', '2025-01-01 10:00:00', '2025-01-15 14:30:00', 2);

-- Coverage amount update after policy amendment
INSERT INTO policies (policy_id, customer_id, agent_id, policy_type, policy_number, coverage_amount, premium_amount, deductible_amount, start_date, end_date, status, created_at, updated_at, version) VALUES
('550e8400-e29b-41d4-a716-446655440000', 
 1001, 101, 'Term Life', 'LIFE-2025-001', 750000.00, 1800.00, 0.00, 
 '2025-01-01', '2045-01-01', 'Active', '2025-01-01 10:00:00', '2025-02-01 09:15:00', 3);

-- Query Operations for ReplacingMergeTree
-- View all versions (before optimization)
SELECT policy_id, coverage_amount, premium_amount, updated_at, version 
FROM policies 
WHERE policy_id = '550e8400-e29b-41d4-a716-446655440000'
ORDER BY version;

-- Query latest version only (using FINAL)
SELECT policy_id, coverage_amount, premium_amount, updated_at, version 
FROM policies FINAL
WHERE policy_id = '550e8400-e29b-41d4-a716-446655440000';

-- Optimize table to keep only latest versions
OPTIMIZE TABLE policies FINAL;

-- Verify only latest version exists after optimization
SELECT policy_id, coverage_amount, premium_amount, updated_at, version 
FROM policies 
WHERE policy_id = '550e8400-e29b-41d4-a716-446655440000';


-- ================================================
-- 2. COLLAPSINGMERGETREE ENGINE
-- ================================================
-- Use Case: Tracking premium payments and refunds with correction capability
-- Best for: Event streams where records can be canceled/corrected

-- Create Premium Transactions Table
DROP TABLE IF EXISTS premium_transactions;
CREATE TABLE premium_transactions 
(
    policy_id UUID,
    transaction_id String,
    amount Decimal(10,2),
    transaction_type Enum8('Payment'=1, 'Refund'=2),
    transaction_date DateTime,
    payment_method String,
    sign Int8  -- 1 for record, -1 for cancel
) 
ENGINE = CollapsingMergeTree(sign)
ORDER BY (policy_id, transaction_id, transaction_date);

-- Transaction Operations
-- Record valid premium payment
INSERT INTO premium_transactions VALUES
('550e8400-e29b-41d4-a716-446655440000',
 'TXN-001', 1200.00, 'Payment', now(), 
 'Credit Card', 1);

-- Record duplicate charge (processing error)
INSERT INTO premium_transactions VALUES
('550e8400-e29b-41d4-a716-446655440000',
 'TXN-002', 1200.00, 'Payment', now(), 
 'Credit Card', 1);

-- Cancel duplicate transaction
INSERT INTO premium_transactions VALUES
('550e8400-e29b-41d4-a716-446655440000',
 'TXN-002', 1200.00, 'Payment', 
 (SELECT transaction_date FROM premium_transactions WHERE policy_id = '550e8400-e29b-41d4-a716-446655440000' AND transaction_id = 'TXN-002' AND transaction_type = 'Payment' LIMIT 1), 
 'Credit Card', -1);

-- Query Operations for CollapsingMergeTree
-- Check final state after collapsing
SELECT * FROM premium_transactions FINAL;

-- Alternative: Manual aggregation to see collapse effect
SELECT 
    policy_id, 
    transaction_id, 
    transaction_date, 
    sum(sign) as net_transactions
FROM premium_transactions
GROUP BY policy_id, transaction_id, transaction_date
HAVING sum(sign) != 0;


-- ================================================
-- 3. SUMMINGMERGETREE ENGINE
-- ================================================
-- Use Case: Aggregating daily premium collections by agent and policy type
-- Best for: Automatic aggregation of numeric columns

-- Create Daily Premium Collection Table
DROP TABLE IF EXISTS daily_premium_collection;
CREATE TABLE daily_premium_collection 
(
    collection_date Date,
    agent_id UInt32,
    policy_type Enum8('Term'=1, 'Whole'=2, 'Universal'=3),
    total_premiums Decimal(15,2),
    policy_count UInt32,
    commission_amount Decimal(10,2)
) 
ENGINE = SummingMergeTree()
ORDER BY (collection_date, agent_id, policy_type)
PARTITION BY toYYYYMM(collection_date);

-- Collection Data Operations
-- Record morning collections
INSERT INTO daily_premium_collection VALUES
('2025-01-01', 101, 'Term', 5000.00, 4, 250.00),
('2025-01-01', 101, 'Whole', 8000.00, 2, 480.00);

-- Record afternoon collections  
INSERT INTO daily_premium_collection VALUES
('2025-01-01', 101, 'Term', 3000.00, 2, 150.00),
('2025-01-01', 101, 'Universal', 12000.00, 1, 720.00);

-- Query Operations for SummingMergeTree
-- View aggregated daily totals (automatic summing)
SELECT 
    collection_date, 
    agent_id,
    policy_type,
    sum(total_premiums) as daily_premiums,
    sum(policy_count) as daily_policies,
    sum(commission_amount) as daily_commission
FROM daily_premium_collection FINAL
GROUP BY collection_date, agent_id, policy_type
ORDER BY collection_date, agent_id;

-- Summary by date only
SELECT 
    collection_date, 
    sum(total_premiums) as total_daily_premiums, 
    sum(policy_count) as total_daily_policies, 
    sum(commission_amount) as total_daily_commission
FROM daily_premium_collection FINAL
GROUP BY collection_date
ORDER BY collection_date;


-- ================================================
-- 4. VERSIONEDCOLLAPSINGMERGETREE ENGINE
-- ================================================
-- Use Case: Tracking policy status changes with version control and corrections
-- Best for: Event streams with versioning and correction capability

-- Create Policy Status History Table
DROP TABLE IF EXISTS policy_status_history;
CREATE TABLE policy_status_history
(
    policy_id UUID,
    status Enum8('Active'=1, 'Lapsed'=2, 'Reinstated'=3, 'Terminated'=4),
    effective_date DateTime,
    reason_code String,
    version UInt32,
    sign Int8  -- 1 for record, -1 for cancel
) 
ENGINE = VersionedCollapsingMergeTree(sign, version)
ORDER BY (policy_id, effective_date, version);

-- Status History Operations
-- Initial policy activation
INSERT INTO policy_status_history VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'Active', '2025-01-01 00:00:00', 'NEW_POLICY', 1, 1);

-- Policy lapse due to non-payment
INSERT INTO policy_status_history VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'Lapsed', '2025-03-01 00:00:00', 'NON_PAYMENT', 2, 1);

-- Correction: Reverse incorrect lapse status
INSERT INTO policy_status_history VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'Lapsed', '2025-03-01 00:00:00', 'NON_PAYMENT', 2, -1);

-- Policy reinstatement after payment received
INSERT INTO policy_status_history VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'Reinstated', '2025-03-05 00:00:00', 'PAYMENT_RECEIVED', 3, 1);

-- Query Operations for VersionedCollapsingMergeTree
-- View final status history
SELECT * FROM policy_status_history FINAL ORDER BY effective_date;

-- Get current policy status
SELECT 
    policy_id,
    status,
    effective_date,
    reason_code
FROM policy_status_history FINAL
WHERE policy_id = '550e8400-e29b-41d4-a716-446655440000'
ORDER BY effective_date DESC
LIMIT 1;


-- ================================================
-- 5. AGGREGATINGMERGETREE ENGINE
-- ================================================
-- Use Case: Pre-aggregated claims analytics for actuarial analysis
-- Best for: Complex aggregations stored as intermediate states

-- Create Claims Analytics Table
DROP TABLE IF EXISTS claims_analytics;
CREATE TABLE claims_analytics 
(
    analysis_date Date,
    policy_type Enum8('Term'=1, 'Whole'=2, 'Universal'=3),
    age_group Enum8('18-30'=1, '31-45'=2, '46-60'=3, '60+'=4),
    total_claims AggregateFunction(sum, UInt32),
    avg_claim_amount AggregateFunction(avg, Float64),
    claim_types AggregateFunction(groupUniqArray, String)
) 
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(analysis_date)
ORDER BY (analysis_date, policy_type, age_group);

-- Sample Claims Data Insertion
INSERT INTO claims_analytics
SELECT 
    analysis_date,
    policy_type,
    age_group,
    sumState(CAST(claim_count AS UInt32)) as total_claims,
    avgState(CAST(claim_amount AS Float64)) as avg_claim_amount,
    groupUniqArrayState(claim_type) as claim_types
FROM 
(
    -- Sample claims data for Term Life, Age 31-45
    SELECT
        toDate('2025-01-01') as analysis_date,
        'Term' as policy_type,
        '31-45' as age_group,
        1 as claim_count,
        150000.00 as claim_amount,
        'Death Benefit' as claim_type
    UNION ALL
    SELECT
        toDate('2025-01-01'),
        'Term',
        '31-45',
        1,
        25000.00,
        'Disability'
    UNION ALL
    SELECT
        toDate('2025-01-01'),
        'Whole',
        '46-60',
        1,
        200000.00,
        'Death Benefit'
    UNION ALL
    SELECT
        toDate('2025-01-01'),
        'Universal',
        '18-30',
        1,
        50000.00,
        'Accidental Death'
) raw_claims
GROUP BY analysis_date, policy_type, age_group;

-- Query Operations for AggregatingMergeTree
-- Retrieve aggregated results for actuarial analysis
SELECT
    analysis_date,
    policy_type,
    age_group,
    sumMerge(total_claims) as total_claims_count,
    avgMerge(avg_claim_amount) as average_claim_amount,
    groupUniqArrayMerge(claim_types) as unique_claim_types
FROM claims_analytics
GROUP BY analysis_date, policy_type, age_group
ORDER BY analysis_date, policy_type, age_group;

-- Summary by policy type across all age groups
SELECT
    analysis_date,
    policy_type,
    sumMerge(total_claims) as total_claims,
    avgMerge(avg_claim_amount) as avg_amount,
    groupUniqArrayMerge(claim_types) as all_claim_types
FROM claims_analytics
GROUP BY analysis_date, policy_type
ORDER BY analysis_date, policy_type;


-- ================================================
-- CLEANUP OPERATIONS (Optional)
-- ================================================

-- Drop tables if needed for cleanup
-- DROP TABLE IF EXISTS policies;
-- DROP TABLE IF EXISTS premium_transactions;
-- DROP TABLE IF EXISTS daily_premium_collection;
-- DROP TABLE IF EXISTS policy_status_history;
-- DROP TABLE IF EXISTS claims_analytics;