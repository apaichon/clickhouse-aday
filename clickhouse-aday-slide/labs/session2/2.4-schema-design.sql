-- ClickHouse Life Insurance Database Schema
-- Session 2: Schema Design and Table Creation

-- Create database
CREATE DATABASE IF NOT EXISTS life_insurance;
USE life_insurance;

-- 1. Customers Table
CREATE TABLE customers
(
    customer_id UInt64,
    first_name String,
    last_name String,
    email String,
    phone String,
    date_of_birth Date,
    address String,
    city LowCardinality(String),
    state LowCardinality(String),
    zip_code FixedString(10),
    customer_type Enum8('Individual' = 1, 'Corporate' = 2, 'Family' = 3),
    created_at DateTime DEFAULT now(),
    is_active UInt8 DEFAULT 1,
    _sign Int8 DEFAULT 1,
    beneficiaries String DEFAULT ''
)
ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(created_at)
ORDER BY (customer_id, created_at)
SETTINGS index_granularity = 8192;

-- 2. Agents Table  
CREATE TABLE agents
(
    agent_id UInt32,
    first_name String,
    last_name String,
    email String,
    phone String,
    license_number String,
    territory LowCardinality(String),
    commission_rate Decimal64(4),
    hire_date Date,
    is_active UInt8 DEFAULT 1,
    _sign Int8 DEFAULT 1
)
ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(hire_date)
ORDER BY (agent_id, hire_date)
SETTINGS index_granularity = 8192;

-- 3. Employees Table
CREATE TABLE employees
(
    employee_id UInt32,
    first_name String,
    last_name String,
    email String,
    phone String,
    employee_number String,
    department LowCardinality(String),
    salary Decimal64(2),
    hire_date Date,
    is_active UInt8 DEFAULT 1,
    _sign Int8 DEFAULT 1
)
ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(hire_date)
ORDER BY (employee_id, department, hire_date)
SETTINGS index_granularity = 8192;

-- 4. Officers in Charge (OIC) Table
CREATE TABLE oic
(
    oic_id UInt32,
    first_name String,
    last_name String,
    email String,
    phone String,
    license_number String,
    region LowCardinality(String),
    commission_rate Decimal64(4),
    appointment_date Date,
    is_active UInt8 DEFAULT 1,
    _sign Int8 DEFAULT 1
)
ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(appointment_date)
ORDER BY (oic_id, region, appointment_date)
SETTINGS index_granularity = 8192;

-- 5. Policies Table
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



-- 6. Claims Table
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

-- 7. Policy Documents Table
CREATE TABLE policy_documents
(
    document_id UUID,
    policy_id UUID,
    document_type Enum8('Application' = 1, 'Policy Certificate' = 2, 'Medical Report' = 3, 'Amendment' = 4, 'Claim Form' = 5),
    file_path String,
    file_size UInt32,
    content_type LowCardinality(String),
    upload_date DateTime DEFAULT now(),
    document_date Date,
    _sign Int8 DEFAULT 1
)
ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(upload_date)
ORDER BY (document_id, policy_id, upload_date)
SETTINGS index_granularity = 8192;

-- Create indexes for better query performance
-- Secondary indexes for frequently queried columns

-- Customer email index
ALTER TABLE customers ADD INDEX idx_customer_email email TYPE bloom_filter() GRANULARITY 1;

-- Agent license number index  
ALTER TABLE agents ADD INDEX idx_agent_license license_number TYPE bloom_filter() GRANULARITY 1;

-- Policy number index
ALTER TABLE policies ADD INDEX idx_policy_number policy_number TYPE bloom_filter() GRANULARITY 1;

-- Claim number index
ALTER TABLE claims ADD INDEX idx_claim_number claim_number TYPE bloom_filter() GRANULARITY 1;

-- Sample data insertion queries for testing

-- Insert sample customers
INSERT INTO customers (customer_id, first_name, last_name, email, phone, date_of_birth, address, city, state, zip_code, customer_type) VALUES
(1, 'John', 'Smith', 'john.smith@email.com', '555-0101', '1980-05-15', '123 Main St', 'New York', 'NY', '10001     ', 'Individual'),
(2, 'Jane', 'Doe', 'jane.doe@email.com', '555-0102', '1975-08-22', '456 Oak Ave', 'Los Angeles', 'CA', '90210     ', 'Individual'),
(3, 'Robert', 'Johnson', 'robert.j@company.com', '555-0103', '1970-12-10', '789 Pine Rd', 'Chicago', 'IL', '60601     ', 'Corporate');

-- Insert sample agents
INSERT INTO agents (agent_id, first_name, last_name, email, phone, license_number, territory, commission_rate, hire_date) VALUES
(101, 'Alice', 'Wilson', 'alice.wilson@company.com', '555-0201', 'LIC123456', 'Northeast', 0.0250, '2020-01-15'),
(102, 'Bob', 'Brown', 'bob.brown@company.com', '555-0202', 'LIC123457', 'West Coast', 0.0275, '2019-03-22'),
(103, 'Carol', 'Davis', 'carol.davis@company.com', '555-0203', 'LIC123458', 'Midwest', 0.0300, '2021-06-10');

-- Insert sample policies
INSERT INTO policies (policy_id, customer_id, agent_id, policy_type, policy_number, coverage_amount, premium_amount, deductible_amount, effective_date, end_date, status, version) VALUES
(generateUUIDv4(), 1, 101, 'Term Life', 'POL-2024-001', 500000.00, 1200.00, 0.00, '2024-01-01', '2044-01-01', 'Active', 1),
(generateUUIDv4(), 2, 102, 'Whole Life', 'POL-2024-002', 750000.00, 2400.00, 0.00, '2024-02-15', '2074-02-15', 'Active', 1),
(generateUUIDv4(), 3, 103, 'Universal Life', 'POL-2024-003', 1000000.00, 3600.00, 0.00, '2024-03-01', '2054-03-01', 'Active', 1);

-- Show table structures
SHOW TABLES FROM life_insurance;

-- Describe table structures
DESCRIBE TABLE customers;
DESCRIBE TABLE policies;
DESCRIBE TABLE claims;