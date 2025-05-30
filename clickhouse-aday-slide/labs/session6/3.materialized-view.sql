-- =============================================
-- Materialized View Basics
-- =============================================

-- Message counts per chat per day (top 100 chats)
CREATE MATERIALIZED VIEW message_counts_top100_mv
ENGINE = SummingMergeTree()
ORDER BY (chat_id, date)
AS
SELECT
    chat_id,
    toDate(sent_timestamp) AS date,
    count() AS message_count
FROM messages
WHERE chat_id BETWEEN 0 AND 100
GROUP BY chat_id, date;

-- Example: Insert sample messages
INSERT INTO messages 
(message_id, chat_id, sent_timestamp, content, user_id, sign)
VALUES
    (generateUUIDv4(), 1, now(), 'Hello, world!', 1, 1),
    (generateUUIDv4(), 1, now(), 'Hello, world!', 1, 1),
    (generateUUIDv4(), 1, now(), 'Hello, world!', 1, 1),
    (generateUUIDv4(), 1, now(), 'Hello, world!', 1, 1),
    (generateUUIDv4(), 1, now(), 'Hello, world!', 1, 1);

-- Query the materialized view
SELECT * FROM message_counts_top100_mv
ORDER BY chat_id, date DESC;

-- =============================================
-- Payment Statistics Materialized View
-- =============================================

CREATE MATERIALIZED VIEW payment_stats_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (payment_currency, payment_status, date)
AS
SELECT
    toDate(uploaded_at) AS date,
    payment_currency,
    payment_status,
    count() AS payment_count,
    sum(payment_amount) AS total_amount
FROM attachments
GROUP BY date, payment_currency, payment_status;

-- Query the payment stats view
SELECT * FROM payment_stats_mv
ORDER BY date DESC;

-- =============================================
-- Specialized Materialized View Engines
-- =============================================

-- SummingMergeTree: Daily payment stats with unique counts
CREATE MATERIALIZED VIEW daily_payments_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, payment_currency)
AS
SELECT
    toDate(uploaded_at) AS date,
    payment_currency,
    count() AS payment_count,
    sum(payment_amount) AS total_amount,
    min(payment_amount) AS min_amount,
    max(payment_amount) AS max_amount,
    uniq(message_id) AS unique_messages,
    uniqExact(user_id) AS unique_users
FROM attachments p
JOIN messages m ON p.message_id = m.message_id
GROUP BY date, payment_currency;

-- AggregatingMergeTree: Flexible aggregation with state functions
CREATE MATERIALIZED VIEW payment_stats_aggr_mv
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, payment_currency)
AS
SELECT
    toDate(uploaded_at) AS date,
    payment_currency,
    count() AS payment_count,
    sumState(payment_amount) AS sum_amount,
    avgState(payment_amount) AS avg_amount,
    quantilesState(0.5, 0.9, 0.95)(payment_amount) AS amount_quantiles
FROM attachments
GROUP BY date, payment_currency;


-- Query the aggregated view
SELECT
    date,
    payment_currency,
    sum(payment_count) AS payment_count,
    sumMerge(sum_amount) AS total_amount,
    avgMerge(avg_amount) AS average_amount,
    quantilesMerge(0.5, 0.9, 0.95)(amount_quantiles) AS quantiles
FROM payment_stats_aggr_mv
GROUP BY date, payment_currency
ORDER BY date, payment_currency;

-- =============================================
-- Materialized View Maintenance
-- =============================================

-- List all materialized views
SELECT name, engine FROM system.tables
WHERE engine LIKE '%Materialized%';

-- Details about materialized views
SELECT * FROM system.tables
WHERE database = currentDatabase()
  AND engine LIKE '%Materialized%';

-- Drop a materialized view
DROP TABLE payment_stats_mv;

-- Generate DROP Statements for All Materialized Views
SELECT
    'DROP TABLE ' || name || ';' AS drop_statement
FROM system.tables
WHERE database = currentDatabase()
  AND engine LIKE '%Materialized%';


SELECT
    toDate(uploaded_at) AS date,
    payment_currency,
    count() AS payment_count,
    sumState(payment_amount) AS sum_amount,
    avgState(payment_amount) AS avg_amount,
    quantilesState(0.5, 0.9, 0.95)(payment_amount) AS amount_quantiles
FROM attachments
GROUP BY date, payment_currency;