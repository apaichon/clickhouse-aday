-- =============================================
-- ClickHouse Table Engines Examples
-- =============================================

-- =============================================
-- 1. ReplacingMergeTree Engine
-- =============================================
-- Purpose: Automatically replaces duplicate rows with the latest version
-- Key features: Version-based replacement, deduplication

CREATE TABLE product_catalog
(
    product_id UInt32,
    product_name String,
    price Decimal(10,2),
    stock_quantity Int32,
    last_updated DateTime,
    version UInt32
) ENGINE = ReplacingMergeTree(version)
PRIMARY KEY product_id
ORDER BY product_id;

-- Sample Data
INSERT INTO product_catalog VALUES
    (1, 'Laptop', 999.99, 50, '2024-01-01 10:00:00', 1),
    (1, 'Laptop', 899.99, 45, '2024-01-02 10:00:00', 2); -- Updated price and stock

-- Query Examples
-- View all rows including duplicates
SELECT * FROM product_catalog FINAL;

-- Optimize table to remove duplicates
OPTIMIZE TABLE product_catalog FINAL;

-- View final state after optimization
SELECT * FROM product_catalog;


-- =============================================
-- 2. CollapsingMergeTree Engine
-- =============================================
-- Purpose: Efficiently tracks changes by collapsing rows with opposite signs
-- Key features: Sign-based collapsing, efficient updates

DROP TABLE IF EXISTS inventory_movements;
CREATE TABLE inventory_movements
(
    product_id UInt32,
    warehouse_id UInt16,
    quantity Int32,
    operation_time DateTime,
    sign Int8 -- 1 for addition, -1 for subtraction
) ENGINE = CollapsingMergeTree(sign)
PRIMARY KEY (product_id)
ORDER BY (product_id, warehouse_id, operation_time);

-- Sample Data
INSERT INTO inventory_movements VALUES (1, 1, 100, '2024-01-01 10:00:00', 1);    -- Received 100 units
INSERT INTO inventory_movements VALUES (1, 1, -20, '2024-01-01 11:00:00', 1);    -- Sold 20 units
INSERT INTO inventory_movements VALUES (1, 1, 20, '2024-01-01 11:00:00', -1);    -- Delete Sold 20 units
INSERT INTO inventory_movements VALUES (1, 1, 50, '2024-01-01 12:00:00', 1);     -- Received 50 more units

-- Query Examples
-- View all movements including collapsed rows
SELECT * FROM inventory_movements;

-- View final state with collapsed rows
SELECT * FROM inventory_movements FINAL;

-- Optimize and view final state
OPTIMIZE TABLE inventory_movements FINAL;
SELECT * FROM inventory_movements;


-- =============================================
-- 3. SummingMergeTree Engine
-- =============================================
-- Purpose: Automatically sums numeric columns for duplicate rows
-- Key features: Automatic summation, efficient aggregation

DROP TABLE IF EXISTS daily_sales;
CREATE TABLE daily_sales
(
    date Date,
    product_id UInt32,
    total_revenue Decimal(15,2),
    items_sold UInt32,
    return_count UInt32
) ENGINE = SummingMergeTree()
ORDER BY (date, product_id)
PARTITION BY toYYYYMM(date);

-- Sample Data
INSERT INTO daily_sales VALUES
    ('2024-01-01', 1, 1000.00, 10, 1),
    ('2024-01-01', 1, 2000.00, 20, 2),
    ('2024-01-01', 2, 500.00, 5, 0);

-- Query Examples
-- View initial state
SELECT * FROM daily_sales;

-- Insert additional data
INSERT INTO daily_sales VALUES
    ('2024-01-01', 1, 1000.00, 10, 1);

-- View state before optimization
SELECT * FROM daily_sales;

-- Optimize and view final summed state
OPTIMIZE TABLE daily_sales FINAL;


-- =============================================
-- 4. VersionedCollapsingMergeTree Engine
-- =============================================
-- Purpose: Tracks changes with versioning and collapsing
-- Key features: Version-based collapsing, efficient updates

DROP TABLE IF EXISTS vehicle_locations;
CREATE TABLE vehicle_locations
(
    vehicle_id UInt32,
    geofence_id UInt32,
    entry_time DateTime,
    version UInt32,
    sign Int8
) ENGINE = VersionedCollapsingMergeTree(sign, version)
ORDER BY (vehicle_id, geofence_id, entry_time);

-- Sample Data
INSERT INTO vehicle_locations VALUES  (1, 100, '2024-01-01 10:00:00', 1, 1);    -- Enter geofence 100
INSERT INTO vehicle_locations VALUES  (1, 100, '2024-01-01 10:00:00', 1, -1);   -- Exit geofence 100
INSERT INTO vehicle_locations VALUES  (1, 103, '2024-01-01 10:00:00', 2, 1);    -- Enter geofence 103
INSERT INTO vehicle_locations VALUES  (1, 101, '2024-01-01 10:31:00', 3, 1);    -- Enter geofence 101

-- Query Examples
-- View all movements
SELECT * FROM vehicle_locations;

-- View final state with collapsed rows
SELECT * FROM vehicle_locations FINAL;

-- Optimize and view final state
OPTIMIZE TABLE vehicle_locations FINAL;
SELECT * FROM vehicle_locations;


-- =============================================
-- 5. AggregatingMergeTree Engine
-- =============================================
-- Purpose: Pre-aggregates data using aggregate functions
-- Key features: Automatic aggregation, efficient storage

DROP TABLE IF EXISTS customer_behavior;
CREATE TABLE customer_behavior
(
    date Date,
    customer_id UInt32,
    total_visits AggregateFunction(sum, UInt8),
    avg_session_duration AggregateFunction(avg, Float64),
    product_categories AggregateFunction(groupUniqArray, String)
) ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, customer_id);

-- Sample Data
INSERT INTO customer_behavior
SELECT 
    date,
    customer_id,
    sumState(CAST(visits AS UInt8)),
    avgState(CAST(duration AS Float64)),
    groupUniqArrayState(category)
FROM (
    -- Initial sample data
    SELECT
        toDate('2024-01-01') as date,
        1 as customer_id,
        1 as visits,
        300.0 as duration,
        'Electronics' as category
    UNION ALL
    SELECT
        toDate('2024-01-01'),
        1,
        1,
        400.0,
        'Clothing'
) raw
GROUP BY date, customer_id;

-- Query Examples
-- Query aggregated results
SELECT
    date,
    customer_id,
    sumMerge(total_visits) as total_visits,
    avgMerge(avg_session_duration) as avg_duration,
    groupUniqArrayMerge(product_categories) as categories
FROM customer_behavior
GROUP BY date, customer_id;

-- View raw state
SELECT * FROM customer_behavior;

-- Insert additional data
INSERT INTO customer_behavior 
SELECT 
    date,
    customer_id,
    sumState(CAST(visits AS UInt8)),
    avgState(CAST(duration AS Float64)),
    groupUniqArrayState(category)
FROM (
    SELECT
        toDate('2024-01-01') as date,
        1 as customer_id,
        1 as visits,
        300.0 as duration,
        'Electronics' as category
) raw
GROUP BY date, customer_id;

-- View state before optimization
SELECT * FROM customer_behavior;

-- View final state with collapsed rows
SELECT * FROM customer_behavior FINAL;

-- Optimize and view final state
OPTIMIZE TABLE customer_behavior FINAL;
SELECT * FROM customer_behavior;