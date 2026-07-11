# ClickHouse Docker Setup and User Authentication Troubleshooting

## Environment

- Operating System: Windows
- Docker Image: `clickhouse:latest`
- ClickHouse Version: 26.6.1
- Container Name: `clickhouse`
- Container ID: `5008640786a6`

## Verify ClickHouse Docker Container

The running Docker container was verified using:

```bash
docker ps -a
```

The container details:

| Property | Value |
|---|---|
| Image | clickhouse:latest |
| Container ID | 5008640786a6 |
| HTTP Port | 8123 |
| Native TCP Port | 9000 |

Port usage:

| Port | Purpose |
|---|---|
| 8123 | HTTP interface, browser access, SQL Playground |
| 9000 | Native ClickHouse client protocol |

## Check Container Environment Variables

Command:

```bash
docker exec -it 5008640786a6 env
```

The following variables were checked:

```text
CLICKHOUSE_USER
CLICKHOUSE_PASSWORD
```

No ClickHouse username or password environment variables were configured.

Therefore, the container was using the default ClickHouse authentication configuration.

## Connect to ClickHouse Server

Command:

```bash
docker exec -it 5008640786a6 clickhouse-client
```

The connection output showed:

```text
Connecting to localhost:9000 as user default.
Connected to ClickHouse server version 26.6.1.
```

The ClickHouse server was running successfully.

## Verify Current User

SQL query:

```sql
SELECT currentUser();
```

Result:

```text
default
```

The active ClickHouse user was: `default`

## Inspect Default User Configuration

Command:

```sql
SHOW CREATE USER default;
```

Output:

```text
CREATE USER default
IDENTIFIED WITH plaintext_password
HOST LOCAL
SETTINGS PROFILE `default`
```

Important observations:

- The default user uses password authentication.
- The default user is restricted with `HOST LOCAL`.

`HOST LOCAL` allows connections only from inside the ClickHouse container.

## Check User Configuration File

The configuration file was inspected:

```bash
cat /etc/clickhouse-server/users.d/default-user.xml
```

Configuration:

```xml
<clickhouse>
  <users>
    <default>
      <networks>
        <ip>::1</ip>
        <ip>127.0.0.1</ip>
      </networks>
    </default>
  </users>
</clickhouse>
```

The default user was allowed only from:

- 127.0.0.1
- ::1

These are local loopback addresses.

## Authentication Problem

Opening:

```text
http://localhost:8123/play
```

returned:

```text
Code: 516
Authentication failed
```

Reason:

The browser connection comes from outside the container, while the default user only allows local connections.

| Connection Type | Result |
|---|---|
| clickhouse-client inside container | Successful |
| Browser SQL Playground | Failed |

## Create New User

A new user was created:

```sql
CREATE USER admin
IDENTIFIED BY 'admin123'
HOST ANY;
```

Result:

```text
Ok.
```

New user details:

| Property | Value |
|---|---|
| Username | admin |
| Password | admin123 |
| Allowed Host | ANY |

## Grant Permissions

The following command was attempted:

```sql
GRANT ALL ON *.* TO admin WITH GRANT OPTION;
```

It failed because the default user did not have permission to grant all available privileges.

The following command was successful:

```sql
GRANT CURRENT GRANTS ON *.* TO admin;
```

This copied the privileges available to the default user to the new admin user.

### What This Achieved

- Created a separate login user (`admin`) with its own password.
- Allowed external connections for `admin` because of `HOST ANY`.
- Copied current effective privileges from the session user to `admin`.

### What This Did Not Change

- `admin` is not a full superuser, because `GRANT ALL ... WITH GRANT OPTION` failed.
- The `default` user is still local-only unless explicitly altered.

## Final User Configuration

| User | Password | Access | Privilege Scope |
|---|---|---|---|
| default | Existing password | Local container only | Original/default session privileges |
| admin | admin123 | External access allowed | Copied via `GRANT CURRENT GRANTS` |

## Login to ClickHouse Web Interface

Open:

```text
http://localhost:8123/play
```

Use:

```text
Username: admin
Password: admin123
Database: default
```

## Useful Commands

Connect to ClickHouse:

```bash
docker exec -it 5008640786a6 clickhouse-client
```

Check users:

```sql
SHOW USERS;
```

Check permissions:

```sql
SHOW GRANTS FOR admin;
```

Check current user:

```sql
SELECT currentUser();
```

## Conclusion

The ClickHouse Docker installation was successful. The initial browser login failure occurred because the built-in `default` user was restricted to local connections only.

A new user named `admin` was created with a password and external access permission. This user can be used for browser-based access through ClickHouse SQL Playground.

The permission assignment gave `admin` the currently available grants from the session user, but did not make `admin` a full superuser.
