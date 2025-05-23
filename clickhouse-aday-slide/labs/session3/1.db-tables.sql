-- =============================================
-- Chat Payments Database and Tables
-- =============================================

-- 1. Create Database
CREATE DATABASE IF NOT EXISTS chat_payments;

-- 2. Use the Database
USE chat_payments;

-- 3. List all databases and tables (for reference)
SHOW DATABASES;
SHOW TABLES;

-- =============================================
-- 4. Messages Table
-- =============================================
CREATE TABLE messages (
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
    INDEX message_type_idx message_type TYPE bloom_filter GRANULARITY 1
) ENGINE = CollapsingMergeTree(sign)
PRIMARY KEY (message_id)
PARTITION BY toYYYYMM(sent_timestamp)
ORDER BY (message_id, chat_id, sent_timestamp);

-- =============================================
-- 5. Attachments Table
-- =============================================
CREATE TABLE attachments (
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
    INDEX payment_status_idx payment_status TYPE set(0) GRANULARITY 1,
    INDEX currency_idx payment_currency TYPE set(0) GRANULARITY 1
) ENGINE = CollapsingMergeTree(sign)
PRIMARY KEY (attachment_id)
PARTITION BY toYYYYMM(uploaded_at)
ORDER BY (attachment_id, message_id, uploaded_at);

-- =============================================
-- 6. Users Table
-- =============================================
CREATE TABLE users (
    user_id UInt64,
    username String,
    email String,
    company_id UInt16,
    created_at DateTime
) ENGINE = ReplacingMergeTree(created_at)
PRIMARY KEY (user_id)
ORDER BY user_id;

