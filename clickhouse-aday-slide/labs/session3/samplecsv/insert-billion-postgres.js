const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid'); // For generating UUIDs

async function insertData() {
    const pool = new Pool({
        user: 'admin',
        host: 'localhost',
        database: 'mydb',
        password: 'admin',
        port: 5432,
        max: 10
    });

    const totalBatches = 1_000;
    const batchSize = 100_000; // 100k

    console.time('Total Insert Time');

    for (let batch = 0; batch < totalBatches; batch++) {
        try {
            console.time(`Batch ${batch + 1}`);

            // Generate data for this batch
            const values = [];
            for (let i = 0; i < batchSize; i++) {
                const message_id = uuidv4();
                const chat_id = Math.floor(Math.random() * 1000);
                const user_id = Math.floor(Math.random() * 10000);
                const sent_timestamp = new Date(Date.now() - Math.floor(Math.random() * 30 * 24 * 60 * 60 * 1000));
                const typeRand = Math.floor(Math.random() * 4);
                const message_type = ['text', 'image', 'invoice', 'receipt'][typeRand];
                const content = `Batch generated message ${batch * batchSize + i}`;
                const has_attachment = (Math.floor(Math.random() * 2) === 1) ? true : false;
                const sign = 1;
                values.push(`('${message_id}', ${chat_id}, ${user_id}, '${sent_timestamp.toISOString()}', '${message_type}', '${content.replace(/'/g, "''")}', ${has_attachment}, ${sign})`);
            }

            // Bulk insert
            const query = `
                INSERT INTO messages
                (message_id, chat_id, user_id, sent_timestamp, message_type, content, has_attachment, sign)
                VALUES
                ${values.join(',')}
            `;

            await pool.query(query);

            console.timeEnd(`Batch ${batch + 1}`);
            console.log(`Progress: ${((batch + 1) / totalBatches * 100).toFixed(2)}%`);

            // Optional: delay between batches
            await new Promise(resolve => setTimeout(resolve, 100));
        } catch (error) {
            console.error(`Error in batch ${batch + 1}:`, error);
            // Optional: retry logic here
            batch--;
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue;
        }
    }

    console.timeEnd('Total Insert Time');
    await pool.end();
}

// Run the insert
insertData().catch(console.error); 