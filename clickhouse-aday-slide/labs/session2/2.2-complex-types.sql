-- =============================================
-- 1. Array Types Example - E-commerce Products
-- =============================================

-- Create products table with array types
CREATE TABLE products (
    product_id UInt32,
    name String,
    price Decimal64(2),
    categories Array(String),                    -- Multiple categories per product
    tag_ids Array(UInt16),                      -- Multiple tag IDs
    price_history Array(Tuple(DateTime, Decimal64(2))),  -- Historical prices with timestamps
    inventory Array(Array(UInt16))              -- Multidimensional array for size variations
) ENGINE = MergeTree()
ORDER BY product_id;

-- Insert sample product data
INSERT INTO products VALUES 
(1001, 'Ultra Comfort Running Shoes', 89.99,
    ['Footwear', 'Sports', 'Running'],
    [42, 56, 73],
    [(toDateTime('2023-01-01 00:00:00'), 79.99), 
     (toDateTime('2023-03-15 00:00:00'), 84.99), 
     (toDateTime('2023-06-01 00:00:00'), 89.99)],
    [[25, 30, 15], [40, 35, 20], [30, 25, 10]]  -- Inventory: [S,M,L] × [Red,Blue,Green]
);

INSERT INTO products VALUES 
(1002, 'Elegant Evening Dress', 199.99,
    ['Dresses', 'Evening', 'Formal'],
    [12, 14, 16],
    [(toDateTime('2023-02-01 00:00:00'), 179.99), 
     (toDateTime('2023-04-15 00:00:00'), 209.99), 
     (toDateTime('2023-07-01 00:00:00'), 229.99)],
    [[10, 12, 8], [20, 18, 15], [15, 10, 12]]
);

INSERT INTO products VALUES 
(1003, 'Stylish Casual T-Shirt', 29.99,
    ['T-Shirts', 'Casual', 'Men'],
    [101, 102, 103],
    [(toDateTime('2023-03-01 00:00:00'), 24.99), 
     (toDateTime('2023-05-15 00:00:00'), 29.99), 
     (toDateTime('2023-08-01 00:00:00'), 34.99)],
    [[50, 40, 30], [35, 30, 25], [45, 40, 35]]
);

-- Array Query Examples
-- 1. Products with specific category
SELECT product_id, name 
FROM products 
WHERE has(categories, 'Running');

-- 2. Count products per category
SELECT 
    category,
    count() AS product_count
FROM products
ARRAY JOIN categories AS category
GROUP BY category
ORDER BY product_count DESC;

-- 3. Find products with at least 3 categories
SELECT product_id, name
FROM products
WHERE length(categories) >= 3;

-- 4. Calculate average price
SELECT 
    product_id,
    name,
    avg(price_point.2) AS avg_price
FROM products
ARRAY JOIN price_history AS price_point
GROUP BY product_id, name;

-- =============================================
-- 2. Nested Types Example - E-commerce Orders
-- =============================================

CREATE TABLE orders (
    order_id UInt32,
    customer_id UInt32,
    order_date DateTime,
    order_items Nested(
        product_id UInt32,
        quantity UInt16,
        price Decimal64(2),
        discount Decimal64(2)
    ),
    total_amount Decimal64(2),
    payment_method Enum8('credit_card' = 1, 'paypal' = 2, 'bank_transfer' = 3),
    shipping_address String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(order_date)
ORDER BY (customer_id, order_date);

-- Insert sample order
INSERT INTO orders VALUES (
    10001, 5001, '2023-07-15 14:30:00',
    [1001, 2002, 3003],          -- product_id array
    [2, 1, 3],                   -- quantity array
    [89.99, 25.50, 12.99],       -- price array
    [0, 5.10, 0],                -- discount array
    157.36, 1, '123 Main St, Anytown, US'
);

-- Nested Data Query Examples
-- 1. Calculate total items sold per product
SELECT 
    order_items.product_id,
    sum(order_items.quantity) AS total_quantity
FROM orders
ARRAY JOIN order_items
GROUP BY order_items.product_id
ORDER BY total_quantity DESC;

-- 2. Find orders with specific product
SELECT 
    order_id,
    order_date
FROM orders
ARRAY JOIN order_items
WHERE order_items.product_id = 1001;

-- 3. Calculate revenue by product
SELECT
    order_items.product_id,
    sum(order_items.quantity * 
        (order_items.price - order_items.discount)) AS revenue
FROM orders
ARRAY JOIN order_items
GROUP BY order_items.product_id
ORDER BY revenue DESC;

-- =============================================
-- 3. Tuple Types Example - Ride-Sharing Events
-- =============================================


CREATE TABLE ride_events (
    ride_id UInt64,
    driver_id UInt32,
    rider_id UInt32,
    event_time DateTime64(3),
    event_type Enum8('requested' = 1, 'accepted' = 2, 'started' = 3, 'completed' = 4, 'canceled' = 5),
    coordinates Tuple(Float64, Float64),
    address Tuple(
        street String,
        city LowCardinality(String),
        state LowCardinality(String),
        zip FixedString(5)
    ),
    stats Tuple(
        distance_km Float32,
        duration_min UInt16,
        fare Decimal64(2)
    )
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (driver_id, event_time);

-- Insert sample ride events
INSERT INTO ride_events VALUES 
(123456789, 1001, 5002, '2023-07-15 08:30:00.000', 3,
    (37.7749, -122.4194),
    ('123 Market St', 'San Francisco', 'CA', '94103'),
    (5.2, 18, 12.50)
);

INSERT INTO ride_events VALUES 
(123456790, 1002, 5003, '2023-07-15 09:00:00.000', 4,
    (37.7749, -122.4194),
    ('123 Market St', 'San Francisco', 'CA', '94103'),
    (5.2, 18, 12.50)
);

-- Tuple Query Examples
-- 1. Find rides within geographic area
SELECT 
    ride_id,
    driver_id,
    event_time
FROM ride_events
WHERE event_type = 3  
  AND coordinates.1 BETWEEN 37.7 AND 37.8  
  AND coordinates.2 BETWEEN -122.5 AND -122.4;

-- 2. Filter by address component
SELECT 
    count() AS ride_count
FROM ride_events
WHERE address.city = 'San Francisco'
  AND event_type = 4;

-- 3. Calculate average statistics
SELECT 
    avg(stats.1) AS avg_distance,
    avg(stats.2) AS avg_duration,
    avg(stats.3) AS avg_fare
FROM ride_events
WHERE event_type = 4;

-- =============================================
-- 4. Map Types Example - Web Analytics Events
-- =============================================

CREATE TABLE user_events (
    event_id UUID,
    user_id UInt64,
    session_id UUID,
    event_time DateTime64(3),
    event_type LowCardinality(String),
    page_url String,
    event_properties Map(LowCardinality(String), String),
    user_properties Map(LowCardinality(String), String),
    metrics Map(LowCardinality(String), Float64),
    browser_info Map(LowCardinality(String), String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (user_id, event_time, event_id);

-- Insert sample user events
INSERT INTO user_events VALUES 
(generateUUIDv4(), 123456, generateUUIDv4(), now(), 'page_view',
    'https://example.com/products',
    {'referrer': 'https://google.com', 'utm_source': 'email_campaign', 'utm_medium': 'email'},
    {'country': 'US', 'language': 'en', 'segment': 'premium'},
    {'page_load_time': 1.24, 'time_on_page': 45.7, 'scroll_depth': 0.75},
    {'browser': 'Chrome', 'os': 'Windows', 'device': 'desktop', 
     'viewport_width': '1920', 'viewport_height': '1080'}
);

INSERT INTO user_events VALUES 
(generateUUIDv4(), 123457, generateUUIDv4(), now(), 'page_load',
    'https://example.com/products',
    {'referrer': 'https://google.com', 'utm_source': 'email_campaign', 'utm_medium': 'email'},
    {'country': 'US', 'language': 'en', 'segment': 'premium'},
    {'page_load_time': 1.24, 'time_on_page': 45.7, 'scroll_depth': 0.75},
    {'browser': 'Chrome', 'os': 'Windows', 'device': 'desktop', 
     'viewport_width': '1920', 'viewport_height': '1080'}
);

-- Map Query Examples
-- 1. Find events with specific property value
SELECT 
    count() AS total_events
FROM user_events
WHERE event_properties['utm_source'] = 'email_campaign';

-- 2. Get events where certain metric exceeds threshold
SELECT 
    event_id,
    event_time,
    event_type
FROM user_events
WHERE metrics['page_load_time'] > 1.0;

-- 3. Aggregate by map value
SELECT 
    browser_info['browser'] AS browser,
    count() AS event_count
FROM user_events
WHERE event_time >= now() - INTERVAL 1 DAY
GROUP BY browser
ORDER BY event_count DESC;

-- 4. Calculate average metric by user segment
SELECT 
    user_properties['segment'] AS segment,
    avg(metrics['time_on_page']) AS avg_time_on_page
FROM user_events
WHERE event_type = 'page_view'
GROUP BY segment;

-- =============================================
-- 5. Complex Types Combined - IoT Sensor Data
-- =============================================

CREATE TABLE sensor_readings (
    device_id UUID,
    timestamp DateTime64(3),
    device_type LowCardinality(String),
    location_id UInt16,
    coordinates Tuple(Float64, Float64, Float64),
    readings Nested(
        sensor_type LowCardinality(String),
        value Float64,
        unit LowCardinality(String)
    ),
    historical_values Array(Float64),
    historical_timestamps Array(DateTime64(3)),
    configuration Map(LowCardinality(String), String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (device_id, timestamp);

-- Insert sample sensor reading
INSERT INTO sensor_readings VALUES (
    generateUUIDv4(),
    now(),
    'thermometer',
    100,
    (1.0, 2.0, 3.0),
    ['temperature', 'humidity'],
    [22.5, 45.0],
    ['C', '%'],
    [21.5, 22.0, 22.5, 23.0, 22.5],
    [now(), now(), now(), now(), now()],
    map('firmware_version', '1.2.3', 'status', 'active')
);

-- Complex Types Query Examples
-- 1. Basic array operations
SELECT 
    device_id,
    length(historical_values) as num_historical_values,
    historical_values[1] as first_value,
    historical_values[-1] as last_value,
    arrayAvg(historical_values) as avg_value
FROM sensor_readings
WHERE device_id IN (select distinct device_id from sensor_readings limit 5);

-- 2. Working with Nested arrays
SELECT 
    device_id,
    arrayMap(i -> (readings.sensor_type[i], readings.value[i], readings.unit[i]), 
            range(length(readings.sensor_type))) as sensor_readings
FROM sensor_readings
WHERE device_id IN (select distinct device_id from sensor_readings limit 5);

-- 3. Array JOIN to unnest the readings
SELECT 
    device_id,
    sensor_type,
    value,
    unit,
    count() as reading_count
FROM sensor_readings
ARRAY JOIN 
    readings.sensor_type AS sensor_type,
    readings.value AS value,
    readings.unit AS unit
GROUP BY device_id, sensor_type, value, unit
ORDER BY reading_count DESC
LIMIT 5;

-- 4. Array filtering and transformation
SELECT 
    device_id,
    arrayFilter(x -> x > 22, historical_values) as high_values,
    arrayMap(x -> x + 1, historical_values) as incremented_values,
    arrayEnumerate(arrayFilter(x -> x > 22, historical_values)) as high_value_positions
FROM sensor_readings
WHERE device_id IN (select distinct device_id from sensor_readings limit 5);

-- 5. Working with Map type configuration
SELECT 
    device_id,
    configuration['firmware_version']
FROM sensor_readings
WHERE device_id IN (select distinct device_id from sensor_readings limit 5);
