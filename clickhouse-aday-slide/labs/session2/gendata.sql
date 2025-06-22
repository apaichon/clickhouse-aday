-- Query aggregated results for actuarial analysis
SELECT
    analysis_date,
    policy_type,
    age_group,
    sumMerge(total_claims) as claims_count,
    avgMerge(avg_claim_amount) as avg_amount,
    groupUniqArrayMerge(claim_types) as claim_categories
FROM claims_analytics
GROUP BY analysis_date, policy_type, age_group;

-- =============================================================================
-- DATA GENERATION FUNCTIONS FOR LIFE INSURANCE TESTING
-- =============================================================================

-- Function 1: Generate Sample Policies (ReplacingMergeTree)
-- Generates realistic policy data with different policy types and versions

INSERT INTO policies 
SELECT
    generateUUIDv4() as policy_id,
    1000 + number as customer_id,
    100 + (number % 10) as agent_id,
    CASE number % 5
        WHEN 0 THEN 'Term Life'
        WHEN 1 THEN 'Whole Life'
        WHEN 2 THEN 'Universal Life'
        WHEN 3 THEN 'Variable Life'
        ELSE 'Endowment'
    END as policy_type,
    concat('LIFE-2024-', lpad(toString(number + 1), 6, '0')) as policy_number,
    (100000 + (number * 50000) + (rand() % 500000)) as coverage_amount,
    (500 + (number * 25) + (rand() % 1000)) as premium_amount,
    0.00 as deductible_amount,
    toDate('2024-01-01') + INTERVAL (number % 365) DAY as start_date,
    toDate('2024-01-01') + INTERVAL (number % 365) DAY + INTERVAL 20 YEAR as end_date,
    CASE number % 10
        WHEN 0 THEN 'Pending'
        WHEN 1 THEN 'Lapsed'
        WHEN 2 THEN 'Terminated'
        ELSE 'Active'
    END as status,
    now() - INTERVAL (rand() % 100) DAY as created_at,
    now() - INTERVAL (rand() % 50) DAY as updated_at,
    1 as version
FROM numbers(1000);

-- Function 2: Generate Policy Updates (ReplacingMergeTree versions)
-- Creates version 2 for some policies with updated premiums

INSERT INTO policies 
SELECT
    policy_id,
    customer_id,
    agent_id,
    policy_type,
    policy_number,
    coverage_amount,
    premium_amount * (1 + (rand() % 20) / 100.0) as premium_amount, -- 0-20% increase
    deductible_amount,
    start_date,
    end_date,
    status,
    created_at,
    now() - INTERVAL (rand() % 30) DAY as updated_at,
    2 as version
FROM policies 
WHERE version = 1 
  AND number % 5 = 0  -- Update 20% of policies
LIMIT 200;

-- Function 3: Generate Premium Transactions (CollapsingMergeTree)
-- Creates payment transactions with some corrections/cancellations

INSERT INTO premium_transactions
SELECT
    policy_id,
    concat('TXN-', toString(number), '-', toString(rand() % 1000)) as transaction_id,
    premium_amount,
    CASE number % 10
        WHEN 9 THEN 'Refund'
        ELSE 'Payment'
    END as transaction_type,
    created_at + INTERVAL (rand() % 30) DAY as transaction_date,
    CASE number % 4
        WHEN 0 THEN 'Credit Card'
        WHEN 1 THEN 'Bank Transfer'
        WHEN 2 THEN 'Check'
        ELSE 'Auto Pay'
    END as payment_method,
    1 as sign
FROM (
    SELECT *, row_number() OVER () as number
    FROM policies FINAL
    WHERE status = 'Active'
) p
LIMIT 2000;

-- Generate some transaction corrections (negative sign)
INSERT INTO premium_transactions
SELECT
    policy_id,
    transaction_id,
    amount,
    transaction_type,
    transaction_date,
    payment_method,
    -1 as sign  -- Correction/cancellation
FROM premium_transactions
WHERE rand() % 100 < 5  -- 5% correction rate
LIMIT 100;

-- Function 4: Generate Daily Premium Collections (SummingMergeTree)
-- Creates daily collection data by agent and policy type

INSERT INTO daily_premium_collection
SELECT
    toDate('2025-06-20') + INTERVAL (number % 100) DAY as collection_date,
    100 + (number % 10) as agent_id,
    CASE number % 3
        WHEN 0 THEN 'Term'
        WHEN 1 THEN 'Whole'
        ELSE 'Universal'
    END as policy_type,
    (1000 + (rand() % 10000)) as total_premiums,
    (1 + (rand() % 10)) as policy_count,
    (50 + (rand() % 500)) as commission_amount
FROM numbers(1000);  -- 100 days of daily data

-- Function 5: Generate Policy Status History (VersionedCollapsingMergeTree)
-- Creates status change history for policies

INSERT INTO policy_status_history
SELECT
    policy_id,
    'Active' as status,
    start_date as effective_date,
    'NEW_POLICY' as reason_code,
    1 as version,
    1 as sign
FROM policies FINAL
LIMIT 500;

-- Generate status changes
INSERT INTO policy_status_history
SELECT
    policy_id,
    CASE number % 4
        WHEN 0 THEN 'Lapsed'
        WHEN 1 THEN 'Reinstated'
        WHEN 2 THEN 'Terminated'
        ELSE 'Active'
    END as status,
    start_date + INTERVAL (30 + rand() % 300) DAY as effective_date,
    CASE number % 4
        WHEN 0 THEN 'NON_PAYMENT'
        WHEN 1 THEN 'PAYMENT_RECEIVED'
        WHEN 2 THEN 'CUSTOMER_REQUEST'
        ELSE 'UNDERWRITING_REVIEW'
    END as reason_code,
    2 as version,
    1 as sign
FROM (
    SELECT *, row_number() OVER () as number
    FROM policies FINAL
    WHERE status != 'Pending'
) p
LIMIT 200;

-- Function 6: Generate Claims Analytics Data (AggregatingMergeTree)
-- Fixed version with proper type casting

INSERT INTO claims_analytics
SELECT 
    analysis_date,
    policy_type,
    age_group,
    sumState(CAST(claim_count AS UInt32)),
    avgState(CAST(claim_amount AS Decimal64(2))),
    groupUniqArrayState(claim_type)
FROM 
(
    SELECT
        toDate('2025-06-20') + INTERVAL (number % 100) DAY as analysis_date,
        CASE number % 3
            WHEN 0 THEN 'Term'
            WHEN 1 THEN 'Whole'
            ELSE 'Universal'
        END as policy_type,
        CASE number % 4
            WHEN 0 THEN '18-30'
            WHEN 1 THEN '31-45'
            WHEN 2 THEN '46-60'
            ELSE '60+'
        END as age_group,
        1 as claim_count,
        CAST((50000 + (rand() % 200000)) AS Decimal64(2)) as claim_amount,
        CASE number % 5
            WHEN 0 THEN 'Death Benefit'
            WHEN 1 THEN 'Disability'
            WHEN 2 THEN 'Surrender'
            WHEN 3 THEN 'Loan'
            ELSE 'Maturity'
        END as claim_type
    FROM numbers(100)
) raw
GROUP BY analysis_date, policy_type, age_group;

-- =============================================================================
-- DATA VERIFICATION AND ANALYSIS QUERIES
-- =============================================================================

-- Verify generated data counts
SELECT 
    'policies' as table_name, 
    count() as total_records,
    count(DISTINCT version) as versions,
    min(start_date) as earliest_policy,
    max(start_date) as latest_policy
FROM policies FINAL

UNION ALL

SELECT 
    'premium_transactions', 
    count(),
    count(DISTINCT sign) as sign_values,
    min(transaction_date),
    max(transaction_date)
FROM premium_transactions FINAL

UNION ALL

SELECT 
    'daily_premium_collection', 
    count(),
    count(DISTINCT agent_id) as agents,
    min(collection_date),
    max(collection_date)
FROM daily_premium_collection FINAL

UNION ALL

SELECT 
    'policy_status_history', 
    count(),
    count(DISTINCT version) as versions,
    min(effective_date),
    max(effective_date)
FROM policy_status_history FINAL

UNION ALL

SELECT 
    'claims_analytics', 
    count(),
    count(DISTINCT policy_type) as policy_types,
    min(analysis_date),
    max(analysis_date)
FROM claims_analytics;

-- Business Intelligence Queries on Generated Data

-- 1. Policy Distribution by Type and Status
SELECT 
    policy_type,
    status,
    count() as policy_count,
    sum(coverage_amount) as total_coverage,
    avg(premium_amount) as avg_premium
FROM policies FINAL
GROUP BY policy_type, status
ORDER BY policy_type, status;

-- 2. Monthly Premium Collections by Agent
SELECT 
    toYYYYMM(collection_date) as month,
    agent_id,
    sum(total_premiums) as monthly_premiums,
    sum(policy_count) as policies_written,
    sum(commission_amount) as total_commission
FROM daily_premium_collection FINAL
GROUP BY month, agent_id
ORDER BY month DESC, monthly_premiums DESC
LIMIT 20;

-- 3. Policy Status Changes Analysis
SELECT 
    status,
    reason_code,
    count() as change_count,
    avg(dateDiff('day', 
        (SELECT min(effective_date) FROM policy_status_history h2 
         WHERE h2.policy_id = h1.policy_id), 
        effective_date)) as avg_days_to_change
FROM policy_status_history FINAL h1
WHERE version > 1
GROUP BY status, reason_code
ORDER BY change_count DESC;

-- 4. Claims Analysis by Demographics
SELECT
    policy_type,
    age_group,
    sumMerge(total_claims) as total_claims,
    avgMerge(avg_claim_amount) as average_amount,
    length(groupUniqArrayMerge(claim_types)) as claim_type_variety
FROM claims_analytics
GROUP BY policy_type, age_group
ORDER BY total_claims DESC;

-- 5. Transaction Success Rate Analysis
SELECT 
    payment_method,
    count() as total_transactions,
    sum(CASE WHEN sign = 1 THEN 1 ELSE 0 END) as successful_transactions,
    sum(CASE WHEN sign = -1 THEN 1 ELSE 0 END) as cancelled_transactions,
    round(sum(CASE WHEN sign = 1 THEN 1 ELSE 0 END) * 100.0 / count(), 2) as success_rate_percent
FROM premium_transactions
GROUP BY payment_method
ORDER BY success_rate_percent DESC;

-- =============================================================================
-- PERFORMANCE TESTING QUERIES
-- =============================================================================

-- Test query performance on different table engines
-- These queries help demonstrate the benefits of each engine type

-- 1. ReplacingMergeTree: Get latest policy versions
SELECT count() FROM policies FINAL WHERE status = 'Active';

-- 2. CollapsingMergeTree: Calculate net transactions
SELECT 
    policy_id,
    sum(amount * sign) as net_amount
FROM premium_transactions
GROUP BY policy_id
HAVING net_amount > 0
LIMIT 10;

-- 3. SummingMergeTree: Aggregate daily collections
SELECT 
    toYYYYMM(collection_date) as month,
    sum(total_premiums) as monthly_total
FROM daily_premium_collection FINAL
GROUP BY month
ORDER BY month;

-- 4. VersionedCollapsingMergeTree: Get current status
SELECT 
    policy_id,
    argMax(status, (version, effective_date)) as current_status
FROM policy_status_history FINAL
GROUP BY policy_id
LIMIT 10;

-- 5. AggregatingMergeTree: Merge aggregated claims data
SELECT
    toYYYYMM(analysis_date) as month,
    policy_type,
    sumMerge(total_claims) as monthly_claims,
    avgMerge(avg_claim_amount) as avg_monthly_amount
FROM claims_analytics
GROUP BY month, policy_type
ORDER BY month DESC, monthly_claims DESC
LIMIT 20;

-- =============================================================================
-- CLEANUP AND MAINTENANCE FUNCTIONS
-- =============================================================================

-- Function to clean up test data (use with caution)
/*
TRUNCATE TABLE policies;
TRUNCATE TABLE premium_transactions;
TRUNCATE TABLE daily_premium_collection;
TRUNCATE TABLE policy_status_history;
TRUNCATE TABLE claims_analytics;
*/

-- Optimize all tables to trigger merges
-- OPTIMIZE TABLE policies FINAL;
-- OPTIMIZE TABLE premium_transactions FINAL;
-- OPTIMIZE TABLE daily_premium_collection FINAL;
-- OPTIMIZE TABLE policy_status_history FINAL;
-- OPTIMIZE TABLE claims_analytics FINAL;

-- Show table sizes and compression
SELECT 
    database,
    table,
    formatReadableSize(sum(bytes_on_disk)) as disk_size,
    formatReadableSize(sum(data_uncompressed_bytes)) as uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(bytes_on_disk), 2) as compression_ratio,
    sum(rows) as total_rows
FROM system.parts
WHERE database = 'life_insurance'
  AND active = 1
GROUP BY database, table
ORDER BY sum(bytes_on_disk) DESC;


SELECT collection_date, sum(total_premiums), sum(policy_count), sum(commission_amount)
 FROM daily_premium_collection FINAL
group by collection_date;
