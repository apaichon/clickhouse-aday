# Basic aggregations
-- Count, sum, average
SELECT
    count() AS total_payments,
    sum(payment_amount) AS total_amount,
    avg(payment_amount) AS average_amount
FROM attachments;

-- Min, max, statistics
SELECT
    min(payment_amount) AS min_amount,
    max(payment_amount) AS max_amount,
    stddevPop(payment_amount) AS std_deviation,
    median(payment_amount) AS median_amount
FROM attachments
WHERE payment_status = 'paid';

-- Group by with multiple aggregates
SELECT
    payment_currency,
    count() AS num_payments,
    sum(payment_amount) AS total,
    avg(payment_amount) AS average,
    min(payment_amount) AS minimum,
    max(payment_amount) AS maximum
FROM attachments
GROUP BY payment_currency;

# Advanced aggregations for Payments Analysis
-- Payment status distribution
SELECT 
    payment_status,
    count() AS count
FROM attachments
GROUP BY payment_status;

-- Monthly payment totals
SELECT 
    toYear(uploaded_at) AS year,
    toMonth(uploaded_at) AS month,
    payment_currency,
    count() AS payment_count,
    sum(payment_amount) AS monthly_total,
    round(avg(payment_amount), 2) AS avg_payment
FROM attachments
GROUP BY year, month, payment_currency
ORDER BY year, month, payment_currency;

-- Payments by user
SELECT 
    m.user_id,
    count() AS payment_count,
    sum(p.payment_amount) AS total_spent,
    avg(p.payment_amount) AS avg_payment
FROM messages m
JOIN payment_attachments p ON m.message_id = p.message_id
GROUP BY m.user_id
ORDER BY total_spent DESC;

-- Payment size categories
SELECT
    multiIf(payment_amount < 100, 'Small',
            payment_amount < 500, 'Medium',
            payment_amount < 1000, 'Large',
            'Very Large') AS payment_category,
    count() AS count
FROM attachments
GROUP BY payment_category;

# Time based aggregation
-- Count, sum, average
SELECT
    count() AS total_payments,
    sum(payment_amount) AS total_amount,
    avg(payment_amount) AS average_amount
FROM attachments;

-- Min, max, statistics
SELECT
    min(payment_amount) AS min_amount,
    max(payment_amount) AS max_amount,
    stddevPop(payment_amount) AS std_deviation,
    median(payment_amount) AS median_amount
FROM attachments
WHERE payment_status = 'paid';

-- Group by with multiple aggregates
SELECT
    payment_currency,
    count() AS num_payments,
    sum(payment_amount) AS total,
    avg(payment_amount) AS average,
    min(payment_amount) AS minimum,
    max(payment_amount) AS maximum
FROM attachments
GROUP BY payment_currency;

# With Rollup, Cube, Having
-- ROLLUP for hierarchical summaries

SELECT 
    payment_currency,
    toYear(uploaded_at) AS year,
    sum(payment_amount) AS total
FROM attachments
GROUP BY payment_currency, year
WITH ROLLUP
ORDER BY 
    IF(payment_currency = '', 1, 0),
    payment_currency,
    IF(year = 0, 1, 0),
    year;

SELECT 
    payment_currency,
    payment_status,
    count() AS count,
    sum(payment_amount) AS total
FROM attachments
GROUP BY payment_currency, payment_status
HAVING count > 40000 
   AND total > 10000
ORDER BY 
    payment_currency, 
    payment_status;