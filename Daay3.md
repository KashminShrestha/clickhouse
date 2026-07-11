# Today's Queries and Classes - Day 3

## Overview

These notes cover the main integrations and environmental setups from Day 3:

- Dynamic Docker networking setups for cross-container communication
- Deploying Kafka and PostgreSQL via Docker
- Connecting ClickHouse directly to PostgreSQL using the PostgreSQL table engine
- Querying PostgreSQL dynamically using the `postgresql()` table function
- Materializing external data into ClickHouse `MergeTree`
- Troubleshooting common networking and database connection issues

---

# 1. Environment Setup (Docker Containers)

To allow **ClickHouse**, **PostgreSQL**, and **Kafka** to communicate seamlessly, all containers must be connected to the same Docker network.

## Step A: Create a Shared Docker Network

```bash
# List existing Docker networks
docker network ls

# Create a dedicated network
docker network create my-network
```

---

## Step B: Start Apache Kafka (KRaft Mode)

```bash
docker run -d --name kafak --network my-network -p 9092:9092 \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafak:9093 \
  -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafak:9092 \
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT \
  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
  -e CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk \
  apache/kafka:latest
```

---

## Step C: Start PostgreSQL

```bash
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=mydatabase \
  -e TZ=Asia/Katmandu \
  -p 5432:5432 \
  postgres
```

### Connect PostgreSQL to the Docker Network

```bash
docker network connect my-network postgres
```

### Verify Container Details

```bash
docker inspect postgres
```

---

# 2. Preparing Source Data in PostgreSQL

Connect to the PostgreSQL database (`mydatabase`) and create a sample table.

## Create the Table

```sql
CREATE TABLE users (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    age INT,
    created_at TIMESTAMP
);
```

## Insert Sample Data

```sql
INSERT INTO users (name, email, age, created_at) VALUES
('John Doe', 'john@example.com', 30, NOW()),
('Jane Smith', 'jane@example.com', 25, NOW()),
('Sam Green', 'sam@example.com', 35, NOW());
```

---

# 3. ClickHouse ↔ PostgreSQL Integration

ClickHouse provides two methods for interacting with PostgreSQL:

1. PostgreSQL Table Engine
2. `postgresql()` Table Function

---

## Method A: PostgreSQL Table Engine

This creates a ClickHouse table that directly maps to a PostgreSQL table.

```sql
CREATE TABLE postgres_users_data_1 (
    id Int32,
    name String
)
ENGINE = PostgreSQL(
    'postgres:5432',
    'postgres',
    'users',
    'postgres',
    'mysecretpassword'
);
```

### Why `postgres:5432` instead of `localhost:5432`?

Since ClickHouse runs inside its own Docker container, `localhost` refers to the ClickHouse container itself—not the PostgreSQL container.

Docker automatically provides DNS resolution using container names, so use:

```text
postgres:5432
```

instead of

```text
localhost:5432
```

---

## Method B: `postgresql()` Table Function

Use this for one-time or ad-hoc queries without creating a permanent table.

### Syntax

```sql
SELECT *
FROM postgresql(
    'host:5432',
    'database',
    'table',
    'user',
    'password'
)
LIMIT 1;
```

### Example

```sql
SELECT *
FROM postgresql(
    'postgres:5432',
    'mydatabase',
    'users',
    'postgres',
    'mysecretpassword'
)
LIMIT 3;
```

---

# 4. Materializing External Data into MergeTree

Although ClickHouse can query PostgreSQL directly, production systems typically copy transactional data into ClickHouse for analytics.

This avoids placing analytical workloads on the OLTP database.

## Step 1: Create a Local MergeTree Table

```sql
CREATE TABLE clickhouse_users (
    user_id Int32,
    name String,
    age Int32,
    country String
)
ENGINE = MergeTree()
ORDER BY user_id;
```

---

## Step 2: Copy Data from PostgreSQL

```sql
INSERT INTO clickhouse_users
SELECT *
FROM postgres_users_data_1;
```

---

# 5. Common Network and Integration Gotchas

## 1. Database Does Not Exist (Error Code: 614)

### Error

```text
FATAL: database "clickhouse_db" does not exist
```

### Cause

The database name supplied in the connection string doesn't match the database created in PostgreSQL.

For example, if the container was started with:

```bash
-e POSTGRES_DB=mydatabase
```

then connecting to:

```text
clickhouse_db
```

will fail.

### Solution

Always connect using the correct database name:

```text
mydatabase
```

---

## 2. Transport Errors (Error Code: 1001)

### Symptoms

- HTTP 500
- Connection timeout
- Transport error

### Cause

Containers are either:

- Not connected to the same Docker network, or
- Using `localhost` instead of the PostgreSQL container name.

### Solution

Verify both containers are attached to the same network.

Use:

```text
postgres:5432
```

instead of:

```text
localhost:5432
```

---

## 3. Debugging Connections

### ClickHouse Server Logs

```text
/var/log/clickhouse-server
```

---

### Install Diagnostic Utilities (Alpine)

```bash
apk update
apk add busybox-extras
```

---

### Install Diagnostic Utilities (Ubuntu/Debian)

```bash
apt-get update
apt-get install -y busybox
```

These tools provide utilities such as:

- telnet
- nc (netcat)
- networking diagnostics

which are useful for verifying connectivity between containers.

---

# 6. Important Takeaways

- Place all related containers on the same Docker network.
- Use Docker container names (e.g., `postgres`) instead of IP addresses or `localhost`.
- Use the PostgreSQL table engine for persistent integration.
- Use the `postgresql()` table function for quick, one-off queries.
- Copy data into `MergeTree` tables for analytical workloads instead of querying PostgreSQL directly.
- Validate networking with diagnostic tools before troubleshooting application configurations.
- Inspect ClickHouse server logs when connection issues occur.

---

# Summary

| Component | Purpose |
|-----------|---------|
| Docker Network | Enables communication between containers |
| Kafka | Message broker |
| PostgreSQL | Transactional (OLTP) database |
| PostgreSQL Table Engine | Persistent PostgreSQL integration |
| `postgresql()` Table Function | Temporary PostgreSQL queries |
| MergeTree | Optimized ClickHouse storage engine for analytics |
| BusyBox / Netcat | Network diagnostics |
| ClickHouse Logs | Debugging server and connection issues |
