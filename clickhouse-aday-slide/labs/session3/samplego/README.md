# ClickHouse Batch Insert with Go Routines

This Go application demonstrates parallel batch insertion into ClickHouse using goroutines for improved performance.

## Features

- **Parallel Processing**: Configurable number of goroutines for concurrent batch processing
- **Configurable Delays**: Set delays between batches in milliseconds
- **Performance Monitoring**: Real-time performance metrics and timing information
- **Error Handling**: Robust error handling with logging
- **Connection Management**: Proper ClickHouse connection management with compression

## Configuration

The application can be configured by modifying the `Config` struct in `main()`:

```go
config := Config{
    NumGoroutines: 5,        // Number of parallel goroutines
    TotalBatches:  10,       // Total number of batches to process
    BatchSize:     100_000,  // Records per batch
    DelayMs:       100,      // Delay between batches in milliseconds
}
```

### Configuration Parameters

- **NumGoroutines**: Number of concurrent goroutines (workers) to run in parallel
- **TotalBatches**: Total number of batches to process
- **BatchSize**: Number of records to insert per batch
- **DelayMs**: Delay in milliseconds between batch processing (helps control load)

## Prerequisites

1. **ClickHouse Server**: Ensure ClickHouse is running on `localhost:9000`
2. **Database Setup**: Create the `chat_payments` database and `messages` table
3. **Go Environment**: Go 1.21 or later

## Database Schema

Make sure your ClickHouse database has the following table:

```sql
CREATE DATABASE IF NOT EXISTS chat_payments;

CREATE TABLE IF NOT EXISTS chat_payments.messages (
    message_id UUID,
    chat_id UInt64,
    user_id UInt32,
    sent_timestamp DateTime,
    message_type Enum8('text' = 1, 'image' = 2, 'invoice' = 3, 'receipt' = 4),
    content String,
    has_attachment UInt8,
    sign Int8
) ENGINE = MergeTree()
ORDER BY (chat_id, sent_timestamp);
```

## Installation and Usage

1. **Install Dependencies**:
   ```bash
   go mod tidy
   ```

2. **Run the Application**:
   ```bash
   go run main.go
   ```

## Performance Tuning

### Goroutine Count
- **Low CPU/Memory**: Start with 2-3 goroutines
- **High-end Systems**: Can handle 10+ goroutines
- **Monitor**: Watch CPU and memory usage to find optimal count

### Batch Size
- **Smaller Batches**: Better for memory usage, more overhead
- **Larger Batches**: Better throughput, higher memory usage
- **Recommended**: 50,000 - 200,000 records per batch

### Delay Settings
- **No Delay (0ms)**: Maximum throughput, higher system load
- **Small Delay (50-100ms)**: Balanced performance and system load
- **Larger Delay (500ms+)**: Lower system load, reduced throughput

## Output Example

```
Starting data insertion with 5 goroutines, 10 batches, 100000 records per batch
Goroutine 2: Batch 3 completed in 1.234s (81081.08 records/sec)
Goroutine 1: Batch 1 completed in 1.456s (68681.32 records/sec)
Goroutine 4: Batch 5 completed in 1.123s (89063.27 records/sec)
...
Total insertion time: 3.456s
Total records inserted: 1000000
Average records per second: 289351.85
```

## Error Handling

The application includes comprehensive error handling:
- Connection failures are logged and reported
- Batch processing errors are logged with goroutine and batch information
- Timeout handling for long-running queries
- Graceful shutdown and resource cleanup

## Customization

To modify the data generation logic, edit the SQL query in the `processBatch` function. The current implementation generates:
- Random UUIDs for message IDs
- Random chat and user IDs
- Random timestamps within the last 30 days
- Random message types (text, image, invoice, receipt)
- Sequential message content with batch information 