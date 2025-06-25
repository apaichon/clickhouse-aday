-- Freeze Database Script
-- This script freezes all tables in the life_insurance database

USE life_insurance;

-- Freeze all main tables
ALTER TABLE customers FREEZE;
ALTER TABLE agents FREEZE;
ALTER TABLE employees FREEZE;
ALTER TABLE oic FREEZE;
ALTER TABLE policies FREEZE;
ALTER TABLE claims FREEZE;
ALTER TABLE policy_documents FREEZE;

-- Check frozen parts
SELECT 
    database,
    table,
    partition,
    name,
    disk_name,
    path
FROM system.parts
WHERE database = 'life_insurance'
  AND active = 1
ORDER BY database, table, partition;

-- Show freeze status
SELECT 
    'Freeze completed at: ' || toString(now()) as status;

-- Optional: Freeze with backup names for identification
-- ALTER TABLE customers FREEZE WITH NAME 'customers_freeze_2025_06_25';
-- ALTER TABLE policies FREEZE WITH NAME 'policies_freeze_2025_06_25'; 