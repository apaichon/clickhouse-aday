# Materialized View
Tips
1. Create Materilized View
```sql
CREATE MATERIALIZED VIEW daily_policy_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(policy_date)
ORDER BY (policy_date, policy_type, agent_id)
AS
SELECT 
    toDate(effective_date) as policy_date,
    policy_type,
    agent_id,
    count() as policies_issued,
    sum(coverage_amount) as total_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE status = 'Active'
GROUP BY policy_date, policy_type, agent_id;
```

2. Refresh Materalized view
```sql
Insert into daily_policy_summary
SELECT 
    toDate(effective_date) as policy_date,
    policy_type,
    agent_id,
    count() as policies_issued,
    sum(coverage_amount) as total_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE status = 'Active'
GROUP BY policy_date, policy_type, agent_id;
```
3. Check data.
```sql
select * from daily_policy_summary final
```

4. Insert new data.
```sql
INSERT INTO policies
(policy_id, customer_id, agent_id, policy_number, policy_type, coverage_amount, premium_amount, deductible_amount, effective_date, end_date, status, created_at, updated_at, version)
SELECT
    generateUUIDv4() as policy_id,
    toUInt64(rand() % 100000) as customer_id,
    604 as agent_id,
    'LIFE-' || toString(toYear(now())) || '-' || toString(number) as policy_number,
    'Endowment'  as policy_type,
    round(rand() * 1000000 + 100000, 2) as coverage_amount,
    round(rand() * 5000 + 500, 2) as premium_amount,
    round(rand() * 1000, 2) as deductible_amount,
    '2024-06-25'::Date as effective_date,
    (now() + toIntervalYear(20 + rand() % 20))::Date as end_date,
    CAST(
        multiIf(
            rand() % 10 = 0, 'Pending',
            rand() % 20 = 0, 'Lapsed',
            rand() % 50 = 0, 'Terminated',
            rand() % 100 = 0, 'Matured',
            'Active'
        ) AS Enum8('Active' = 1, 'Lapsed' = 2, 'Terminated' = 3, 'Matured' = 4, 'Pending' = 5)
    ) as status,
    now() as created_at,
    now() as updated_at,
    1 as version
FROM numbers(2);
```



select * from daily_policy_summary FINAL
where agent_id =604 and policy_date ='2024-06-25'


- quick command
- access control
- generate data
- index
