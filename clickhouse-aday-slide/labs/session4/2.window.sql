-- =============================================
-- Basic Window Function Example
-- =============================================

SELECT 
    payment_currency,
    uploaded_at,
    payment_amount,
    sum(payment_amount) OVER (
        PARTITION BY payment_currency 
        ORDER BY uploaded_at
    ) AS running_total,
    row_number() OVER (
        PARTITION BY payment_currency
        ORDER BY uploaded_at
    ) AS row_num,
    avg(payment_amount) OVER (
        PARTITION BY payment_currency
    ) AS currency_avg,
    avg(payment_amount) OVER () AS overall_avg
FROM chat_payments.attachments
WHERE payment_status = 'paid'
  AND date(uploaded_at) = '2024-04-15'
ORDER BY payment_currency, uploaded_at;

-- =============================================
-- Rank Window Functions
-- =============================================

SELECT 
    payment_currency,
    payment_amount,
    -- Regular rank (with gaps)
    rank() OVER (
        PARTITION BY payment_currency 
        ORDER BY payment_amount DESC
    ) AS payment_rank,
    -- Dense rank (no gaps)
    dense_rank() OVER (
        PARTITION BY payment_currency 
        ORDER BY payment_amount DESC
    ) AS dense_payment_rank,
    -- Percentile rank
    percent_rank() OVER (
        PARTITION BY payment_currency 
        ORDER BY payment_amount
    ) AS percentile
FROM attachments
WHERE payment_status = 'paid' 
  AND date(uploaded_at) = '2024-04-15';

-- =============================================
-- Row Position Functions
-- =============================================

SELECT 
    payment_currency,
    uploaded_at,
    -- Row number
    row_number() OVER (
        PARTITION BY payment_currency 
        ORDER BY uploaded_at
    ) AS row_num,
    -- Previous row's value (instead of lag)
    anyLast(payment_amount) OVER (
        PARTITION BY payment_currency 
        ORDER BY uploaded_at
        ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
    ) AS previous_payment,
    -- Next row's value (instead of lead)
    any(payment_amount) OVER (
        PARTITION BY payment_currency 
        ORDER BY uploaded_at
        ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING
    ) AS next_payment
FROM attachments
WHERE payment_status = 'paid' 
  AND date(uploaded_at) BETWEEN '2024-04-15' AND '2024-04-20'
ORDER BY payment_currency, uploaded_at;

-- =============================================
-- Running Aggregates
-- =============================================

SELECT 
    toDate(uploaded_at) AS date,
    payment_currency,
    payment_amount,
    -- Running sum (cumulative total)
    sum(payment_amount) OVER (
        PARTITION BY payment_currency 
        ORDER BY toDate(uploaded_at)
    ) AS running_total,
    -- Daily total
    sum(payment_amount) OVER (
        PARTITION BY payment_currency, toDate(uploaded_at)
    ) AS daily_total
FROM attachments
WHERE payment_status = 'paid' 
  AND date(uploaded_at) BETWEEN '2023-01-01' AND '2023-08-07'
ORDER BY payment_currency, date;

-- =============================================
-- Moving Averages
-- =============================================

SELECT 
    toDate(uploaded_at) AS date,
    payment_currency,
    payment_amount,
    -- 7-day moving average using ROWS
    avg(payment_amount) OVER (
        PARTITION BY payment_currency 
        ORDER BY toDate(uploaded_at)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7day,
    -- Alternative moving average also using ROWS
    avg(payment_amount) OVER (
        PARTITION BY payment_currency 
        ORDER BY toDate(uploaded_at)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7day_alt
FROM attachments
WHERE payment_status = 'paid' 
  AND toDate(uploaded_at) >= '2023-01-01'
  AND toDate(uploaded_at) <= '2023-08-07'
ORDER BY payment_currency, date;

-- =============================================
-- Payment Trend Analysis
-- =============================================

SELECT 
    toDate(p.uploaded_at) AS date,
    p.payment_currency,
    count() AS payment_count,
    sum(p.payment_amount) AS daily_total,
    -- 7-day moving average of daily totals
    avg(daily_total) OVER (
        PARTITION BY p.payment_currency 
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7day,
    -- Month-to-date running total
    sum(daily_total) OVER (
        PARTITION BY p.payment_currency, toStartOfMonth(date)
        ORDER BY date
    ) AS month_to_date_total
FROM attachments p
WHERE payment_status = 'paid' 
  AND toDate(uploaded_at) >= '2023-01-01'
  AND toDate(uploaded_at) <= '2023-08-07'
GROUP BY 
    date,
    p.payment_currency
ORDER BY p.payment_currency, date;

-- =============================================
-- Sample Data for Window Functions
-- =============================================

-- Insert users
INSERT INTO chat_payments.users 
(user_id, username, email, company_id, created_at) 
VALUES
    (1001, 'john.doe', 'john@example.com', 101, now()),
    (1002, 'jane.smith', 'jane@example.com', 102, now());

-- Insert messages

INSERT INTO chat_payments.messages 
(
    message_id,
    chat_id,
    user_id,
    sent_timestamp,
    message_type,
    content,
    has_attachment,
    sign
)
VALUES
    ('11111111-1111-1111-1111-111111111111', 200, 1001, '2024-06-01 10:00:00', 'text', 'Hello, this is a sample message 1.', 1, 1),
    ('22222222-2222-2222-2222-222222222222', 200, 1001, '2024-06-02 10:00:00', 'text', 'Hello, this is a sample message 2.', 1, 1),
    ('33333333-3333-3333-3333-333333333333', 200, 1001, '2024-06-03 10:00:00', 'text', 'Hello, this is a sample message 3.', 1, 1),
    ('44444444-4444-4444-4444-444444444444', 200, 1001, '2024-06-04 10:00:00', 'text', 'Hello, this is a sample message 4.', 1, 1),
    ('55555555-5555-5555-5555-555555555555', 200, 1001, '2024-06-05 10:00:00', 'text', 'Hello, this is a sample message 5.', 1, 1);

-- Insert attachments
INSERT INTO chat_payments.attachments (
    attachment_id, message_id, payment_amount, payment_currency, invoice_date,
    payment_status, file_path, file_size, uploaded_at, sign
) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1250.00, 'USD', '2024-06-01', 'pending', '/storage/invoices/inv_12345.pdf', 128000, '2024-06-02 14:30:00', 1),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 750.50, 'EUR', '2024-06-05', 'paid', '/storage/receipts/rec_75421.pdf', 98500, '2024-06-06 09:15:00', 1);

-- =============================================
-- User Payment Behavior Analysis
-- =============================================

SELECT 
    u.user_id,
    u.username,
    p.payment_amount,
    p.uploaded_at,
    -- Difference from user's average
    p.payment_amount - avg(p.payment_amount) OVER (
        PARTITION BY u.user_id
    ) AS diff_from_user_avg,
    -- Rank of payments per user
    rank() OVER (
        PARTITION BY u.user_id 
        ORDER BY p.payment_amount DESC
    ) AS payment_rank_for_user,
    -- Days since previous payment using anyLast
    dateDiff('day',
        anyLast(p.uploaded_at) OVER (
            PARTITION BY u.user_id 
            ORDER BY p.uploaded_at
            ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
        ),
        p.uploaded_at
    ) AS days_since_previous
FROM attachments p
JOIN messages m ON p.message_id = m.message_id
JOIN users u ON m.user_id = u.user_id
WHERE p.payment_status = 'paid' 
  AND toDate(p.uploaded_at) >= '2023-01-01'
ORDER BY u.user_id, p.uploaded_at;


