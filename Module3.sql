-- ### Postgres SQL
CREATE TABLE users (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    age INT,
    created_at TIMESTAMP
);

INSERT INTO users (name, email, age, created_at) VALUES
('John Doe', 'john@example.com', 30, NOW()),
('Jane Smith', 'jane@example.com', 25, NOW()),
('Sam Green', 'sam@example.com', 35, NOW()),
('Kashmin', 'kashmin@example.com', 35, NOW());

select * from users;

-- ### Clickhouse SQL
CREATE TABLE postgres_users
(
    id Int32,
    name String,
    email String,
    age Int32,
    created_at DateTime
)
ENGINE = PostgreSQL(
    'postgres:5432',
    'mydatabase',
    'users',
    'postgres',
    'mysecretpassword'
);

SELECT *
FROM postgresql(
    'postgres:5432',
    'mydatabase',
    'users',
    'postgres',
    'mysecretpassword'
);

SHOW CREATE TABLE postgres_users;

select * from default.postgres_users ;

CREATE TABLE clickhouse_users
(
    id Int32,
    name String,
    email String,
    age Int32,
    created_at DateTime
)
ENGINE = MergeTree()
ORDER BY (id, email);

INSERT INTO clickhouse_users
SELECT *
FROM postgres_users;

select * from clickhouse_users;

