-- =============================================
-- 1. Event Sourcing Pattern : PostgreSQL
-- =============================================

CREATE TABLE order_events (
    order_id BIGINT NOT NULL,
    event_time TIMESTAMP NOT NULL DEFAULT NOW(),
    event_type TEXT NOT NULL, -- 'Created', 'ItemAdded', etc.
    event_data JSONB NOT NULL, -- JSON payload with details
    event_id BIGSERIAL PRIMARY KEY
);

-- Sample events
INSERT INTO order_events (order_id, event_type, event_data) VALUES
    (1, 'Created',    '{"status": "Pending", "total": 100.0}'),
    (1, 'ItemAdded',  '{"item_id": "123", "quantity": 2}'),
    (1, 'ItemAdded',  '{"item_id": "456", "quantity": 1}'),
    (1, 'ItemRemoved','{"item_id": "123", "quantity": 2}'),
    (1, 'ItemAdded',  '{"item_id": "789", "quantity": 1}'),
    (2, 'Created',    '{"status": "Pending", "total": 500.0}');

-- Get latest event per order
SELECT DISTINCT ON (order_id)
    order_id,
    event_time AS last_event_time,
    event_type AS last_event_type,
    event_data AS last_event_data,
    event_id   AS last_event_id
FROM order_events
ORDER BY order_id, event_time DESC;

-- Get current status and total for each order
SELECT
    order_id,
    (event_data->>'status') AS current_status,
    (event_data->>'total')::float AS current_total
FROM (
    SELECT DISTINCT ON (order_id)
        order_id,
        event_data
    FROM order_events
    WHERE event_data ? 'status' AND event_data ? 'total'
    ORDER BY order_id, event_time DESC
) latest_status;


-- =============================================
-- 2. Bi-Temporal Modeling Pattern : PostgreSQL
-- =============================================

CREATE TABLE products_bitemporal (
    product_id INTEGER,
    name TEXT,
    price NUMERIC(10, 2),
    valid_from TIMESTAMP,   -- When this fact became true in business
    valid_to TIMESTAMP,     -- When this fact ceased to be true
    system_from TIMESTAMP,  -- When this record was inserted
    system_to TIMESTAMP,    -- When this record was logically deleted
    is_current BOOLEAN      -- Flag for current version
);

TRUNCATE TABLE products_bitemporal;

-- Initial data
INSERT INTO products_bitemporal (product_id, name, price, valid_from, system_from, is_current) VALUES
    (1, 'Product A', 100.00, '2023-01-01 00:00:00', '2023-01-01 00:00:00', TRUE),
    (2, 'Product B', 200.00, '2023-01-01 00:00:00', '2023-01-01 00:00:00', TRUE);

SELECT * FROM products_bitemporal;

-- Example update and insert in a transaction
BEGIN;

UPDATE products_bitemporal
SET valid_to  = (SELECT min(valid_from) FROM products_bitemporal WHERE product_id = 1),
    system_to = (SELECT min(system_from) FROM products_bitemporal WHERE product_id = 1),
    is_current = FALSE
WHERE product_id = 1 AND valid_from < now();

INSERT INTO products_bitemporal (product_id, name, price, valid_from, system_from, is_current)
VALUES (1, 'Product A', 100.00, now(), now(), TRUE);

COMMIT;

-- Get current active records
SELECT * FROM products_bitemporal WHERE is_current = TRUE;

-- Get records where valid_to or system_to is null (still open)
SELECT * FROM products_bitemporal WHERE valid_to IS NULL OR system_to IS NULL;


    -- =============================================
    -- 3. Snapshot Pattern : PostgreSQL
    -- =============================================

CREATE TABLE account_snapshots (
    account_id BIGINT,
    snapshot_time TIMESTAMP NOT NULL,
    balance NUMERIC(18,2),
    status TEXT,
    PRIMARY KEY (account_id, snapshot_time)
);

-- Sample snapshots
INSERT INTO account_snapshots (account_id, snapshot_time, balance, status) VALUES
    (1, '2024-06-01 00:00:00', 1000.00, 'active'),
    (1, '2024-07-01 00:00:00', 1200.00, 'active'),
    (2, '2024-06-01 00:00:00', 500.00, 'inactive'),
    (2, '2024-07-01 00:00:00', 700.00, 'active');

-- Compare balances between two snapshots
SELECT
    a.account_id,
    a.balance AS balance_at_start,
    b.balance AS balance_at_end,
    (b.balance - a.balance) AS balance_diff
FROM
    account_snapshots a
JOIN
    account_snapshots b
    ON a.account_id = b.account_id
WHERE
    a.snapshot_time = '2024-06-01 00:00:00'
    AND b.snapshot_time = '2024-07-01 00:00:00';





