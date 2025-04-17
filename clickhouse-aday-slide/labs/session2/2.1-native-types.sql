-- Example table demonstrating various ClickHouse data types
CREATE TABLE data_types_example (
    -- Numeric Types
    id UInt32,                    -- Auto-incrementing ID
    status_code Int16,            -- Response status codes (-32K to +32K)
    temperature Float32,          -- Temperature readings (e.g., 23.45)
    amount Decimal64(2),          -- Money amounts (e.g., 199.99)
    
    -- String Types
    name String,                  -- Variable length strings
    country_code FixedString(2),  -- ISO country codes (fixed 2 chars)
    tags Array(String),           -- Array of strings
    
    -- Enum Types
    status Enum8(
        'active' = 1,
        'inactive' = 0,
        'pending' = 2
    ),
    user_type Enum16(
        'admin' = 1,
        'user' = 2,
        'guest' = 3
    ),
    
    -- DateTime Types
    created_at DateTime,          -- Creation timestamp
    updated_at DateTime64(3),     -- Update timestamp with milliseconds
    event_date Date,              -- Just the date
    
    -- IP Address Types
    user_ip IPv4,                -- IPv4 address
    server_ip IPv6,              -- IPv6 address
    
    -- Geo Types
    location Point,              -- Latitude and longitude
    service_area Polygon,        -- Service coverage area
    
    -- Low Cardinality for better performance
    region LowCardinality(String),
    device_type LowCardinality(String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(created_at)
ORDER BY (id, created_at);

INSERT INTO data_types_example VALUES 
(
    1,                          -- id
    200,                        -- status_code
    23.45,                      -- temperature
    199.99,                     -- amount
    'Alice',                    -- name
    'US',                       -- country_code
    ['tag1', 'tag2'],           -- tags
    'active',                   -- status (Enum8)
    'admin',                    -- user_type (Enum16)
    now(),                      -- created_at
    now64(3),                   -- updated_at
    toDate('2025-04-15'),       -- event_date
    toIPv4('192.168.1.10'),     -- user_ip
    toIPv6('2001:db8::1'),      -- server_ip
    (37.7749, -122.4194),       -- location (Point as tuple)
    [                           -- service_area (Polygon as array of rings)
        [                       -- outer ring
            (37.7749, -122.4194),
            (37.7750, -122.4195),
            (37.7751, -122.4196),
            (37.7749, -122.4194)  -- close the polygon by repeating first point
        ]
    ],
    'North America',            -- region (LowCardinality)
    'mobile'                    -- device_type (LowCardinality)
);

select * from data_types_example;


# Type conversion

SELECT toUInt8(10), toString(42), toFloat64('3.14');

-- CAST operator for explicit conversion:
SELECT CAST('2023-01-01' AS Date), CAST(3.14 AS Decimal(10,2));

-- Conversion between numeric types:
SELECT CAST(3 AS Float64) / 4 AS ratio;

-- String to Date/DateTime conversion:
SELECT toDate('2023-01-01'), toDateTime('2023-01-01 12:30:00');

-- Type conversion in table definition
CREATE TABLE conversion_example (
    string_date String,
    parsed_date Date MATERIALIZED toDate(string_date)
) ENGINE = MergeTree()
ORDER BY parsed_date;

INSERT INTO conversion_example VALUES ('2023-01-01');

INSERT INTO conversion_example VALUES ('2023-01-01 12:30:00');



