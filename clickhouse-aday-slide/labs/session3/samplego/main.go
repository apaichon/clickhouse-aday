package main

import (
	"context"
	"fmt"
	"log"
	"math"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
)

type Config struct {
	NumGoroutines int
	BatchSize     int
	DelayMs       int

	// Data generation config
	NumPolicies     int64   // e.g., 30_000_000
	ClaimPercentage float64 // e.g., 0.30 (30% of policies)
	DocsPerPolicy   int     // e.g., 5 (5 documents per policy)

	// Customer and Agent ranges (must exist in DB)
	MinCustomerID int64 // e.g., 10000
	MaxCustomerID int64 // e.g., 100000
	MinAgentID    int64 // e.g., 600
	MaxAgentID    int64 // e.g., 649
}

type DataType int

const (
	DataTypePolicies DataType = iota
	DataTypeClaims
	DataTypeDocuments
)

func main() {
	config := Config{
		NumGoroutines: 4,      // Reduced from 10 to 4
		BatchSize:     10_000, // Reduced from 100_000 to 10_000
		DelayMs:       100,    // Reduced delay

		// Data generation config
		NumPolicies:     30_000_000,
		ClaimPercentage: 0.30,
		DocsPerPolicy:   5,

		// Ensure these ranges exist in your database
		MinCustomerID: 1000,
		MaxCustomerID: 2000998,
		MinAgentID:    5000,
		MaxAgentID:    54999,
	}

	if err := generateAllData(config); err != nil {
		log.Fatal(err)
	}
}

func generateAllData(config Config) error {
	conn, err := createConnection()
	if err != nil {
		return err
	}
	defer conn.Close()

	// Validate that customers and agents exist
	if err := validateDependencies(conn, config); err != nil {
		return fmt.Errorf("dependency validation failed: %w", err)
	}

	fmt.Printf("=== Data Generation Plan ===\n")
	fmt.Printf("Policies: %d (batch size: %d)\n", config.NumPolicies, config.BatchSize)

	numClaims := int64(float64(config.NumPolicies) * config.ClaimPercentage)
	fmt.Printf("Claims: %d (%.1f%% of policies)\n", numClaims, config.ClaimPercentage*100)

	numDocuments := config.NumPolicies * int64(config.DocsPerPolicy)
	fmt.Printf("Documents: %d (%dx policies)\n", numDocuments, config.DocsPerPolicy)

	totalBatches := calculateTotalBatches(config.NumPolicies, numClaims, numDocuments, int64(config.BatchSize))
	fmt.Printf("Total batches: %d\n", totalBatches)
	fmt.Printf("Estimated time: %.1f minutes (with %dms delay)\n",
		float64(totalBatches*int64(config.DelayMs))/60000, config.DelayMs)
	fmt.Println("==============================")

	// Generate data in sequence: Policies -> Claims -> Documents
	/*fmt.Println("\n🏢 Generating Policies...")
	if err := generateData(conn, config, DataTypePolicies, config.NumPolicies); err != nil {
		return fmt.Errorf("failed to generate policies: %w", err)
	}*/

	/*fmt.Println("\n📋 Generating Claims...")
	if err := generateData(conn, config, DataTypeClaims, numClaims); err != nil {
		return fmt.Errorf("failed to generate claims: %w", err)
	}
	*/

	fmt.Println("\n📄 Generating Documents...")
	if err := generateData(conn, config, DataTypeDocuments, numDocuments); err != nil {
		return fmt.Errorf("failed to generate documents: %w", err)
	}

	fmt.Println("\n✅ All data generation completed!")
	return nil
}

func createConnection() (driver.Conn, error) {
	conn, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{"localhost:9000"},
		Auth: clickhouse.Auth{
			Database: "life_insurance", // Changed to match your schema
			Username: "admin",
			Password: "P@ssw0rd",
		},
		Settings: clickhouse.Settings{
			"max_execution_time":                 3600,            // 1 hour
			"max_memory_usage":                   "2000000000",    // Reduced to 2GB
			"max_bytes_before_external_group_by": "1000000000",    // Reduced to 1GB
			"max_insert_block_size":              "100000",        // Reduced block size
			"min_insert_block_size_rows":         "10000",         // Reduced min rows
			"max_insert_threads":                 "2",             // Reduced threads
			"async_insert":                       "0",             // Disabled
			"send_timeout":                       "300",           // 5 minutes
			"receive_timeout":                    "300",           // 5 minutes
			"join_algorithm":                     "partial_merge", // Memory efficient join
		},
		Compression: &clickhouse.Compression{
			Method: clickhouse.CompressionLZ4,
		},
		MaxOpenConns:    10, // Limit concurrent connections
		MaxIdleConns:    3,
		ConnMaxLifetime: time.Hour,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to ClickHouse: %w", err)
	}

	if err := conn.Ping(context.Background()); err != nil {
		return nil, fmt.Errorf("failed to ping ClickHouse: %w", err)
	}

	return conn, nil
}

func validateDependencies(conn driver.Conn, config Config) error {
	ctx := context.Background()

	// Check customer range
	var customerCount uint64
	err := conn.QueryRow(ctx,
		"SELECT count() FROM customers WHERE customer_id BETWEEN ? AND ?",
		config.MinCustomerID, config.MaxCustomerID).Scan(&customerCount)
	if err != nil {
		return fmt.Errorf("failed to check customers: %w", err)
	}
	if customerCount == 0 {
		return fmt.Errorf("no customers found in range %d-%d", config.MinCustomerID, config.MaxCustomerID)
	}

	// Check agent range
	var agentCount uint64
	err = conn.QueryRow(ctx,
		"SELECT count() FROM agents WHERE agent_id BETWEEN ? AND ?",
		config.MinAgentID, config.MaxAgentID).Scan(&agentCount)
	if err != nil {
		return fmt.Errorf("failed to check agents: %w", err)
	}
	if agentCount == 0 {
		return fmt.Errorf("no agents found in range %d-%d", config.MinAgentID, config.MaxAgentID)
	}

	fmt.Printf("✓ Found %d customers and %d agents in specified ranges\n", customerCount, agentCount)
	return nil
}

func generateData(conn driver.Conn, config Config, dataType DataType, totalRecords int64) error {
	totalBatches := int(math.Ceil(float64(totalRecords) / float64(config.BatchSize)))

	// Create work channel
	batchChan := make(chan BatchJob, totalBatches)
	var wg sync.WaitGroup

	// Fill channel with batch jobs
	for i := 0; i < totalBatches; i++ {
		startOffset := int64(i) * int64(config.BatchSize)
		remainingRecords := totalRecords - startOffset
		batchSize := int64(config.BatchSize)
		if remainingRecords < batchSize {
			batchSize = remainingRecords
		}

		batchChan <- BatchJob{
			BatchNum:     i,
			StartOffset:  startOffset,
			BatchSize:    batchSize,
			DataType:     dataType,
			TotalBatches: totalBatches,
		}
	}
	close(batchChan)

	startTime := time.Now()

	// Start workers
	for i := 0; i < config.NumGoroutines; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			dataWorker(workerID, batchChan, conn, config)
		}(i)
	}

	// Wait for completion
	wg.Wait()

	duration := time.Since(startTime)
	fmt.Printf("✓ Completed %d %s in %v (%.2f records/sec)\n",
		totalRecords, getDataTypeName(dataType), duration,
		float64(totalRecords)/duration.Seconds())

	return nil
}

type BatchJob struct {
	BatchNum     int
	StartOffset  int64
	BatchSize    int64
	DataType     DataType
	TotalBatches int
}

func dataWorker(workerID int, batchChan <-chan BatchJob, conn driver.Conn, config Config) {
	for job := range batchChan {
		// Add retry logic for timeouts
		maxRetries := 3
		var err error

		for retry := 0; retry <= maxRetries; retry++ {
			if err = processBatchJob(workerID, job, conn, config); err == nil {
				break
			}

			if retry < maxRetries {
				log.Printf("Worker %d: Retry %d/%d for batch %d: %v",
					workerID, retry+1, maxRetries, job.BatchNum, err)
				time.Sleep(time.Duration(retry+1) * time.Second)
			}
		}

		if err != nil {
			log.Printf("Worker %d: Failed batch %d after %d retries: %v",
				workerID, job.BatchNum, maxRetries, err)
			continue
		}

		if config.DelayMs > 0 {
			time.Sleep(time.Duration(config.DelayMs) * time.Millisecond)
		}
	}
}

func processBatchJob(workerID int, job BatchJob, conn driver.Conn, config Config) error {
	batchStart := time.Now()

	var query string

	switch job.DataType {
	case DataTypePolicies:
		query = generatePoliciesQuery(job, config)
	case DataTypeClaims:
		query = generateClaimsQueryOptimized(job, config) // Using optimized version
	case DataTypeDocuments:
		query = generateDocumentsQueryOptimized(job, config) // Using optimized version
	default:
		return fmt.Errorf("unknown data type: %v", job.DataType)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Second) // Increased to 5 minutes
	defer cancel()

	if err := conn.Exec(ctx, query); err != nil {
		return fmt.Errorf("failed to execute %s insert: %w", getDataTypeName(job.DataType), err)
	}

	duration := time.Since(batchStart)
	fmt.Printf("Worker %d: %s batch %d/%d completed (%d records in %v)\n",
		workerID, getDataTypeName(job.DataType), job.BatchNum+1, job.TotalBatches,
		job.BatchSize, duration)

	return nil
}

func generatePoliciesQuery(job BatchJob, config Config) string {
	return fmt.Sprintf(`
		INSERT INTO policies (
			policy_id, customer_id, agent_id, policy_type, policy_number,
			coverage_amount, premium_amount, deductible_amount,
			effective_date, end_date, status
		)
		SELECT 
			generateUUIDv4(),
			%d + ((number + %d) %% (%d - %d + 1)), -- customer_id in range
			%d + ((number + %d) %% (%d - %d + 1)), -- agent_id in range
			multiIf(
				number %% 5 = 0, 'Term Life',
				number %% 5 = 1, 'Whole Life',
				number %% 5 = 2, 'Universal Life',
				number %% 5 = 3, 'Variable Life',
				'Endowment'
			),
			concat('POL-', toString(number + %d), '-', toString(toUnixTimestamp(now()) %% 100000)),
			multiIf(
				number %% 3 = 0, 1000000.00 + (number %% 10) * 100000.00,
				number %% 3 = 1, 500000.00 + (number %% 10) * 50000.00,
				250000.00 + (number %% 10) * 25000.00
			),
			multiIf(
				number %% 3 = 0, 2400.00 + (number %% 10) * 240.00,
				number %% 3 = 1, 1200.00 + (number %% 10) * 120.00,
				600.00 + (number %% 10) * 60.00
			),
			multiIf(
				number %% 5 = 0, 0.00,
				(number %% 10) * 100.00
			),
			today() - INTERVAL (number %% 365) DAY,
			today() + INTERVAL multiIf(
				number %% 5 = 0, 20,
				number %% 5 = 1, 30,
				25
			) YEAR,
			multiIf(
				number %% 20 = 0, 'Pending',
				number %% 50 = 0, 'Lapsed',
				'Active'
			)
		FROM numbers(%d)`,
		config.MinCustomerID, job.StartOffset, config.MaxCustomerID, config.MinCustomerID,
		config.MinAgentID, job.StartOffset, config.MaxAgentID, config.MinAgentID,
		job.StartOffset,
		job.BatchSize)
}

// OPTIMIZED: Avoid OFFSET by using random selection
func generateClaimsQueryOptimized(job BatchJob, config Config) string {
	return fmt.Sprintf(`
		INSERT INTO claims (
			claim_id, policy_id, customer_id, claim_type, claim_number,
			incident_date, claim_amount, approved_amount, claim_status, 
			description, adjuster_id
		)
		SELECT 
			generateUUIDv4(),
			policy_id,
			customer_id,
			multiIf(
				(number %% 10) < 4, 'Death',
				(number %% 10) < 7, 'Disability',
				(number %% 10) < 9, 'Surrender',
				'Maturity'
			),
			concat('CLM-', toString(customer_id), '-', toString(toUnixTimestamp(now()) %% 100000)),
			effective_date + INTERVAL (number %% 1000) DAY,
			coverage_amount * multiIf(
				(number %% 10) < 4, 1.0,
				(number %% 10) < 7, 0.6,
				(number %% 10) < 9, 0.8,
				1.0
			),
			coverage_amount * multiIf(
				(number %% 10) < 4, 0.95,
				(number %% 10) < 7, 0.55,
				(number %% 10) < 9, 0.75,
				0.95
			),
			multiIf(
				number %% 15 = 0, 'Denied',
				number %% 10 = 0, 'Under Review',
				number %% 8 = 0, 'Approved',
				number %% 5 = 0, 'Paid',
				'Reported'
			),
			concat('Claim for policy ', policy_number, ' - ', 
				   multiIf(
					   (number %% 10) < 4, 'Death benefit claim',
					   (number %% 10) < 7, 'Disability claim',
					   (number %% 10) < 9, 'Policy surrender',
					   'Maturity benefit'
				   )),
			400 + (number %% 50)
		FROM (
			SELECT 
				policy_id, customer_id, effective_date, coverage_amount, policy_number
			FROM policies 
			WHERE status = 'Active'
			  AND cityHash64(policy_id) %% 100 < 30  -- Random 30%% selection instead of OFFSET
			LIMIT %d
		) AS p
		CROSS JOIN numbers(%d) AS n`,
		job.BatchSize/int64(config.DocsPerPolicy), job.BatchSize)
}

// OPTIMIZED: Avoid OFFSET by using random selection
func generateDocumentsQueryOptimized(job BatchJob, config Config) string {
	return fmt.Sprintf(`
		INSERT INTO policy_documents (
			document_id, policy_id, document_type, file_path, file_size,
			content_type, document_date
		)
		SELECT 
			generateUUIDv4(),
			policy_id,
			multiIf(
				number %% 5 = 0, 'Application',
				number %% 5 = 1, 'Policy Certificate',
				number %% 5 = 2, 'Medical Report',
				number %% 5 = 3, 'Amendment',
				'Claim Form'
			),
			concat('/documents/policy/', toString(customer_id), '/', 
				   multiIf(
					   number %% 5 = 0, 'application.pdf',
					   number %% 5 = 1, 'certificate.pdf',
					   number %% 5 = 2, 'medical.pdf',
					   number %% 5 = 3, 'amendment.pdf',
					   'claim_form.pdf'
				   )),
			1024 + (number %% 10) * 512,
			multiIf(
				number %% 3 = 0, 'application/pdf',
				number %% 3 = 1, 'image/jpeg',
				'application/msword'
			),
			effective_date + INTERVAL (number %% 30) DAY
		FROM (
			SELECT policy_id, customer_id, effective_date
			FROM policies 
			WHERE status IN ('Active', 'Pending')
			  AND cityHash64(policy_id) %% 100 < 80  -- Random 80%% selection
			LIMIT %d
		) AS p
		CROSS JOIN numbers(%d)`, // Generate multiple docs per policy
		job.BatchSize/int64(config.DocsPerPolicy), config.DocsPerPolicy)
}

func calculateTotalBatches(numPolicies, numClaims, numDocuments, batchSize int64) int64 {
	policyBatches := int64(math.Ceil(float64(numPolicies) / float64(batchSize)))
	claimBatches := int64(math.Ceil(float64(numClaims) / float64(batchSize)))
	documentBatches := int64(math.Ceil(float64(numDocuments) / float64(batchSize)))
	return policyBatches + claimBatches + documentBatches
}

func getDataTypeName(dataType DataType) string {
	switch dataType {
	case DataTypePolicies:
		return "policies"
	case DataTypeClaims:
		return "claims"
	case DataTypeDocuments:
		return "documents"
	default:
		return "unknown"
	}
}
