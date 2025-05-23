package main

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
)

type Config struct {
	NumGoroutines int
	TotalBatches  int
	BatchSize     int
	DelayMs       int
}

func main() {
	config := Config{
		NumGoroutines: 10,       // Number of parallel goroutines
		TotalBatches:  1_000,      // Total number of batches to process
		BatchSize:     1_000_000, // Records per batch
		DelayMs:       100,     // Delay between batches in milliseconds
	}

	if err := insertData(config); err != nil {
		log.Fatal(err)
	}
}

func insertData(config Config) error {
	// Create ClickHouse connection
	conn, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{"localhost:9000"},
		Auth: clickhouse.Auth{
			Database: "chat_payments",
			Username: "admin",
			Password: "admin",
		},
		Settings: clickhouse.Settings{
			"max_execution_time": 60,
		},
		Compression: &clickhouse.Compression{
			Method: clickhouse.CompressionLZ4,
		},
	})
	if err != nil {
		return fmt.Errorf("failed to connect to ClickHouse: %w", err)
	}
	defer conn.Close()

	// Test connection
	if err := conn.Ping(context.Background()); err != nil {
		return fmt.Errorf("failed to ping ClickHouse: %w", err)
	}

	fmt.Printf("Starting data insertion with %d goroutines, %d batches, %d records per batch\n",
		config.NumGoroutines, config.TotalBatches, config.BatchSize)

	startTime := time.Now()

	// Create a channel to distribute work
	batchChan := make(chan int, config.TotalBatches)
	var wg sync.WaitGroup

	// Fill the channel with batch numbers
	for i := 0; i < config.TotalBatches; i++ {
		batchChan <- i
	}
	close(batchChan)

	// Start goroutines
	for i := 0; i < config.NumGoroutines; i++ {
		wg.Add(1)
		go func(goroutineID int) {
			defer wg.Done()
			worker(goroutineID, batchChan, conn, config)
		}(i)
	}

	// Wait for all goroutines to complete
	wg.Wait()

	// Final flush
	if err := conn.Exec(context.Background(), "SYSTEM FLUSH LOGS"); err != nil {
		log.Printf("Warning: Failed to flush logs: %v", err)
	}

	totalTime := time.Since(startTime)
	fmt.Printf("Total insertion time: %v\n", totalTime)
	fmt.Printf("Total records inserted: %d\n", config.TotalBatches*config.BatchSize)
	fmt.Printf("Average records per second: %.2f\n", float64(config.TotalBatches*config.BatchSize)/totalTime.Seconds())

	return nil
}

func worker(goroutineID int, batchChan <-chan int, conn driver.Conn, config Config) {
	for batchNum := range batchChan {
		if err := processBatch(goroutineID, batchNum, conn, config); err != nil {
			log.Printf("Goroutine %d: Error processing batch %d: %v", goroutineID, batchNum, err)
			// Retry logic could be added here
			continue
		}

		// Add delay between batches
		if config.DelayMs > 0 {
			time.Sleep(time.Duration(config.DelayMs) * time.Millisecond)
		}
	}
}

func processBatch(goroutineID, batchNum int, conn driver.Conn, config Config) error {
	batchStart := time.Now()

	query := fmt.Sprintf(`
		INSERT INTO messages
		(message_id, chat_id, user_id, sent_timestamp, message_type, content, has_attachment, sign)
		SELECT
			generateUUIDv4() as message_id,
			toUInt64(rand() %% 1000) as chat_id,
			toUInt32(rand() %% 10000) as user_id,
			now() - toIntervalDay(rand() %% 30) as sent_timestamp,
			CAST(
				multiIf(
					rand() %% 4 = 0, 'text',
					rand() %% 4 = 1, 'image',
					rand() %% 4 = 2, 'invoice',
					'receipt'
				) AS Enum8('text' = 1, 'image' = 2, 'invoice' = 3, 'receipt' = 4)
			) as message_type,
			'Batch generated message ' || toString(number) as content,
			rand() %% 2 as has_attachment,
			1 as sign
		FROM numbers(%d)
	`, config.BatchSize)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := conn.Exec(ctx, query); err != nil {
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	// Flush logs for this batch
	if err := conn.Exec(ctx, "SYSTEM FLUSH LOGS"); err != nil {
		log.Printf("Warning: Failed to flush logs for batch %d: %v", batchNum, err)
	}

	batchDuration := time.Since(batchStart)
	fmt.Printf("Goroutine %d: Batch %d completed in %v (%.2f records/sec)\n",
		goroutineID, batchNum+1, batchDuration,
		float64(config.BatchSize)/batchDuration.Seconds())

	return nil
}
