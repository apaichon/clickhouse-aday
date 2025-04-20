# CTE Basics

-- Basic WITH clause example
WITH avg_by_currency AS (
    SELECT payment_currency, avg(payment_amount) AS avg_amount
    FROM attachments
    GROUP BY payment_currency
)

SELECT 
    p.payment_currency,
    p.payment_amount,
    a.avg_amount,
    p.payment_amount - a.avg_amount AS diff_from_avg
FROM attachments p
JOIN avg_by_currency a ON p.payment_currency = a.payment_currency
WHERE p.payment_status = 'paid'

-- Filter results after joining with CTE
HAVING p.payment_amount > a.avg_amount * 1.5
ORDER BY p.payment_currency, diff_from_avg DESC;

## Multiple CTEs

-- Calculate daily totals
WITH daily_totals AS (
    SELECT toDate(uploaded_at) AS date, sum(payment_amount) AS total
    FROM attachments
    GROUP BY date
),

-- Calculate daily active users
daily_users AS (
    SELECT toDate(sent_timestamp) AS date, count(DISTINCT user_id) AS active_users
    FROM messages
    WHERE has_attachment = 1
    GROUP BY date
)

-- Combine the CTEs to get metrics
SELECT 
    d.date,
    d.total AS daily_payment_total,
    u.active_users,
    d.total / u.active_users AS avg_payment_per_user
FROM daily_totals d
JOIN daily_users u ON d.date = u.date
WHERE d.date >= '2023-04-01'
  AND d.date <= '2025-04-30'
ORDER BY d.date;

## Chained CTEs
-- Step 1: Get payment data by user
WITH user_payments AS (
    SELECT m.user_id, p.payment_amount, p.payment_currency
    FROM messages m
    JOIN attachments p ON m.message_id = p.message_id
    WHERE p.payment_status = 'paid'
),

-- Step 2: Aggregate by user
user_totals AS (
    SELECT 
        user_id,
        sum(payment_amount) AS total_paid,
        count() AS payment_count,
        avg(payment_amount) AS avg_payment
    FROM user_payments
    GROUP BY user_id
)

-- Step 3: Categorize users
SELECT 
    u.username,
    t.total_paid,
    t.payment_count,
    multiIf(t.total_paid < 1000, 'Low',
           t.total_paid < 5000, 'Medium',
           'High') AS spending_category
FROM user_totals t
JOIN users u ON t.user_id = u.user_id
ORDER BY t.total_paid DESC;

## Monthly Payment Trends
WITH monthly_by_currency AS (
    SELECT 
        toStartOfMonth(uploaded_at) AS month,
        payment_currency,
        count() AS payment_count,
        sum(payment_amount) AS monthly_total,
        avg(payment_amount) AS avg_payment
    FROM attachments
    WHERE payment_status = 'paid'
    GROUP BY month, payment_currency
),

-- Step 2: Calculate previous month metrics using anyLast
monthly_with_previous AS (
    SELECT 
        m1.month,
        m1.payment_currency,
        m1.payment_count,
        m1.monthly_total,
        m1.avg_payment,
        anyLast(m1.monthly_total) OVER (
            PARTITION BY m1.payment_currency 
            ORDER BY m1.month
            ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
        ) AS prev_month_total,
        anyLast(m1.payment_count) OVER (
            PARTITION BY m1.payment_currency 
            ORDER BY m1.month
            ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
        ) AS prev_month_count
    FROM monthly_by_currency m1
    ORDER BY m1.month, m1.payment_currency
)

-- Step 3: Calculate growth rates with null checks
SELECT 
    month,
    payment_currency,
    payment_count,
    monthly_total,
    prev_month_total,
    CASE 
        WHEN prev_month_total > 0 
        THEN round((monthly_total - prev_month_total) / prev_month_total * 100, 1)
        ELSE NULL
    END AS month_over_month_growth,
    CASE 
        WHEN prev_month_count > 0 
        THEN round((payment_count - prev_month_count) / prev_month_count * 100, 1)
        ELSE NULL
    END AS count_growth
FROM monthly_with_previous
WHERE prev_month_total IS NOT NULL
ORDER BY month DESC, payment_currency;


## User Cohort Analysis
-- Step 1: Get user's first payment month
WITH user_first_payment AS (
    SELECT 
        m.user_id,
        min(toStartOfMonth(p.uploaded_at)) AS first_payment_month
    FROM messages m
    JOIN attachments p ON m.message_id = p.message_id
    WHERE p.payment_status = 'paid'
    GROUP BY m.user_id
),

-- Step 2: Get all payments with cohort info
user_payments_by_month AS (
    SELECT 
        ufp.first_payment_month AS cohort,
        toStartOfMonth(p.uploaded_at) AS payment_month,
        count(DISTINCT m.user_id) AS user_count,
        sum(p.payment_amount) AS total_amount
    FROM attachments p
    JOIN messages m ON p.message_id = m.message_id
    JOIN user_first_payment ufp ON m.user_id = ufp.user_id
    WHERE p.payment_status = 'paid'
    GROUP BY cohort, payment_month
)

-- Step 3: Calculate month number from cohort start
SELECT 
    cohort,
    payment_month,
    dateDiff('month', cohort, payment_month) AS month_number,
    user_count,
    total_amount,
    total_amount / user_count AS avg_payment_per_user
FROM user_payments_by_month
ORDER BY cohort, payment_month;