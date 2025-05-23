// Let's generate sample data for the ClickHouse table
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');

// Define configuration
const numRows = 1_000_000;
const startDate = new Date('2023-01-01');
const endDate = new Date('2025-04-01');
const currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'];
const statuses = ['pending', 'paid', 'canceled'];
const statusEnums = { 'pending': 1, 'paid': 2, 'canceled': 3 };

// Helper function to generate random date between start and end
function randomDate(start, end) {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

// Helper function to format date as YYYY-MM-DD
function formatDate(date) {
  return date.toISOString().split('T')[0];
}

// Helper function to format datetime as YYYY-MM-DD HH:MM:SS
function formatDateTime(date) {
  return date.toISOString().replace('T', ' ').split('.')[0];
}

// Helper function to generate random decimal with 2 decimal places
function randomDecimal(min, max) {
  return (Math.random() * (max - min) + min).toFixed(2);
}

// Helper function to generate random file path
function randomFilePath() {
  const folders = ['invoices', 'receipts', 'contracts', 'statements'];
  const fileTypes = ['pdf', 'docx', 'jpg', 'png'];
  const folder = folders[Math.floor(Math.random() * folders.length)];
  const fileType = fileTypes[Math.floor(Math.random() * fileTypes.length)];
  return `/storage/${folder}/${uuidv4().slice(0, 8)}.${fileType}`;
}

// Helper function to generate random file size (1KB to 10MB)
function randomFileSize() {
  return Math.floor(Math.random() * 10 * 1024 * 1024) + 1024;
}

// Generate the CSV data
let csvData = [];

// Add header
csvData.push([
  'attachment_id',
  'message_id',
  'payment_amount',
  'payment_currency',
  'invoice_date',
  'payment_status',
  'file_path',
  'file_size',
  'uploaded_at',
  'sign'
].join(','));

// Generate rows
for (let i = 0; i < numRows; i++) {
  const uploadDate = randomDate(startDate, endDate);
  const invoiceDate = randomDate(new Date(uploadDate.getTime() - 30 * 24 * 60 * 60 * 1000), uploadDate);
  const paymentStatus = statuses[Math.floor(Math.random() * statuses.length)];

  // For collapsed rows, we need to generate pairs with sign 1 and -1
  // This simulates updates in CollapsingMergeTree
  // Let's make ~20% of our records have a "matching" collapsed record
  const generateCollapsedPair = Math.random() < 0.2;

  // First record with sign = 1
  const row = [
    uuidv4(),
    uuidv4(),
    randomDecimal(10, 5000),
    currencies[Math.floor(Math.random() * currencies.length)],
    formatDate(invoiceDate),
    paymentStatus,
    randomFilePath(),
    randomFileSize(),
    formatDateTime(uploadDate),
    1  // sign = 1 for "add" record
  ];

  csvData.push(row.join(','));

  // If we're generating a pair, add a matching record with sign = -1
  if (generateCollapsedPair) {
    // Clone the row but set sign to -1
    const collapsedRow = [...row];
    collapsedRow[9] = -1; // sign = -1 for "delete" record
    csvData.push(collapsedRow.join(','));
  }
}

// Instead of console.log, write to file
const outputPath = './output.csv';
fs.writeFileSync(outputPath, csvData.join('\n'));

// Print stats
console.log(`\nFile written to: ${outputPath}`);
console.log(`Generated ${csvData.length - 1} rows of data (including ${csvData.length - 1 - numRows} collapsed records)`);
console.log(`CSV contains data spanning from ${startDate.toDateString()} to ${endDate.toDateString()}`);