-- =============================================
-- ClickHouse Session 5: Data Operations and Management - INSERT Operations
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Basic INSERT Operations
-- =============================================

-- Single row insert into customers
INSERT INTO customers (
    customer_id, first_name, last_name, email, phone, 
    date_of_birth, address, city, state, zip_code, customer_type
) VALUES (
    5001, 'John', 'Smith', 'john.smith@email.com', '555-0101',
    '1980-05-15', '123 Main St', 'New York', 'NY', '10001     ', 'Individual'
);

-- Multiple rows insert into agents
INSERT INTO agents (
    agent_id, first_name, last_name, email, phone, 
    license_number, territory, commission_rate, hire_date
) VALUES 
    (501, 'Alice', 'Johnson', 'alice.j@insurance.com', '555-0201', 'LIC501', 'Northeast', 0.0250, '2023-01-15'),
    (502, 'Bob', 'Wilson', 'bob.w@insurance.com', '555-0202', 'LIC502', 'Southeast', 0.0275, '2023-02-20'),
    (503, 'Carol', 'Davis', 'carol.d@insurance.com', '555-0203', 'LIC503', 'Midwest', 0.0300, '2023-03-10');

-- INSERT with SELECT (copying data)
INSERT INTO customers (
    customer_id, first_name, last_name, email, phone,
    date_of_birth, address, city, state, zip_code, customer_type
)
SELECT 
    customer_id + 1000,
    first_name,
    last_name,
    concat('copy_', email),
    phone,
    date_of_birth,
    address,
    city,
    state,
    zip_code,
    customer_type
FROM customers
WHERE customer_id BETWEEN 1 AND 10;

-- =============================================
-- 2. INSERT with Functions and Expressions
-- =============================================

INSERT INTO policies
(policy_id, customer_id, agent_id, policy_number, policy_type, coverage_amount, premium_amount, deductible_amount, effective_date, end_date, status, created_at, updated_at, version)
SELECT
    generateUUIDv4() as policy_id,
    toUInt64(rand() % 100000) as customer_id,
    toUInt32(rand() % 1000) as agent_id,
    'LIFE-' || toString(toYear(now())) || '-' || toString(number) as policy_number,
    CAST(
        multiIf(
            rand() % 5 = 0, 'Term Life',
            rand() % 5 = 1, 'Whole Life',
            rand() % 5 = 2, 'Universal Life',
            rand() % 5 = 3, 'Variable Life',
            'Endowment'
        ) AS Enum8('Term Life' = 1, 'Whole Life' = 2, 'Universal Life' = 3, 'Variable Life' = 4, 'Endowment' = 5)
    ) as policy_type,
    round(rand() * 1000000 + 100000, 2) as coverage_amount,
    round(rand() * 5000 + 500, 2) as premium_amount,
    round(rand() * 1000, 2) as deductible_amount,
    (now() - toIntervalDay(rand() % 365))::Date as effective_date,
    (now() + toIntervalYear(20 + rand() % 20))::Date as end_date,
    CAST(
        multiIf(
            rand() % 10 = 0, 'Pending',
            rand() % 20 = 0, 'Lapsed',
            rand() % 50 = 0, 'Terminated',
            rand() % 100 = 0, 'Matured',
            'Active'
        ) AS Enum8('Active' = 1, 'Lapsed' = 2, 'Terminated' = 3, 'Matured' = 4, 'Pending' = 5)
    ) as status,
    now() as created_at,
    now() as updated_at,
    1 as version
FROM numbers(1_000_000);

-- Insert policies with calculated values
INSERT INTO policies (
    policy_id, customer_id, agent_id, policy_type, policy_number,
    coverage_amount, premium_amount, deductible_amount, 
    effective_date, end_date, status
) VALUES 
    (generateUUIDv4(), 5001, 501, 'Term Life', concat('POL-', toString(toUnixTimestamp(now()))), 
     500000.00, 1200.00, 0.00, today(), today() + INTERVAL 20 YEAR, 'Active'),
    (generateUUIDv4(), 5001, 501, 'Whole Life', concat('POL-', toString(toUnixTimestamp(now()) + 1)), 
     750000.00, 2400.00, 0.00, today(), today() + INTERVAL 30 YEAR, 'Active');

-- Insert claims with date calculations
INSERT INTO claims (
    claim_id, policy_id, customer_id, claim_type, claim_number,
    incident_date, claim_amount, claim_status, description, adjuster_id
)
SELECT 
    generateUUIDv4(),
    policy_id,
    customer_id,
    'Death',
    concat('CLM-', toString(toUnixTimestamp(now()))),
    effective_date + INTERVAL 365 DAY,
    coverage_amount * 0.8,
    'Reported',
    'Sample claim for testing',
    401
FROM policies
WHERE customer_id = 5001
LIMIT 1;

-- =============================================
-- 3. Conditional INSERT Operations
-- =============================================

-- INSERT IGNORE equivalent (using INSERT with WHERE NOT EXISTS pattern)
INSERT INTO customers (
    customer_id, first_name, last_name, email, phone,
    date_of_birth, address, city, state, zip_code, customer_type
)
SELECT 5002, 'Jane', 'Doe', 'jane.doe@email.com', '555-0102',
       '1985-08-22', '456 Oak St', 'Los Angeles', 'CA', '90210     ', 'Individual'
WHERE NOT EXISTS (
    SELECT 1 FROM customers WHERE customer_id = 5002
);

-- Conditional insert based on business rules
INSERT INTO policies (
    policy_id, customer_id, agent_id, policy_type, policy_number,
    coverage_amount, premium_amount, deductible_amount,
    effective_date, end_date, status
)
SELECT 
    generateUUIDv4(),
    c.customer_id,
    501,
    'Universal Life',
    concat('POL-UL-', toString(c.customer_id)),
    CASE 
        WHEN c.customer_type = 'Corporate' THEN 2000000.00
        WHEN c.customer_type = 'Family' THEN 1000000.00
        ELSE 500000.00
    END,
    CASE 
        WHEN c.customer_type = 'Corporate' THEN 4800.00
        WHEN c.customer_type = 'Family' THEN 2400.00
        ELSE 1200.00
    END,
    0.00,
    today(),
    today() + INTERVAL 25 YEAR,
    'Pending'
FROM customers c
WHERE c.customer_id IN (5001, 5002)
  AND NOT EXISTS (
      SELECT 1 FROM policies p 
      WHERE p.customer_id = c.customer_id 
      AND p.policy_type = 'Universal Life'
  );



SELECT name, value, default
FROM system.settings 
WHERE name IN ('max_insert_block_size', 'min_insert_block_size_rows', 'min_insert_block_size_bytes');


SET max_insert_block_size = DEFAULT;
SET min_insert_block_size_rows = DEFAULT;
SET min_insert_block_size_bytes = DEFAULT;

xml
<!-- In users.xml or settings profiles -->
<profiles>
    <default_profile>
        <max_insert_block_size>1048576</max_insert_block_size>
        <min_insert_block_size_rows>0</min_insert_block_size_rows>
        <min_insert_block_size_bytes>0</min_insert_block_size_bytes>
    </default_profile>
</profiles>
Then apply the profile:




