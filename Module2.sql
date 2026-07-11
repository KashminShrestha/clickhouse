create database training;

create table training.table1
(
	Column1 String
)
engine = Log;

insert into training.table1
values ('a'),('b');

rename table training.table1 to training.table2;

select * from training.table2 t ;

show tables from training;

truncate table training.table2;

select * from training.table2 t ;

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

INSERT INTO bank_demo.transactions VALUES
(1, 1001, 'KTM-01', 5000.00, 'DEPOSIT', '2026-06-01'),
(2, 1002, 'PKR-02', 1500.50, 'WITHDRAW', '2026-06-01');

select * from bank_demo.transactions;

SELECT
    branch_code,
    sum(amount) AS total
FROM bank_demo.transactions
GROUP BY branch_code
ORDER BY total DESC
LIMIT 10;




SELECT *
FROM s3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet',
    Parquet
)
LIMIT 10;

CREATE TABLE noaa_weather_s3
ENGINE = S3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet',
    Parquet
);

select * from noaa_weather_s3;

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

DESC s3(
'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet'
);

CREATE TABLE weather_temp
ENGINE = Memory
AS
SELECT *
FROM s3(
'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet'
)
LIMIT 100
SETTINGS schema_inference_make_columns_nullable = 0;


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


INSERT INTO weather
SELECT *
FROM s3(
'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet'
)
WHERE toYear(date) >= 1995;

INSERT INTO weather
SELECT *
FROM s3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/noaa/noaa_enriched.parquet',
    Parquet
)
WHERE toYear(date) >= 1995
LIMIT 1000000;

SELECT formatReadableQuantity(count())
FROM weather;

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

SELECT
formatReadableSize(sum(data_compressed_bytes)),
formatReadableSize(sum(data_uncompressed_bytes))
FROM system.parts
WHERE table='weather'
AND active=1;


SELECT *
FROM file(
    'annual-enterprise-survey-2025-financial-year-provisional.csv',
    CSVWithNames
)
LIMIT 5;

SELECT *
FROM weather
INTO OUTFILE '/data/raw_events.csv'
FORMAT CSV;
