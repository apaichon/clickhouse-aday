CREATE TABLE chat_payments.messages_projection (
    message_id UUID,
    chat_id UInt64,
    user_id UInt32,
    sent_timestamp DateTime,
    message_type Enum8(
        'text' = 1, 'image' = 2, 
        'invoice' = 3, 'receipt' = 4
    ),
    content String,
    has_attachment UInt8,
    sign Int8,
    PROJECTION user_message_counts_proj (
        SELECT
            user_id,
            count() AS message_count
        GROUP BY user_id
    ),

    INDEX message_type_idx message_type TYPE bloom_filter GRANULARITY 1
) ENGINE = CollapsingMergeTree(sign)
Primary Key (message_id)
PARTITION BY toYYYYMM(sent_timestamp)
ORDER BY (message_id, chat_id, sent_timestamp)
SETTINGS deduplicate_merge_projection_mode = 'drop';


INSERT INTO chat_payments.messages_projection 
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


SELECT
    user_id,
    count() AS message_count
FROM chat_payments.messages_projection
GROUP BY user_id

select * from chat_payments.messages_projection 
where user_id = 35096

SELECT query, projections FROM system.query_log 



-- Then add the projection
SET deduplicate_merge_projection_mode = 'drop';
