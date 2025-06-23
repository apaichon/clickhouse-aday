-- =============================================
-- ClickHouse Session 5: Data Operations and Management - Deduplication
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Identifying Duplicate Records
-- =============================================

-- Find duplicate customers by email
SELECT 
    email,
    count() as duplicate_count,
    groupArray(customer_id) as customer_ids
FROM customers
GROUP BY email
HAVING count() > 1
ORDER BY duplicate_count DESC;

-- Find duplicate policies by policy number
SELECT 
    policy_number,
    count() as duplicate_count,
    groupArray(policy_id) as policy_ids,
    groupArray(customer_id) as customer_ids
FROM policies
GROUP BY policy_number
HAVING count() > 1
ORDER BY duplicate_count DESC;

-- Find potential duplicate customers by name and date of birth
SELECT 
    first_name,
    last_name,
    date_of_birth,
    count() as duplicate_count,
    groupArray(customer_id) as customer_ids,
    groupArray(email) as emails
FROM customers
GROUP BY first_name, last_name, date_of_birth
HAVING count() > 1
ORDER BY duplicate_count DESC;

-- Find duplicate claims by policy and incident details
SELECT 
    policy_id,
    claim_type,
    incident_date,
    claim_amount,
    count() as duplicate_count,
    groupArray(claim_id) as claim_ids
FROM claims
GROUP BY policy_id, claim_type, incident_date, claim_amount
HAVING count() > 1
ORDER BY duplicate_count DESC;

-- Find duplicate agents by license number
SELECT 
    license_number,
    count() as duplicate_count,
    groupArray(agent_id) as agent_ids,
    groupArray(concat(first_name, ' ', last_name)) as agent_names
FROM agents
GROUP BY license_number
HAVING count() > 1
ORDER BY duplicate_count DESC;

-- =============================================
-- 2. Deduplication Using Window Functions
-- =============================================

-- Identify duplicate claims using row_number
WITH ranked_claims AS (
    SELECT 
        *,
        row_number() OVER (
            PARTITION BY policy_id, claim_type, incident_date, claim_amount
            ORDER BY reported_date ASC
        ) as rn
    FROM claims
)
SELECT *
FROM ranked_claims
WHERE rn > 1  -- These are duplicates
ORDER BY policy_id, claim_type;

-- Find latest version of each policy (for ReplacingMergeTree)
WITH latest_policies AS (
    SELECT 
        *,
        row_number() OVER (
            PARTITION BY policy_id
            ORDER BY version DESC, updated_at DESC
        ) as rn
    FROM policies
)
SELECT 
    policy_id,
    policy_number,
    customer_id,
    status,
    version,
    updated_at
FROM latest_policies
WHERE rn = 1
ORDER BY policy_id;

-- =============================================
-- 3. Deduplication Strategies for Different Table Engines
-- =============================================

-- For ReplacingMergeTree (policies table)
-- Force merge to remove old versions
OPTIMIZE TABLE policies FINAL;

-- Query to get deduplicated data from ReplacingMergeTree
SELECT 
    policy_id,
    customer_id,
    policy_number,
    policy_type,
    coverage_amount,
    status,
    version
FROM policies
FINAL  -- This ensures we get the latest version
WHERE status = 'Active'
ORDER BY policy_id;

-- For CollapsingMergeTree (customers, claims tables)
-- Insert cancellation record (_sign = -1)
INSERT INTO customers (
    customer_id, first_name, last_name, email, phone,
    date_of_birth, address, city, state, zip_code, 
    customer_type, created_at, _sign
) VALUES (
    6001, 'John', 'Smith', 'john.smith.old@email.com', '555-0101',
    '1980-05-15', '123 Old St', 'New York', 'NY', '10001     ',
    'Individual', now(), -1  -- Cancellation record
);

-- Then insert corrected record
INSERT INTO customers (
    customer_id, first_name, last_name, email, phone,
    date_of_birth, address, city, state, zip_code, 
    customer_type, created_at, _sign
) VALUES (
    6001, 'John', 'Smith', 'john.smith.corrected@email.com', '555-0101',
    '1980-05-15', '123 Corrected St', 'New York', 'NY', '10001     ',
    'Individual', now(), 1  -- New correct record
);

-- Query CollapsingMergeTree with proper aggregation
SELECT 
    customer_id,
    argMax(first_name, _sign) as first_name,
    argMax(last_name, _sign) as last_name,
    argMax(email, _sign) as email,
    argMax(phone, _sign) as phone,
    sum(_sign) as final_sign
FROM customers
WHERE customer_id = 6001
GROUP BY customer_id
HAVING final_sign > 0;  -- Only records that haven't been cancelled

-- =============================================
-- 4. Creating Deduplicated Views
-- =============================================

-- Create a view for deduplicated active policies
CREATE VIEW active_policies_dedup AS
SELECT 
    policy_id,
    customer_id,
    agent_id,
    policy_type,
    policy_number,
    coverage_amount,
    premium_amount,
    effective_date,
    status,
    version
FROM policies
FINAL
WHERE status IN ('Active', 'Pending');

-- Create a view for deduplicated customers
CREATE VIEW customers_dedup AS
SELECT 
    customer_id,
    argMax(first_name, created_at) as first_name,
    argMax(last_name, created_at) as last_name,
    argMax(email, created_at) as email,
    argMax(phone, created_at) as phone,
    argMax(date_of_birth, created_at) as date_of_birth,
    argMax(customer_type, created_at) as customer_type,
    sum(_sign) as active_sign
FROM customers
GROUP BY customer_id
HAVING active_sign > 0;

-- =============================================
-- 5. Cleanup Operations
-- =============================================

-- Remove duplicate policy documents (keep the latest)
-- First, identify duplicates
WITH duplicate_docs AS (
    SELECT 
        policy_id,
        document_type,
        count() as doc_count,
        max(upload_date) as latest_upload
    FROM policy_documents
    GROUP BY policy_id, document_type
    HAVING count() > 1
)
SELECT 
    pd.document_id,
    pd.policy_id,
    pd.document_type,
    pd.upload_date,
    CASE WHEN pd.upload_date = dd.latest_upload THEN 'KEEP' ELSE 'DELETE' END as action
FROM policy_documents pd
JOIN duplicate_docs dd ON pd.policy_id = dd.policy_id AND pd.document_type = dd.document_type
ORDER BY pd.policy_id, pd.document_type, pd.upload_date DESC;

-- For CollapsingMergeTree, mark old documents as deleted
INSERT INTO policy_documents (
    document_id, policy_id, document_type, file_path, file_size,
    content_type, upload_date, document_date, _sign
)
SELECT 
    document_id, policy_id, document_type, file_path, file_size,
    content_type, upload_date, document_date, -1  -- Mark as deleted
FROM policy_documents
WHERE (policy_id, document_type, upload_date) IN (
    SELECT policy_id, document_type, min(upload_date)
    FROM policy_documents
    GROUP BY policy_id, document_type
    HAVING count() > 1
);


