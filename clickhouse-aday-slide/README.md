# ClickHouse Course Outline
Clickhouse essential course in a day.

## Course Structure

### Main Course Content
The main course content is available in `clickhouse-aday-slide/clickhouse.slides.md`. This file contains the complete course material including:
- Introduction to ClickHouse
- Data Types and Schema Design
- Basic Operations
- Advanced Querying
- Data Management
- Performance Optimization
- Monitoring with Grafana

### Hands-on Labs
The course includes practical labs located in the `clickhouse-aday-slide/labs` directory, organized by session:
- `session1/` - Introduction and Setup
- `session2/` - Data Types and Schema Design
- `session3/` - Basic Operations
- `session4/` - Advanced Querying
- `session5/` - Data Management
- `session6/` - Performance Optimization
- `session7/` - Monitoring with Grafana

## Setup Instructions

1. Install dependencies:
```bash
cd clickhouse-aday/clickhouse-aday-slide && npm install
```

2. Run the development server:
```bash
npm run dev
```

3. Access the slides at http://localhost:3030

## Course Content Overview

### Session 1. Introduction to ClickHouse (1 hour)
- What is ClickHouse?
- Key features and advantages
- Use cases and applications
- Installation and setup
- Basic architecture overview

### Session 2. Data Types and Schema Design (1 hour)
- Native data types
- Complex data types (Arrays, Nested, Tuples)
- Table engines overview
- Schema design best practices
- Partitioning and sharding concepts

### Session 3. Basic Operations (1 hour)
- Creating databases and tables
- Inserting data
- Basic SELECT queries
- WHERE clauses and filtering
- ORDER BY and LIMIT
- Aggregation functions

### Session 4. Advanced Querying (1 hour)
- JOIN operations
- Window functions
- Subqueries
- Common table expressions (CTEs)
- Query optimization techniques

### Session 5. Data Management (1 hour)
- Data insertion methods
- Batch processing
- Data deduplication
- Data compression
- Backup and Restore

### Session 6. Performance Optimization (1 hour)
- Index types and usage
- Query optimization
- Materialized views
- Projections

### Session 7. Monitoring with Grafana (1 hour)
- Setting up Grafana with ClickHouse
- Creating ClickHouse data sources
- Building monitoring dashboards
- Key metrics to monitor
  - Query performance
  - System resources
  - Table sizes and growth



