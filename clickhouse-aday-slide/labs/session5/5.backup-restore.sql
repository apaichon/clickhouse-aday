-- =============================================
-- Filesystem-level Backup (Manual)
-- =============================================

-- Stop ClickHouse service
```bash
$ systemctl stop clickhouse-server
```

-- Copy data directory
```bash
$ cp -r /var/lib/clickhouse /backup/clickhouse-data
```

-- =============================================
-- Using BACKUP Command (ClickHouse 21.8+)
-- =============================================

-- Example disk configuration: /etc/clickhouse-server/config.d/backup_disk.xml
```xml
<clickhouse>
    <storage_configuration>
        <disks>
            <backups>
                <type>local</type>
                <path>/backups/</path>
            </backups>
        </disks>
    </storage_configuration>
    <backups>
        <allowed_disk>backups</allowed_disk>
        <allowed_path>/backups/</allowed_path>
    </backups>
</clickhouse>
```

-- Create a backup of the entire database
```sql
BACKUP DATABASE chat_payments TO Disk('backups', 'chat_payments_backup')
    SETTINGS compression_level = 4;
```

-- Create a backup of a single table
```sql
BACKUP TABLE chat_payments.attachments TO Disk('backups', 'attachments.zip');
```

-- =============================================
-- Restore Example
-- =============================================

-- Check current row count
SELECT count(*) FROM chat_payments.attachments;

-- Truncate table before restore (optional, for demonstration)
TRUNCATE TABLE chat_payments.attachments;

-- Restore table from backup
RESTORE TABLE chat_payments.attachments FROM Disk('backups', 'attachments.zip');

-- =============================================
-- ClickHouse Session 5: Data Operations and Management - Backup and Restore
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Data Export for Backup (Using SELECT with FORMAT)
-- =============================================

-- Export customers data to CSV format (copy and save output manually)
SELECT 
    customer_id,
    first_name,
    last_name,
    email,
    phone,
    date_of_birth,
    address,
    city,
    state,
    zip_code,
    customer_type,
    created_at,
    is_active
FROM customers
WHERE _sign > 0  -- Only active records for CollapsingMergeTree
FORMAT CSV;

-- Export policies data with headers in CSV format
SELECT 
    'policy_id' as policy_id,
    'customer_id' as customer_id, 
    'agent_id' as agent_id,
    'policy_type' as policy_type,
    'policy_number' as policy_number,
    'coverage_amount' as coverage_amount,
    'premium_amount' as premium_amount,
    'deductible_amount' as deductible_amount,
    'effective_date' as effective_date,
    'end_date' as end_date,
    'status' as status,
    'created_at' as created_at,
    'updated_at' as updated_at,
    'version' as version

UNION ALL

SELECT 
    toString(policy_id),
    toString(customer_id),
    toString(agent_id),
    toString(policy_type),
    policy_number,
    toString(coverage_amount),
    toString(premium_amount),
    toString(deductible_amount),
    toString(effective_date),
    toString(end_date),
    toString(status),
    toString(created_at),
    toString(updated_at),
    toString(version)
FROM policies
FINAL  -- Get latest version for ReplacingMergeTree


-- Export claims data in JSON format
SELECT 
    claim_id,
    policy_id,
    customer_id,
    claim_type,
    claim_number,
    incident_date,
    reported_date,
    claim_amount,
    approved_amount,
    claim_status,
    description,
    adjuster_id
FROM claims
WHERE _sign > 0  -- Only active records


-- =============================================
-- 2. Incremental Backup Queries
-- =============================================

-- Export only recent policies (last 30 days)
SELECT *
FROM policies
FINAL
WHERE created_at >= today() - INTERVAL 30 DAY
SETTINGS format_csv_delimiter = ',';

-- Export claims by date range
SELECT *
FROM claims
WHERE _sign > 0
  AND reported_date >= '2024-01-01 00:00:00'
  AND reported_date < '2024-02-01 00:00:00'


-- Create backup of specific customer's data
WITH customer_data AS (
    SELECT 1001 as target_customer_id
)
SELECT 
    'CUSTOMERS' as data_type,
    toString(c.customer_id) as id,
    c.first_name,
    c.last_name,
    c.email
FROM customers c, customer_data cd
WHERE c.customer_id = cd.target_customer_id AND c._sign > 0

UNION ALL

SELECT 
    'POLICIES' as data_type,
    toString(p.policy_id) as id,
    p.policy_number,
    toString(p.policy_type),
    toString(p.coverage_amount)
FROM policies p, customer_data cd
WHERE p.customer_id = cd.target_customer_id

UNION ALL

SELECT 
    'CLAIMS' as data_type,
    toString(cl.claim_id) as id,
    cl.claim_number,
    toString(cl.claim_type),
    toString(cl.claim_amount)
FROM claims cl
JOIN policies p ON cl.policy_id = p.policy_id, customer_data cd
WHERE p.customer_id = cd.target_customer_id AND cl._sign > 0

FORMAT CSV;

-- =============================================
-- 3. Alternative Backup Methods
-- =============================================

-- Create backup tables (snapshot approach)
drop table if exists customers_backup;
CREATE TABLE customers_backup AS 
customers;

insert into customers_backup
SELECT *
FROM customers
WHERE _sign > 0;

CREATE TABLE policies_backup AS
policies;

insert into policies_backup
SELECT *
FROM policies
FINAL;

CREATE TABLE claims_backup AS
claims;


insert into claims_backup
SELECT *
FROM claims
WHERE _sign > 0;

-- =============================================
-- 4. Restore Operations (Using INSERT FROM SELECT)
-- =============================================

-- Create temporary table for restore testing
drop table if exists customers_restore_temp;
CREATE TABLE customers_restore_temp
as customers
ENGINE = Memory;

-- Restore from backup table
INSERT INTO customers_restore_temp
SELECT * FROM customers_backup;

-- Validate restored data
SELECT 
    'Original' as source,
    count() as record_count,
    min(created_at) as earliest_date,
    max(created_at) as latest_date
FROM customers
WHERE _sign > 0

UNION ALL

SELECT 
    'Backup' as source,
    count() as record_count,
    min(created_at) as earliest_date,
    max(created_at) as latest_date
FROM customers_backup

UNION ALL

SELECT 
    'Restored' as source,
    count() as record_count,
    min(created_at) as earliest_date,
    max(created_at) as latest_date
FROM customers_restore_temp;

-- =============================================
-- 5. Backup Verification Queries
-- =============================================

-- Verify data integrity after backup/restore
SELECT 
    table_name,
    record_count,
    checksum
FROM (
    SELECT 
        'customers_original' as table_name,
        count() as record_count,
        sum(cityHash64(toString(customer_id) || first_name || last_name)) as checksum
    FROM customers
    WHERE _sign > 0
    
    UNION ALL
    
    SELECT 
        'customers_backup' as table_name,
        count() as record_count,
        sum(cityHash64(toString(customer_id) || first_name || last_name)) as checksum
    FROM customers_backup
    
    UNION ALL
    
    SELECT 
        'policies_original' as table_name,
        count() as record_count,
        sum(cityHash64(toString(policy_id) || policy_number)) as checksum
    FROM policies
    FINAL
    
    UNION ALL
    
    SELECT 
        'policies_backup' as table_name,
        count() as record_count,
        sum(cityHash64(toString(policy_id) || policy_number)) as checksum
    FROM policies_backup
    
    UNION ALL
    
    SELECT 
        'claims_original' as table_name,
        count() as record_count,
        sum(cityHash64(toString(claim_id) || claim_number)) as checksum
    FROM claims
    WHERE _sign > 0
    
    UNION ALL
    
    SELECT 
        'claims_backup' as table_name,
        count() as record_count,
        sum(cityHash64(toString(claim_id) || claim_number)) as checksum
    FROM claims_backup
);

-- Check for data consistency across related tables
SELECT 
    'Policy-Customer Consistency (Original)' as check_type,
    count(*) as total_policies,
    sum(CASE WHEN c.customer_id IS NULL THEN 1 ELSE 0 END) as orphaned_policies
FROM policies p
FINAL
LEFT JOIN (
    SELECT customer_id FROM customers WHERE _sign > 0
) c ON p.customer_id = c.customer_id

UNION ALL

SELECT 
    'Policy-Customer Consistency (Backup)' as check_type,
    count(*) as total_policies,
    sum(CASE WHEN c.customer_id IS NULL THEN 1 ELSE 0 END) as orphaned_policies
FROM policies_backup p
LEFT JOIN customers_backup c ON p.customer_id = c.customer_id

UNION ALL

SELECT 
    'Claim-Policy Consistency (Original)' as check_type,
    count(*) as total_claims,
    sum(CASE WHEN p.policy_id IS NULL THEN 1 ELSE 0 END) as orphaned_claims
FROM claims cl
LEFT JOIN policies p ON cl.policy_id = p.policy_id
WHERE cl._sign > 0

UNION ALL

SELECT 
    'Claim-Policy Consistency (Backup)' as check_type,
    count(*) as total_claims,
    sum(CASE WHEN p.policy_id IS NULL THEN 1 ELSE 0 END) as orphaned_claims
FROM claims_backup cl
LEFT JOIN policies_backup p ON cl.policy_id = p.policy_id;

-- =============================================
-- 6. Cleanup Backup Tables (Optional)
-- =============================================

-- Uncomment to clean up backup tables after verification
-- DROP TABLE IF EXISTS customers_backup;
-- DROP TABLE IF EXISTS policies_backup;
-- DROP TABLE IF EXISTS claims_backup;
-- DROP TABLE IF EXISTS customers_restore_temp;