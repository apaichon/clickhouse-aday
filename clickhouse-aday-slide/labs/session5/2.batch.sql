-- =============================================
-- ClickHouse Session 5: Data Operations and Management - Batch Operations
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Batch INSERT Operations
-- =============================================

-- Large batch insert of customers
INSERT INTO customers (
    customer_id, first_name, last_name, email, phone,
    date_of_birth, address, city, state, zip_code, customer_type, beneficiaries
) 
SELECT 
    1000999 + number,
    concat('Customer', toString(number)),
    concat('LastName', toString(number)),
    concat('customer', toString(number), '@email.com'),
    concat('555-', leftPad(toString(number % 10000), 4, '0')),
    today() - INTERVAL (20 + (number % 40)) YEAR,
    concat(toString(100 + number), ' Main St'),
    multiIf(
        number % 4 = 0, 'New York',
        number % 4 = 1, 'Los Angeles', 
        number % 4 = 2, 'Chicago',
        'Houston'
    ),
    multiIf(
        number % 4 = 0, 'NY',
        number % 4 = 1, 'CA',
        number % 4 = 2, 'IL', 
        'TX'
    ),
    leftPad(toString(10000 + (number % 90000)), 5, '0') || '     ',
    multiIf(
        number % 10 < 7, 'Individual',
        number % 10 < 9, 'Family',
        'Corporate'
    ),
    concat('Beneficiary', toString(number), ',Spouse', toString(number))
FROM numbers(1_000_000);

-- truncate table agents;
-- Batch insert agents with territories
INSERT INTO agents (
    agent_id, first_name, last_name, email, phone,
    license_number, territory, commission_rate, hire_date
)
SELECT 
    5000 + number,
    concat('Agent', toString(number)),
    concat('AgentLast', toString(number)),
    concat('agent', toString(number), '@insurance.com'),
    concat('555-', leftPad(toString(5000 + number), 4, '0')),
    concat('LIC', leftPad(toString(600 + number), 6, '0')),
    multiIf(
        number % 5 = 0, 'Northeast',
        number % 5 = 1, 'Southeast',
        number % 5 = 2, 'Midwest',
        number % 5 = 3, 'Southwest',
        'West'
    ),
    0.0200 + (number % 10) * 0.0010,
    today() - INTERVAL (number % 1000) DAY
FROM numbers(50000);

-- =============================================
-- 2. Batch Policy Generation
-- =============================================

-- Generate policies for customers
-- truncate table policies;
INSERT INTO policies (
    policy_id, customer_id, agent_id, policy_type, policy_number,
    coverage_amount, premium_amount, deductible_amount,
    effective_date, end_date, status
)
SELECT 
    generateUUIDv4(),
    c.customer_id,
    50000 + (c.customer_id % 50000),  -- Assign to available agents
    multiIf(
        (c.customer_id % 5) = 0, 'Term Life',
        (c.customer_id % 5) = 1, 'Whole Life',
        (c.customer_id % 5) = 2, 'Universal Life',
        (c.customer_id % 5) = 3, 'Variable Life',
        'Endowment'
    ),
    concat('POL-', toString(c.customer_id), '-', toString(toUnixTimestamp(now()) % 100000)),
    multiIf(
        c.customer_type = 'Corporate', 1000000.00 + (c.customer_id % 10) * 100000.00,
        c.customer_type = 'Family', 500000.00 + (c.customer_id % 10) * 50000.00,
        250000.00 + (c.customer_id % 10) * 25000.00
    ),
    multiIf(
        c.customer_type = 'Corporate', 2400.00 + (c.customer_id % 10) * 240.00,
        c.customer_type = 'Family', 1200.00 + (c.customer_id % 10) * 120.00,
        600.00 + (c.customer_id % 10) * 60.00
    ),
    multiIf(
        (c.customer_id % 5) = 0, 0.00,  -- Term Life no deductible
        (c.customer_id % 10) * 100.00   -- Others have small deductible
    ),
    today() - INTERVAL (c.customer_id % 365) DAY,
    today() + INTERVAL multiIf(
        (c.customer_id % 5) = 0, 20,  -- Term Life 20 years
        (c.customer_id % 5) = 1, 30,  -- Whole Life 30 years
        25                             -- Others 25 years
    ) YEAR,
    multiIf(
        c.customer_id % 20 = 0, 'Pending',
        c.customer_id % 50 = 0, 'Lapsed',
        'Active'
    )
FROM customers c
WHERE c.customer_id >= 10000
SETTINGS max_execution_time = 1800;






-- =============================================
-- 3. Batch Claims Generation
-- =============================================

-- Generate sample claims for some policies
-- truncate table claims;

INSERT INTO claims (
    claim_id, policy_id, customer_id, claim_type, claim_number,
    incident_date, claim_amount, approved_amount, claim_status, 
    description, adjuster_id
)
SELECT 
    generateUUIDv4(),
    p.policy_id,
    p.customer_id,
    multiIf(
        (p.customer_id % 10) < 4, 'Death',
        (p.customer_id % 10) < 7, 'Disability',
        (p.customer_id % 10) < 9, 'Surrender',
        'Maturity'
    ),
    concat('CLM-', toString(p.customer_id), '-', toString(toUnixTimestamp(now()) % 100000)),
    p.effective_date + INTERVAL (p.customer_id % 1000) DAY,
    p.coverage_amount * multiIf(
        (p.customer_id % 10) < 4, 1.0,      -- Death claim - full coverage
        (p.customer_id % 10) < 7, 0.6,      -- Disability - 60%
        (p.customer_id % 10) < 9, 0.8,      -- Surrender - 80%
        1.0                                  -- Maturity - full
    ),
    p.coverage_amount * multiIf(
        (p.customer_id % 10) < 4, 0.95,     -- Death approved 95%
        (p.customer_id % 10) < 7, 0.55,     -- Disability approved 55%
        (p.customer_id % 10) < 9, 0.75,     -- Surrender approved 75%
        0.95                                 -- Maturity approved 95%
    ),
    multiIf(
        p.customer_id % 15 = 0, 'Denied',
        p.customer_id % 10 = 0, 'Under Review',
        p.customer_id % 8 = 0, 'Approved',
        p.customer_id % 5 = 0, 'Paid',
        'Reported'
    ),
    concat('Claim for policy ', p.policy_number, ' - ', 
           multiIf(
               (p.customer_id % 10) < 4, 'Death benefit claim',
               (p.customer_id % 10) < 7, 'Disability claim',
               (p.customer_id % 10) < 9, 'Policy surrender',
               'Maturity benefit'
           )),
    400 + (p.customer_id % 50)  -- Assign adjusters 400-449
FROM policies p
WHERE p.customer_id >= 6000
  AND p.status = 'Active'
  AND (p.customer_id % 4) = 0  -- Only generate claims for 25% of policies
LIMIT 100000;

-- =============================================
-- 4. Batch Policy Documents Generation
-- =============================================

-- Generate policy documents
INSERT INTO policy_documents (
    document_id, policy_id, document_type, file_path, file_size,
    content_type, document_date
)
SELECT 
    generateUUIDv4(),
    p.policy_id,
    multiIf(
        (p.customer_id % 5) = 0, 'Application',
        (p.customer_id % 5) = 1, 'Policy Certificate',
        (p.customer_id % 5) = 2, 'Medical Report',
        (p.customer_id % 5) = 3, 'Amendment',
        'Claim Form'
    ),
    concat('/documents/policy/', toString(p.customer_id), '/', 
           multiIf(
               (p.customer_id % 5) = 0, 'application.pdf',
               (p.customer_id % 5) = 1, 'certificate.pdf',
               (p.customer_id % 5) = 2, 'medical.pdf',
               (p.customer_id % 5) = 3, 'amendment.pdf',
               'claim_form.pdf'
           )),
    1024 + (p.customer_id % 10) * 512,  -- File size between 1KB-6KB
    multiIf(
        (p.customer_id % 3) = 0, 'application/pdf',
        (p.customer_id % 3) = 1, 'image/jpeg',
        'application/msword'
    ),
    p.effective_date + INTERVAL (p.customer_id % 30) DAY
FROM policies p
WHERE p.customer_id >= 6000
  AND p.status IN ('Active', 'Pending');

-- Remove existing backup if it exists
-- DROP TABLE IF EXISTS system.backups WHERE name = 'daily_backup_2025_06_25_2';

-- Optimized backup with longer timeout and compression
BACKUP DATABASE life_insurance 
TO Disk('backups', 'life_insurance2.tar')
SETTINGS 
    max_execution_time = 900,           -- 15 minutes timeout
    backup_threads = 4,                  -- Use multiple threads
    compression_method = 'lz4',          -- Fast compression
    compression_level = 1;               -- Low compression for speed

SELECT * FROM system.backups;

ALTER TABLE system.backups DELETE WHERE name = 'life_insurance2.tar';

ALTER TABLE life_insurance.customers FREEZE;
ALTER TABLE life_insurance.agents FREEZE;
ALTER TABLE life_insurance.policies FREEZE;
ALTER TABLE life_insurance.claims FREEZE;
ALTER TABLE life_insurance.policy_documents FREEZE;


-- =============================================
-- 5. Performance Monitoring for Batch Operations
-- =============================================

-- Check batch operation performance
SELECT 
    'customers' as table_name,
    count() as total_records,
    min(created_at) as earliest_record,
    max(created_at) as latest_record
FROM customers
WHERE customer_id >= 6000

UNION ALL

SELECT 
    'policies' as table_name,
    count() as total_records,
    min(created_at) as earliest_record,
    max(created_at) as latest_record
FROM policies
WHERE customer_id >= 6000

UNION ALL

SELECT 
    'claims' as table_name,
    count() as total_records,
    min(reported_date) as earliest_record,
    max(reported_date) as latest_record
FROM claims
WHERE customer_id >= 6000;

-- Analyze data distribution
SELECT 
    policy_type,
    status,
    count() as policy_count,
    avg(coverage_amount) as avg_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE customer_id >= 6000
GROUP BY policy_type, status
ORDER BY policy_type, status;



