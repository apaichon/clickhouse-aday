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
    effective_date Date,
    end_date Date,
    status Enum8('Active' = 1, 'Lapsed' = 2, 'Terminated' = 3, 'Matured' = 4, 'Pending' = 5),
    created_at DateTime DEFAULT now(),
    updated_at DateTime DEFAULT now(),
    version UInt32 DEFAULT 1
)
ENGINE = ReplacingMergeTree(version)
PARTITION BY (toYYYYMM(effective_date), policy_type)
ORDER BY (policy_id, customer_id, effective_date)
SETTINGS index_granularity = 8192;


-- Option 1: Customer-First Design (Recommended for Customer-Centric Queries)
CREATE TABLE policies_optimized
(
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
ORDER BY (customer_id, effective_date, policy_type, policy_id)  -- Customer-first ordering
PRIMARY KEY (customer_id, effective_date)  -- Explicit primary key
SETTINGS index_granularity = 8192;

-- Option 2: Time-First Design (Recommended for Time-Based Queries)
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

CREATE TABLE policies
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
