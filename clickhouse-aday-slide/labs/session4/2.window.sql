-- Basic window function example


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
        ORDER BY uploaded_at  -- Added ORDER BY clause
    ) AS row_num,
        
    avg(payment_amount) OVER (
        PARTITION BY payment_currency
    ) AS currency_avg,
        
    avg(payment_amount) OVER () AS overall_avg
    
FROM chat_payments.attachments
WHERE payment_status = 'paid'
and date(uploaded_at) = '2024-04-15'
ORDER BY payment_currency, uploaded_at;

## Rank Window Functions

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
WHERE payment_status = 'paid' and  date(uploaded_at) = '2024-04-15';

## Row Position Functions

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
  AND date(uploaded_at) = '2024-04-15'
ORDER BY payment_currency, uploaded_at;


## Running Aggregates

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
WHERE payment_status = 'paid' AND date(uploaded_at) = '2023-01-01' 
ORDER BY payment_currency, date;


## Moving Averages
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
  AND toDate(uploaded_at) <= '2023-01-07'
ORDER BY payment_currency, date;



## Payment Trend Analysis
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
  AND toDate(uploaded_at) <= '2023-01-07'
GROUP BY 
    date,
    p.payment_currency
ORDER BY p.payment_currency, date;




-- First, insert users
INSERT INTO chat_payments.users 
(user_id, username, email, company_id, created_at) 
VALUES
    (1001, 'john.doe', 'john@example.com', 101, now()),
    (1002, 'jane.smith', 'jane@example.com', 102, now());

-- Insert messages
INSERT INTO chat_payments.messages 
(message_id, chat_id, user_id, sent_timestamp, message_type, content) 
VALUES
    ('msg-001', 201, 1001, '2023-01-01 10:00:00', 'invoice', 'Invoice 1'),
    ('msg-002', 201, 1001, '2023-01-03 10:00:00', 'invoice', 'Invoice 2'),
    ('msg-003', 202, 1002, '2023-01-02 10:00:00', 'invoice', 'Invoice 3'),
    ('msg-004', 202, 1002, '2023-01-04 10:00:00', 'invoice', 'Invoice 4');

-- Insert attachments
INSERT INTO chat_payments.attachments 
(attachment_id, message_id, payment_amount, payment_currency, payment_status, uploaded_at) 
VALUES
    (generateUUIDv4(), 'msg-001', 1500.00, 'USD', 'paid', '2023-01-01 10:30:00'),
    (generateUUIDv4(), 'msg-002', 2500.00, 'USD', 'paid', '2023-01-03 15:00:00'),
    (generateUUIDv4(), 'msg-003', 1800.00, 'USD', 'paid', '2023-01-02 09:00:00'),
    (generateUUIDv4(), 'msg-004', 2200.00, 'USD', 'paid', '2023-01-04 14:00:00');


 ## User Payment Behavior
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


