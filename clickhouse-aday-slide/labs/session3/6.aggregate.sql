-- =============================================
-- Basic Aggregations
-- =============================================

-- 1. Count, sum, average
SELECT
    count() AS total_payments,
    sum(payment_amount) AS total_amount,
    avg(payment_amount) AS average_amount
FROM attachments;

-- 2. Min, max, statistics for paid payments
SELECT
    min(payment_amount) AS min_amount,
    max(payment_amount) AS max_amount,
    stddevPop(payment_amount) AS std_deviation,
    median(payment_amount) AS median_amount
FROM attachments
WHERE payment_status = 'paid';

-- 3. Group by currency with multiple aggregates
SELECT
    payment_currency,
    count() AS num_payments,
    sum(payment_amount) AS total,
    avg(payment_amount) AS average,
    min(payment_amount) AS minimum,
    max(payment_amount) AS maximum
FROM attachments
GROUP BY payment_currency;

-- =============================================
-- Advanced Aggregations for Payments Analysis
-- =============================================

-- 4. Payment status distribution
SELECT 
    payment_status,
    count() AS count
FROM attachments
GROUP BY payment_status;

-- 5. Monthly payment totals
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

-- 6. Payments by user
SELECT 
    m.user_id,
    count() AS payment_count,
    sum(p.payment_amount) AS total_spent,
    avg(p.payment_amount) AS avg_payment
FROM messages m
JOIN attachments p ON m.message_id = p.message_id
GROUP BY m.user_id
ORDER BY total_spent DESC;

-- 7. Payment size categories
SELECT
    multiIf(payment_amount < 100, 'Small',
            payment_amount < 500, 'Medium',
            payment_amount < 1000, 'Large',
            'Very Large') AS payment_category,
    count() AS count
FROM attachments
GROUP BY payment_category;

-- =============================================
-- Time-based Aggregations
-- =============================================

-- 8. Count, sum, average (repeated for time-based context)
SELECT
    count() AS total_payments,
    sum(payment_amount) AS total_amount,
    avg(payment_amount) AS average_amount
FROM attachments;

-- 9. Min, max, statistics for paid payments (repeated)
SELECT
    min(payment_amount) AS min_amount,
    max(payment_amount) AS max_amount,
    stddevPop(payment_amount) AS std_deviation,
    median(payment_amount) AS median_amount
FROM attachments
WHERE payment_status = 'paid';

-- 10. Group by currency with multiple aggregates (repeated)
SELECT
    payment_currency,
    count() AS num_payments,
    sum(payment_amount) AS total,
    avg(payment_amount) AS average,
    min(payment_amount) AS minimum,
    max(payment_amount) AS maximum
FROM attachments
GROUP BY payment_currency;

-- =============================================
-- Hierarchical and Conditional Aggregations
-- =============================================

-- 11. ROLLUP for hierarchical summaries
SELECT 
    payment_currency,
        toYear(uploaded_at) AS year,
        sum(payment_amount) AS total
    FROM attachments
    GROUP BY payment_currency, year
    WITH ROLLUP
    ORDER BY 
        IF(payment_currency = '', 1, 0),
        payment_currency ,
        IF(year = 0, 1, 0),
        year;

       

-- 12. Aggregation with HAVING clause
SELECT 
    payment_currency,
    payment_status,
    count() AS count,
    sum(payment_amount) AS total
FROM attachments
GROUP BY payment_currency, payment_status
 HAVING count > 100 
    AND total > 10000
ORDER BY 
    payment_currency, 
    payment_status;


-- Sample data for attachments table
INSERT INTO attachments VALUES
    (generateUUIDv4(), generateUUIDv4(), 5000, 'USD', '2023-04-01', 'paid', '/storage/inv1.pdf', 100000, '2023-04-01 10:00:00', 1),
    (generateUUIDv4(), generateUUIDv4(), 6000, 'USD', '2023-04-02', 'paid', '/storage/inv2.pdf', 100000, '2023-04-02 10:00:00', 1),
    (generateUUIDv4(), generateUUIDv4(), 7000, 'USD', '2023-04-03', 'pending', '/storage/inv3.pdf', 100000, '2023-04-03 10:00:00', 1),
    (generateUUIDv4(), generateUUIDv4(), 8000, 'EUR', '2023-04-04', 'paid', '/storage/inv4.pdf', 100000, '2023-04-04 10:00:00', 1),
    (generateUUIDv4(), generateUUIDv4(), 9000, 'EUR', '2023-04-05', 'paid', '/storage/inv5.pdf', 100000, '2023-04-05 10:00:00', 1),
    (generateUUIDv4(), generateUUIDv4(), 10000, 'USD', '2023-04-06', 'canceled', '/storage/inv6.pdf', 100000, '2023-04-06 10:00:00', 1);

-- To ensure the HAVING clause is satisfied, insert many rows for a group:
-- For example, insert 10,000 rows of 'USD'/'paid' with payment_amount=2
INSERT INTO attachments
SELECT
    generateUUIDv4(),
    generateUUIDv4(),
    2,                -- payment_amount
    'USD',            -- payment_currency
    '2023-04-10',     -- invoice_date
    'paid',           -- payment_status
    '/storage/bulk.pdf',
    100000,
    '2023-04-10 10:00:00',
    1
FROM numbers(10000);

-- And another group to cross the threshold
INSERT INTO attachments
SELECT
    generateUUIDv4(),
    generateUUIDv4(),
    5,                -- payment_amount
    'EUR',            -- payment_currency
    '2023-04-11',     -- invoice_date
    'paid',           -- payment_status
    '/storage/bulk2.pdf',
    100000,
    '2023-04-11 10:00:00',
    1
FROM numbers(10000);

