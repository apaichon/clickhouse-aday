const { createClient } = require('@clickhouse/client');

async function insertData() {
    const clickhouse = createClient({
        url: 'http://localhost:8123',
        database: 'chat_payments',
        username: 'admin',
        password: 'admin',
        compression: {
            response: true,
            request: false
        },
        session_timeout: 60,
        keep_alive: {
            enabled: true
        }
    });

    const totalBatches = 10;
    const batchSize = 100_000;  // Reduced batch size

    console.time('Total Insert Time');

    for (let batch = 0; batch < totalBatches; batch++) {
        try {
            console.time(`Batch ${batch + 1}`);

            const query = `
                INSERT INTO messages
                (message_id, chat_id, user_id, sent_timestamp, message_type, content, has_attachment, sign)
                SELECT
                    generateUUIDv4() as message_id,
                    toUInt64(rand() % 1000) as chat_id,
                    toUInt32(rand() % 10000) as user_id,
                    now() - toIntervalDay(rand() % 30) as sent_timestamp,
                    CAST(
                        multiIf(
                            rand() % 4 = 0, 'text',
                            rand() % 4 = 1, 'image',
                            rand() % 4 = 2, 'invoice',
                            'receipt'
                        ) AS Enum8('text' = 1, 'image' = 2, 'invoice' = 3, 'receipt' = 4)
                    ) as message_type,
                    'Batch generated message ' || toString(number) as content,
                    rand() % 2 as has_attachment,
                    1 as sign
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