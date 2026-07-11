# Today's Queries and Classes - Day 2

## Overview

These notes cover the main ClickHouse topics from Day 2:

- Basic database and table commands
- MergeTree table design
- External data sources with `s3()` and `url()`
- Loading CSV and Parquet data
- File import and export patterns
- A few important ClickHouse performance gotchas

## 0) ClickHouse Data Types

ClickHouse is a strongly typed columnar database. Choosing the right data type matters because it affects storage size, compression, and query speed.

### Why data types matter

- Smaller types usually store less data and scan faster.
- Exact numeric types are safer for financial values.
- Repeated strings can be optimized with `LowCardinality(String)`.
- Nested types such as `Array`, `Tuple`, `Map`, and dictionaries help model semi-structured data.

### Common primitive types

| Type | Use Case | Example |
|---|---|---|
| `Int32` / `UInt32` | Counts, IDs, numeric values | `user_id UInt32` |
| `Float32` / `Float64` | Scientific or approximate values | `temperature Float32` |
| `Decimal(18, 2)` | Money and exact calculations | `amount Decimal(18, 2)` |
| `String` | Text values | `name String` |
| `Date` | Dates without time | `created_at Date` |
| `DateTime` | Date and time values | `event_time DateTime` |
| `LowCardinality(String)` | Repeated text values | `branch_code LowCardinality(String)` |

### Example: primitive columns

```sql
CREATE TABLE sample_types
(
    user_id UInt32,
    user_name String,
    balance Decimal(18, 2),
    created_at DateTime,
    status LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY user_id;
```

This table shows the most common business-friendly ClickHouse types in one place.

### Array type

`Array(T)` stores multiple values of the same type in one column.

Use it when one record can have many values of the same kind, such as tags, skills, or categories.

#### Example

```sql
CREATE TABLE user_tags
(
    user_id UInt32,
    tags Array(String)
)
ENGINE = MergeTree
ORDER BY user_id;
```

#### Insert example

```sql
INSERT INTO user_tags VALUES
(1, ['sql', 'clickhouse', 'analytics']),
(2, ['python', 'data']);
```

#### Query example

```sql
SELECT
    user_id,
    tags,
    length(tags) AS tag_count
FROM user_tags;
```

This returns the full array and also counts how many items are inside it.

### Tuple type

`Tuple` stores a fixed number of values together. It is useful for coordinates, pairs, or grouped values that belong together.

#### Example

```sql
CREATE TABLE locations
(
    place_id UInt32,
    location Tuple(lat Float64, lon Float64)
)
ENGINE = MergeTree
ORDER BY place_id;
```

#### Insert example

```sql
INSERT INTO locations VALUES
(1, (27.7172, 85.3240)),
(2, (28.3949, 84.1240));
```

#### Query example

```sql
SELECT
    place_id,
    location.lat,
    location.lon
FROM locations;
```

Named tuple fields make the data easier to read and query.

### Map type

`Map(K, V)` stores key-value pairs. The key is usually a `String`, and the value can be a number, string, or other type.

Use it when each row contains a small flexible set of attributes, such as metadata or dynamic counters.

#### Example

```sql
CREATE TABLE product_attributes
(
    product_id UInt32,
    attributes Map(String, String)
)
ENGINE = MergeTree
ORDER BY product_id;
```

#### Insert example

```sql
INSERT INTO product_attributes VALUES
(1, {'color': 'red', 'size': 'M'}),
(2, {'color': 'blue', 'material': 'cotton'});
```

#### Query example

```sql
SELECT
    product_id,
    attributes['color'] AS color,
    attributes['size'] AS size
FROM product_attributes;
```

If a key does not exist, the result may be empty or default depending on the query and type.

### Dictionary concept

ClickHouse dictionaries are fast lookup structures used for reference data such as product names, user profiles, or code-to-name mappings.

They are especially useful when you want to avoid joins on large dimension tables.

#### Function-style lookup

```sql
SELECT dictGet('dictionary_name', 'attribute_name', key);
```

#### Example use case

If you have a dictionary that maps branch codes to branch names, you can fetch the name directly instead of joining a table.

```sql
SELECT dictGet('branch_dictionary', 'branch_name', 'KTM-01');
```

This returns the value stored for the key `KTM-01`.

### Quick comparison

| Type | Best For | Notes |
|---|---|---|
| `Array` | Multiple values of same type | Good for tags, lists, repeated values |
| `Tuple` | Fixed grouped values | Good for coordinates or paired fields |
| `Map` | Dynamic key-value data | Good for flexible attributes |
| `Dictionary` | Fast reference lookup | Useful for replacing joins on lookup data |

## 1) Basic Database and Table Commands

### Create a database

```sql
CREATE DATABASE training;
```

This creates a logical container named `training` for tables and other objects.

### Show databases

```sql
SHOW DATABASES;
```

This lists all available databases in the ClickHouse server.

### Create a table using the `Log` engine

```sql
CREATE TABLE training.table1
(
    Column1 String
)
ENGINE = Log;
```

This creates a very simple table for practice or testing.

The `Log` engine is lightweight and has no indexing or merge optimization, so it is not a production engine.

### Insert data

```sql
INSERT INTO training.table1
VALUES ('a'), ('b');
```

This inserts two rows into the table.

### Rename the table

```sql
RENAME TABLE training.table1 TO training.table2;
```

This changes only the metadata name of the table. The data itself is not rewritten.

### Read the data

```sql
SELECT *
FROM training.table2;
```

This reads all rows from the renamed table.

### Show tables inside a database

```sql
SHOW TABLES
FROM training;
```

This lists the tables stored in the `training` database.

### Truncate the table

```sql
TRUNCATE TABLE training.table2;
```

This removes all rows but keeps the table structure.

### Drop the table

```sql
DROP TABLE training.table2;
```

This deletes the table and its data completely.

### Drop the database

```sql
DROP DATABASE training;
```

This deletes the database and everything inside it.

## 2) MergeTree Engine - Bank Transactions

### Why MergeTree matters

`MergeTree` is the main storage engine used for analytical workloads in ClickHouse. It supports:

- Fast reads
- Sorting on disk
- Background merges
- Efficient filtering with primary key layout

### Create the database and table

```sql
CREATE DATABASE IF NOT EXISTS bank_demo;

CREATE TABLE bank_demo.transactions
(
    transaction_id UInt64,
    account_id UInt32,
    branch_code LowCardinality(String),
    amount Decimal(18, 2),
    txn_type LowCardinality(String),
    txn_date Date
)
ENGINE = MergeTree()
ORDER BY (txn_date, account_id);
```

This table is sorted by `txn_date` and then `account_id`, which helps ClickHouse skip data faster during queries.

`LowCardinality(String)` is useful for repeated string values such as branch codes and transaction types.

### Insert sample rows

```sql
INSERT INTO bank_demo.transactions VALUES
(1, 1001, 'KTM-01', 5000.00, 'DEPOSIT', '2026-06-01'),
(2, 1002, 'PKR-02', 1500.50, 'WITHDRAW', '2026-06-01');
```

This adds sample transaction data for testing.

### Read the table

```sql
SELECT *
FROM bank_demo.transactions;
```

This shows all inserted transactions.

### Aggregate by branch

```sql
SELECT
    branch_code,
    sum(amount) AS total
FROM bank_demo.transactions
GROUP BY branch_code
ORDER BY total DESC
LIMIT 10;
```

This calculates the total amount per branch.

## 3) External Data with `s3()`

### Read a remote Parquet file directly

```sql
SELECT *
FROM s3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet',
    'Parquet'
)
LIMIT 10;
```

This reads data directly from a remote Parquet file without creating a local table first.

### Create a virtual S3-backed table

```sql
CREATE TABLE noaa_weather_s3
ENGINE = S3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet',
    'Parquet'
);

SELECT *
FROM noaa_weather_s3
LIMIT 5;
```

This treats the remote file like a table for read-only querying.

## 4) Streaming Data with `url()`

### Create a destination table

```sql
CREATE TABLE uk_price_paid
(
    transaction_id String,
    price UInt32,
    transfer_date DateTime,
    postcode String,
    property_type String,
    old_new String,
    duration String,
    paon String,
    saon String,
    street String,
    locality String,
    town_city String,
    district String,
    county String,
    ppd_category_type String,
    record_status String
)
ENGINE = MergeTree
ORDER BY transfer_date;
```

This table is designed to store UK price-paid data.

### Load data from a remote CSV file

```sql
INSERT INTO uk_price_paid
SELECT
    transaction_id,
    price,
    parseDateTimeBestEffort(transfer_date),
    postcode,
    property_type,
    old_new,
    duration,
    paon,
    saon,
    street,
    locality,
    town_city,
    district,
    county,
    ppd_category_type,
    record_status
FROM url(
    'https://price-paid-data.publicdata.landregistry.gov.uk/pp-2026.csv',
    'CSV',
    '
    transaction_id String,
    price UInt32,
    transfer_date String,
    postcode String,
    property_type String,
    old_new String,
    duration String,
    paon String,
    saon String,
    street String,
    locality String,
    town_city String,
    district String,
    county String,
    ppd_category_type String,
    record_status String
    '
);
```

`parseDateTimeBestEffort()` converts the text date into ClickHouse `DateTime` format.

## 5) NOAA Weather Dataset

### Inspect the schema of a remote Parquet file

```sql
DESC s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet');
```

This shows the columns and types available in the Parquet file.

### Stage a small sample in memory

```sql
CREATE TABLE weather_temp
ENGINE = Memory
AS
SELECT *
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet')
LIMIT 100
SETTINGS schema_inference_make_columns_nullable = 0;
```

This creates a temporary in-memory sample for quick testing.

### Create the final weather table

```sql
CREATE TABLE weather
(
    station_id LowCardinality(String),
    date Date32,
    tempAvg Int32,
    tempMax Int32,
    tempMin Int32,
    precipitation Int32,
    snowfall Int32,
    snowDepth Int32,
    percentDailySun Int8,
    averageWindSpeed Int32,
    maxWindSpeed Int32,
    weatherType UInt8,
    location Tuple(lat Float64, lon Float64),
    elevation Float32,
    name String
)
ENGINE = MergeTree
PRIMARY KEY date;
```

This table is optimized for time-based analysis.

`PRIMARY KEY date` works well because weather data is usually queried by date ranges.

### Insert data into the weather table

```sql
INSERT INTO weather
SELECT *
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet')
WHERE toYear(date) >= 1995;
```

This loads only records from 1995 onward.

### Count rows

```sql
SELECT formatReadableQuantity(count())
FROM weather;
```

This shows the row count in a readable format.

### Find hot weather records

```sql
SELECT
    tempMax / 10 AS maxTemp,
    location,
    name,
    date
FROM weather
WHERE tempMax > 500
ORDER BY
    tempMax DESC,
    date ASC
LIMIT 10;
```

This finds the warmest records and converts tenths of degrees into normal units.

### Check compression sizes

```sql
SELECT
    formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS raw_size
FROM system.parts
WHERE table = 'weather'
  AND active = 1;
```

This compares compressed and uncompressed storage size for the table.

## 6) File Input and Output

### Read a local CSV file

```sql
SELECT *
FROM file(
    'annual-enterprise-survey-2025-financial-year-provisional.csv',
    'CSVWithNames'
)
LIMIT 5;
```

This reads a CSV file from disk.

### Export query results to a file

```sql
SELECT *
FROM weather
INTO OUTFILE '/data/raw_events.csv'
FORMAT CSV;
```

This writes query output to a CSV file.

## 7) Important Takeaways

- Use `MergeTree` for real analytical tables.
- Use `LowCardinality(String)` for repeated text values.
- Use `s3()` for remote object storage reads.
- Use `url()` when loading from a remote HTTP CSV source.
- Avoid many tiny inserts. Batch inserts into larger chunks to reduce the "Too many parts" problem.
- Use `parseDateTimeBestEffort()` when the incoming date format may vary.

