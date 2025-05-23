# =============================================
# Understanding ClickHouse Query Execution
# =============================================

EXPLAIN
SELECT 
    m.chat_id,
    toDate(p.uploaded_at) AS date,
    sum(p.payment_amount) AS total_amount
FROM chat_payments.messages m
JOIN chat_payments.attachments p ON m.message_id = p.message_id
WHERE m.chat_id IN (100, 101, 102)
  AND p.payment_status = 'paid'
  AND p.uploaded_at >= '2023-04-01'
  AND p.uploaded_at < '2025-05-01'
GROUP BY m.chat_id, date
ORDER BY m.chat_id, date;


# =============================================
# Data Preparation and Table Management
# =============================================

describe table chat_payments.messages;

truncate table chat_payments.messages;
truncate table chat_payments.attachments;

# 1
INSERT INTO chat_payments.messages 
    (message_id, chat_id, user_id, sent_timestamp, message_type, content, sign)
    WITH 
    toDate('2023-04-01') as start_date,
    toDate('2025-05-01') as end_date,
    1_000_000 as num_records,

    messages_data as (
        SELECT 
            generateUUIDv4() as message_id,
            100 + intDiv(number, 5) as chat_id,  
            1000 + intDiv(number, 10) as user_id, 
            start_date + toIntervalDay(rand() % dateDiff('day', start_date, end_date)) + 
                toIntervalSecond(rand() % 86400) as sent_timestamp,
            arrayElement(['text', 'image', 'invoice', 'receipt'], 1 + number % 4) as message_type,
            concat('Message content #', toString(number)) as content,
            1 as sign,  -- Added sign column
            number  
        FROM numbers(num_records)
    )

SELECT 
    message_id,
    chat_id,
    user_id,
    sent_timestamp,
    message_type,
    content,
    1 as sign
FROM messages_data


# 2
-- Insert attachments for a batch of messages
INSERT INTO chat_payments.attachments 
    (attachment_id, message_id, payment_amount, payment_currency, 
     invoice_date, payment_status, file_path, file_size, uploaded_at, sign)
SELECT 
    generateUUIDv4() as attachment_id,
    message_id,
    100 + (rand() % 4900) as payment_amount, 
    arrayElement(['USD', 'EUR', 'GBP'], 1 + rowNumberInBlock() % 3) as payment_currency,
    sent_timestamp::Date as invoice_date,
    arrayElement(['pending', 'paid', 'canceled'], 1 + rowNumberInBlock() % 3) as payment_status,
    concat('/storage/invoices/', toString(rowNumberInBlock()), '.pdf') as file_path,
    50000 + (rand() % 450000) as file_size,
    sent_timestamp + toIntervalHour(1) as uploaded_at,
    1 as sign
FROM chat_payments.messages
WHERE message_type IN ('invoice', 'receipt')
LIMIT 1_000_000 OFFSET 0;  -- First 10 records


select count(*) from chat_payments.messages;
select count(*) from chat_payments.attachments;


# 3


select count(*) from chat_payments.messages 
where sent_timestamp > '2023-04-01' and sent_timestamp < '2025-04-02';

select count(*) from chat_payments.messages 
where content like '%content%';

SELECT count(*)
FROM messages
WHERE toYYYYMM(sent_timestamp) = 202304;


SELECT count(*)
FROM messages
WHERE toString(chat_id) = '100';

-- Good: Keep indexed column as is
SELECT count(*)
FROM messages
WHERE chat_id = 100;

explain json =1
select * from chat_payments.messages 
where   user_id = 1000;

describe table chat_payments.messages;
drop index idx_user_id on chat_payments.messages;

-- select count(distinct user_id) from chat_payments.messages;
ALTER TABLE chat_payments.messages
ADD INDEX idx_user_id user_id TYPE minmax GRANULARITY 8192;

# =============================================
# JOIN Optimization Strategy
# =============================================

## Choose the Right JOIN Type

SELECT m.chat_id, p.payment_amount
FROM messages m
JOIN /* LOCAL */  attachments p 
ON m.message_id = p.message_id
WHERE m.chat_id = 100;


## Filter Before Joining
-- Less efficient: Join then filter
SELECT m.chat_id, p.payment_amount
FROM messages m
JOIN attachments p 
ON m.message_id = p.message_id
WHERE m.chat_id = 197319
  AND p.payment_status = 'paid'
  --LIMIT 100;

-- More efficient: Filter then join
SELECT 
    m.chat_id, 
    p.payment_amount
FROM 
    (SELECT message_id, chat_id 
     FROM messages 
     WHERE chat_id = 197319 ) m
JOIN 
    (SELECT message_id, payment_amount 
     FROM attachments 
     WHERE payment_status = 'paid') p
ON m.message_id = p.message_id
--Limit 100

## Optimize Join Order

-- Put smaller filtered result sets first in joins
SELECT u.username, COUNT(p.attachment_id) as total_attachments
FROM (
    SELECT  * FROM attachments
    WHERE payment_status = 'paid'
    AND uploaded_at > '2023-04-01'
) AS p
JOIN messages m ON p.message_id = m.message_id
JOIN users u ON m.user_id = u.user_id
GROUP BY u.username
ORDER BY total_attachments DESC;

-- 1. Index on attachments table for filtering
ALTER TABLE chat_payments.attachments
    ADD INDEX idx_attachment_status_date (payment_status, uploaded_at)
    TYPE minmax
    GRANULARITY 8192;

-- 2. Index on attachments for JOIN condition
ALTER TABLE chat_payments.attachments
    ADD INDEX idx_attachment_message (message_id)
    TYPE set(100000)
    GRANULARITY 8192;

-- 3. Index on messages for user JOIN
ALTER TABLE chat_payments.messages
    ADD INDEX idx_message_user (user_id)
    TYPE set(100000)
    GRANULARITY 8192;

-- 4. Compound index on messages if frequently querying both
ALTER TABLE chat_payments.messages
    ADD INDEX idx_message_composite (message_id, user_id)
    TYPE set(100000)
    GRANULARITY 8192;

drop index idx_attachment_status_date on chat_payments.attachments;
drop index idx_attachment_message on chat_payments.attachments;
drop index idx_message_user on chat_payments.messages;
drop index idx_message_composite on chat_payments.messages;

## Use USING Instead of ON When Possible

-- Simplified join syntax
SELECT m.chat_id, p.payment_amount
FROM messages m
JOIN attachments p USING (message_id)
WHERE m.chat_id = 100;


# =============================================
# Aggregation and GROUP BY Optimization
# =============================================

## Pre-filter Data
-- Pre-filter before expensive aggregation
SELECT 
    chat_id,
    count() AS message_count
FROM messages
WHERE sent_timestamp >= '2023-04-01'
  AND sent_timestamp < '2023-05-01'
GROUP BY chat_id;


## Use Efficient Aggregation Functions
-- Approximate count distinct (faster)
SELECT 
    uniq(user_id) AS approx_unique_users
FROM messages
WHERE chat_id = 100;

-- Exact count distinct (slower)
EXPLAIN indexes = 1
SELECT 
    count(DISTINCT user_id) AS exact_unique_users
FROM messages
WHERE chat_id = 100

alter table messages add index idx_message_chat_id (chat_id) type set(100000) granularity 8192;

drop index idx_message_chat_id on messages;


## Consider Materialized Views

-- Create a materialized view for common aggregations
CREATE MATERIALIZED VIEW payment_daily_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, payment_currency)
AS
SELECT
    toDate(uploaded_at) AS date,
    payment_currency,
    sum(payment_amount) AS daily_total
FROM attachments
GROUP BY date, payment_currency;


insert into chat_payments.payment_daily_mv
SELECT
    toDate(uploaded_at) AS date,
    payment_currency,
    sum(payment_amount) AS daily_total
FROM attachments
GROUP BY date, payment_currency;

select * from payment_daily_mv;

SELECT
    month
    payment_currency,
    sum(daily_total) AS monthly_total
FROM payment_daily_mv
WHERE toYYYYMM(date) = 202304
GROUP BY toStartOfMonth(date) AS month, payment_currency


## Break Down Complex Queries
-- Step 1: Create a temporary table for filtered data
CREATE TABLE filtered_payments 
ENGINE = Memory
AS
SELECT *
FROM attachments
WHERE payment_status = 'paid'
  AND uploaded_at >= '2023-01-01';


select count(*) from filtered_payments

-- Step 2: Create a temporary table for aggregated data
CREATE TABLE payment_summary 
Engine = Memory
AS
SELECT
    toStartOfMonth(uploaded_at) AS month,
    payment_currency,
    sum(payment_amount) AS total_amount
FROM filtered_payments
GROUP BY month, payment_currency;

-- Step 3: Query the prepared data
SELECT
    formatDateTime(month, '%Y-%m') AS month_str,
    payment_currency,
    total_amount
FROM payment_summary
ORDER BY month, payment_currency;


## Use CTEs for Better Readability and Optimization

-- Clear structure helps the optimizer
WITH filtered_data AS (
    SELECT *
    FROM attachments
    WHERE payment_status = 'paid'
      AND uploaded_at >= '2023-01-01'
      AND payment_amount > 100
),

monthly_stats AS (
    SELECT
        toStartOfMonth(uploaded_at) AS month,
        payment_currency,
        count() AS payment_count,
        sum(payment_amount) AS total_amount,
        avg(payment_amount) AS avg_amount
    FROM filtered_data
    GROUP BY month, payment_currency
)

-- Final analysis with organized data
SELECT
    formatDateTime(month, '%Y-%m') AS month_str,
    payment_currency,
    payment_count,
    total_amount,
    avg_amount,
    total_amount / payment_count AS avg_transaction
FROM monthly_stats
ORDER BY month, payment_currency;


## Analyzing Query Performance

-- Find slow queries
SELECT
    query_id,
    query_duration_ms,
    query,
    read_rows,
    read_bytes,
    memory_usage
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query_duration_ms > 1000
  AND event_time > now() - INTERVAL 1 DAY
  AND query LIKE '%attachments%'
ORDER BY query_duration_ms DESC
LIMIT 10;


## Configuration Settings for Optimization

-- Adjust max memory usage per query (in bytes)
SET max_memory_usage = 1000000000; -- 1 GB

-- Control parallel processing
SET max_threads = 8;

-- Optimize distributed queries
SET optimize_skip_unused_shards = 1;

-- Adjust join execution
SET join_algorithm = 'partial_merge';


# =============================================
# Real-World Optimization Example: Chat Payment Analysis
# =============================================

## Original Slow Query
-- Complex, inefficient query

SELECT 
    u.username,
    m.chat_id,
    p.month,
    count() AS payment_count,
    sum(p.payment_amount) AS total_amount
FROM (
    SELECT 
        message_id,
        payment_amount,
        toStartOfMonth(uploaded_at) AS month
    FROM attachments
    WHERE uploaded_at BETWEEN 
        '2023-01-01 00:00:00' AND '2023-12-31 23:59:59'
) p
JOIN messages m ON p.message_id = m.message_id
JOIN users u ON m.user_id = u.user_id
GROUP BY u.username, m.chat_id, p.month
ORDER BY total_amount DESC;


## Optimized Query

SELECT 
    u.username,
    m.chat_id,
    toStartOfMonth(p.uploaded_at) AS month,
    count() AS payment_count,
    sum(p.payment_amount) AS total_amount
FROM users u
JOIN messages m ON u.user_id = m.user_id
JOIN attachments p ON m.message_id = p.message_id
WHERE p.uploaded_at BETWEEN 
    '2023-01-01 00:00:00' AND '2023-12-31 23:59:59'
GROUP BY u.username, m.chat_id, month
ORDER BY total_amount DESC;

WITH 
filtered_data AS (
    SELECT 
        u.username,
        m.chat_id,
        toStartOfMonth(p.uploaded_at) AS month,
        p.payment_amount
    FROM attachments p
    JOIN messages m ON p.message_id = m.message_id
    JOIN users u ON m.user_id = u.user_id
    WHERE p.uploaded_at BETWEEN 
        '2023-01-01 00:00:00' AND '2023-12-31 23:59:59'
)

SELECT 
    username,
    chat_id,
    month,
    count() AS payment_count,
    sum(payment_amount) AS total_amount
FROM filtered_data
GROUP BY 
    username,
    chat_id,
    month
ORDER BY total_amount DESC;








 




