# Module 4 — Query Monitoring and Performance Analysis in ClickHouse

## Overview and Learning Objectives

In this module you will learn how to use ClickHouse system tables to observe query execution, identify bottlenecks, and tune workloads. By the end of the module you will be able to:

- Inspect query history with `system.query_log`
- Identify slow and resource-intensive queries
- Analyze memory, CPU, and disk I/O consumption
- Group similar statements using `normalizeQuery()`
- Build a practical workflow for performance tuning

---

## Introduction to `system.query_log`

`system.query_log` records information about completed and running queries. It is the primary source for performance investigations and operational monitoring.

Important fields include:

- `query_id`: Unique identifier of a query execution.
- `query_kind`: Query category such as `Select` or `Insert`.
- `type`: Lifecycle event (`QueryStart`, `QueryFinish`, etc.).
- `query_duration_ms`: Execution time.
- `memory_usage`: Peak memory consumed.
- `read_rows` and `read_bytes`: Data scanned during execution.

---

## Monitoring Slow Queries

```sql
SELECT
    query_start_time,
    query_duration_ms,
    read_rows,
    formatReadableSize(memory_usage) AS mem,
    query
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_date = today()
ORDER BY query_duration_ms DESC
LIMIT 10;
```

This query shows the slowest completed queries for today. Large execution times combined with many rows read usually indicate missing filters, inefficient joins, or suboptimal table ordering.

---

## Finding Memory-Intensive Queries

```sql
SELECT
    query_id,
    user,
    formatReadableSize(memory_usage) AS max_mem,
    query_duration_ms AS duration,
    query
FROM system.query_log
WHERE event_time >= now() - INTERVAL 1 DAY
  AND type = 'QueryFinish'
  AND query_kind = 'Select'
ORDER BY memory_usage DESC
LIMIT 20;
```

Use this report to identify analytical statements that may benefit from better predicates, projections, or aggregation strategies.

---

## CPU and Disk I/O Analysis

```sql
SELECT
    user,
    query_id,
    query_duration_ms,
    formatReadableSize(memory_usage) AS max_ram_used,
    formatReadableSize(read_bytes) AS disk_bytes_read,
    read_rows AS disk_rows_read,
    formatReadableTimeDelta(ProfileEvents['UserTimeMicroseconds'] / 1000000) AS cpu_user_time,
    formatReadableTimeDelta(ProfileEvents['SystemTimeMicroseconds'] / 1000000) AS cpu_system_time,
    normalizeQuery(query) AS normalized_query
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_time >= now() - INTERVAL 1 DAY
ORDER BY memory_usage DESC,
         ProfileEvents['UserTimeMicroseconds'] DESC
LIMIT 10;
```

`ProfileEvents` expose detailed resource consumption. `normalizeQuery()` replaces literals with placeholders, allowing you to aggregate similar statements and discover recurring expensive patterns.

---

## Performance Tuning Workflow

1. Identify slow or expensive queries.
2. Examine rows and bytes scanned.
3. Verify that table ordering keys match common filters.
4. Reduce unnecessary columns and computations.
5. Re-run the query and compare metrics in `system.query_log`.

---

## Best Practices

- Enable query logging in production.
- Review normalized query patterns regularly.
- Investigate sudden increases in memory or scan volume.
- Retain logs long enough to support trend analysis.

---

## Hands-On Exercises

1. Find the five slowest queries executed in the last hour.
2. Group queries by `normalizeQuery(query)` and compute average duration.
3. Identify the user consuming the most memory during the past day.

---

## Summary

| Metric | Purpose |
|---|---|
| `query_duration_ms` | Execution latency |
| `memory_usage` | Peak RAM consumption |
| `read_rows`, `read_bytes` | Data scanned |
| `ProfileEvents` | CPU and low-level statistics |
| `normalizeQuery()` | Workload pattern analysis |

### Additional Notes

Query monitoring is a continuous activity. Combining the foundational data modeling concepts from Module 2 with the integration techniques from Module 3 enables efficient, observable, and production-ready ClickHouse deployments.
