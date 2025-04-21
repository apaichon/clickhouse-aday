# Understanding Duplication Challenges

SELECT
    message_id,
    COUNT(*) as count
FROM messages
GROUP BY message_id
HAVING count > 1
ORDER BY count DESC;

-- Check for duplicate payment attachments
SELECT
    attachment_id,
    COUNT(*) as count
FROM attachments
GROUP BY attachment_id
HAVING count > 1
ORDER BY count DESC;



## Basic Implementation

-- Using ReplacingMergeTree for payment attachments
drop table attachments_dedup

CREATE TABLE attachments_dedup
(
   attachment_id UUID,
    message_id UUID,
    payment_amount Decimal64(2),
    payment_currency LowCardinality(String),
    invoice_date Date,
    payment_status Enum8(
        'pending' = 1, 'paid' = 2, 'canceled' = 3
    ),
    file_path String,
    file_size UInt32,
    uploaded_at DateTime,
    sign Int8,
) ENGINE = ReplacingMergeTree(uploaded_at)
PARTITION BY toYYYYMM(uploaded_at)
ORDER BY (message_id, attachment_id);

-- Fill the table with deduplicated data
INSERT INTO attachments_dedup
SELECT *
FROM attachments

SELECT
    message_id,
    COUNT(*) as count
FROM attachments_dedup FINAL
GROUP BY message_id
HAVING count > 1
ORDER BY count DESC;


insert into attachments_dedup
select * from attachments_dedup 
where attachment_id = 'c9e6be4b-3a7b-45de-8003-b68b027736f7'
ORDER BY attachment_id;



## Force Merge for Deduplication
-- Trigger merges to eliminate duplicates
OPTIMIZE TABLE attachments_dedup FINAL;

-- Verify deduplication
SELECT
    attachment_id,
    COUNT(*) as count
FROM attachments_dedup
GROUP BY attachment_id
HAVING count > 1;
