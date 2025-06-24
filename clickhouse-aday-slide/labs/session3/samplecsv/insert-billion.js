const { createClient } = require('@clickhouse/client');

async function insertData() {
    const clickhouse = createClient({
        url: 'http://localhost:8123',
        database: 'life_insurance',
        username: 'admin',
        password: 'P@ssw0rd',
        compression: {
            response: true,
            request: false
        },
        session_timeout: 60,
        keep_alive: {
            enabled: true
        }
    });

    const totalBatches = 500;
    const batchSize = 100_000;  // Reduced batch size

    console.time('Total Insert Time');

    for (let batch = 0; batch < totalBatches; batch++) {
        try {
            console.time(`Batch ${batch + 1}`);

            const query = `
                INSERT INTO policies
                (policy_id, customer_id, agent_id, policy_type, policy_number, coverage_amount, premium_amount, deductible_amount, effective_date, end_date, status, created_at, updated_at, version)
                SELECT
                    generateUUIDv4() as policy_id,
                    toUInt64(rand() % 1000) as customer_id,
                    toUInt32(rand() % 10000) as agent_id,
                    now() - toIntervalDay(rand() % 30) as effective_date,
                    CAST(
                        multiIf(
                            rand() % 4 = 0, 'Term Life',
                            rand() % 4 = 1, 'Whole Life',
                            rand() % 4 = 2, 'Universal Life',
                            'Variable Life'
                        ) AS Enum8('Term Life' = 1, 'Whole Life' = 2, 'Universal Life' = 3, 'Variable Life' = 4, 'Endowment' = 5)
                    ) as policy_type,
                    'Batch generated message ' || toString(number) as policy_number,
                    rand() % 2 as status,
                    now() as created_at,
                    now() as updated_at,
                    1 as version
                FROM numbers(${batchSize})

    
            `;

            await clickhouse.exec({
                query: query,
                clickhouse_settings: { wait_end_of_query: 1 }
            });

            // Clear buffers - fixed syntax
            await clickhouse.exec({
                query: 'SYSTEM FLUSH LOGS'  // Changed from FLUSH BUFFERS to FLUSH LOGS
            });

            console.timeEnd(`Batch ${batch + 1}`);
            console.log(`Progress: ${((batch + 1) / totalBatches * 100).toFixed(2)}%`);

            // Increased delay between batches
            await new Promise(resolve => setTimeout(resolve, 100));

        } catch (error) {
            console.error(`Error in batch ${batch + 1}:`, error);
            if (error.code === 'ECONNREFUSED') {
                console.log('Connection refused, retrying in 5 seconds...');
                await new Promise(resolve => setTimeout(resolve, 5000));
                batch--; // Retry the same batch
                continue;
            }
            // Add delay before retry
            await new Promise(resolve => setTimeout(resolve, 5000));
            batch--; // Retry the same batch
            continue;
        }
    }

    // Final flush
    await clickhouse.exec({
        query: 'SYSTEM FLUSH LOGS'
    });

    console.timeEnd('Total Insert Time');
    await clickhouse.close();
}

// Run the insert
insertData().catch(console.error); 