-- =============================================
-- Insert Sample Data into life_insurance Database
-- =============================================

-- 1. Insert multiple policies
INSERT INTO life_insurance.policies VALUES
    (generateUUIDv4(), 1001, 201, 'Term Life', 'LIFE-2025-001', 500000.00, 1200.00, 0.00, today(), today() + INTERVAL 20 YEAR, 'Active', now(), now(), 1),
    (generateUUIDv4(), 1002, 201, 'Whole Life', 'LIFE-2025-002', 250000.00, 2400.00, 0.00, today(), today() + INTERVAL 20 YEAR, 'Active', now(), now(), 1),
    (generateUUIDv4(), 1003, 202, 'Universal Life', 'LIFE-2025-003', 750000.00, 3600.00, 0.00, today(), today() + INTERVAL 20 YEAR, 'Active', now(), now(), 1),
    (generateUUIDv4(), 1004, 203, 'Term Life', 'LIFE-2025-004', 1000000.00, 4800.00, 0.00, today(), today() + INTERVAL 20 YEAR, 'Active', now(), now(), 1);


-- 2. Insert a single claim record (with explicit columns)
INSERT INTO life_insurance.claims (
    claim_id, policy_id, customer_id, claim_type, claim_number,
    incident_date, reported_date, claim_amount, approved_amount,
    claim_status, description, adjuster_id, _sign
) VALUES (
    generateUUIDv4(), 
    '550e8400-e29b-41d4-a716-446655440000',
    1001, 
    'Death', 
    'CLM-2025-001',
    '2025-03-15', 
    '2025-03-20 09:30:00',
    500000.00,
    500000.00,
    'Approved',
    'Life insurance death benefit claim',
    301,
    1
);


-- Insert multiple claim records
INSERT INTO claims VALUES
    (generateUUIDv4(), generateUUIDv4(), 1001, 'Death', 'CLM-2025-001', toDate('2025-04-01'), parseDateTimeBestEffort('2025-04-01 10:00:00'), 500000, 500000, 'Paid', 'Death benefit claim', 301, 1),
    (generateUUIDv4(), generateUUIDv4(), 1002, 'Disability', 'CLM-2025-002', toDate('2025-04-02'), parseDateTimeBestEffort('2025-04-02 10:00:00'), 60000, 60000, 'Paid', 'Disability insurance claim', 302, 1),
    (generateUUIDv4(), generateUUIDv4(), 1003, 'Surrender', 'CLM-2025-003', toDate('2025-04-03'), parseDateTimeBestEffort('2025-04-03 10:00:00'), 75000, 75000, 'Under Review', 'Policy surrender request', 303, 1),
    (generateUUIDv4(), generateUUIDv4(), 1004, 'Disability', 'CLM-2025-004', toDate('2025-04-04'), parseDateTimeBestEffort('2025-04-04 10:00:00'), 80000, 80000, 'Paid', 'Partial disability claim', 304, 1),
    (generateUUIDv4(), generateUUIDv4(), 1005, 'Death', 'CLM-2025-005', toDate('2025-04-05'), parseDateTimeBestEffort('2025-04-05 10:00:00'), 90000, 90000, 'Paid', 'Life insurance death claim', 305, 1),
    (generateUUIDv4(), generateUUIDv4(), 1006, 'Maturity', 'CLM-2025-006', toDate('2025-04-06'), parseDateTimeBestEffort('2025-04-06 10:00:00'), 100000, 0, 'Denied', 'Policy maturity claim - denied', 306, 1);
