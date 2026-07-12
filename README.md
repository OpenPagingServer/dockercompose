# Open Paging Server — Docker Compose

Docker Compose setup for [Open Paging Server](https://github.com/OpenPagingServer/OpenPagingServer), a free & open source public address, bell, and mass notification system for VoIP infrastructure.

The Dockerfile downloads Open Paging Server directly from the project's install endpoint along with all endpoint modules and assets — no local clone required.

> **⚠️ Beta software** — Open Paging Server is not yet ready for production use.

## Quick Start

### 1. Set the MariaDB root password

```bash
cp .env.example .env
# Edit .env — only MARIADB_ROOT_PASSWORD is required
```

### 2. Build the image

```bash
docker compose build
```

To pin a specific release tag instead of `main`:

```bash
docker compose build --build-arg OPS_REF=v0.5.0
```

### 3. Initialize the database (first run only)

```bash
docker compose --profile init run --rm db-init
```

This runs the project's `database-initialization.py` script to create tables, generate a random database password, and seed defaults — just like the real installer. The credentials are stored in a shared Docker volume (`ops_env`) that the app container reads on startup.

### 4. Start the stack

```bash
docker compose up -d
```

Open Paging Server will be available at `http://localhost` (or the port you set in `.env`).

## Services

| Service   | Description                        | Default Port(s)                |
|-----------|------------------------------------|--------------------------------|
| `ops`     | Open Paging Server application     | 80, 443, 5060, 8088, 8710, 50010, 50011 |
| `db`      | MariaDB 11 database                | 3306 (internal only)           |
| `db-init` | One-shot database initialization   | —                              |

## Ports

| Port  | Protocol | Purpose              |
|-------|----------|----------------------|
| 80    | TCP      | Web UI               |
| 443   | TCP      | Web UI (HTTPS)       |
| 5060  | TCP/UDP  | SIP                  |
| 8088  | TCP      | REST API             |
| 8710  | TCP      | Multicast Gateway    |
| 50010 | TCP      | Live Page WebSocket  |
| 50011 | TCP      | Desktop Client IPC   |

## Volumes

| Volume             | Container Path                              | Purpose                        |
|--------------------|---------------------------------------------|--------------------------------|
| `db_data`          | `/var/lib/mysql`                            | Database storage               |
| `ops_env`          | `/opt/ops-env`                              | Generated .env (from db-init)  |
| `assets`           | `/var/lib/openpagingserver/assets`           | Audio assets                   |
| `endpoint_modules` | `/var/lib/openpagingserver/endpointmodules`  | Endpoint modules               |
| `trusted_ca`       | `/etc/openpagingserver/trustedca`            | Trusted CA certs               |

## Upgrading

Rebuild the image (optionally with a new ref) and restart:

```bash
docker compose build --build-arg OPS_REF=main
docker compose up -d
```

## Installing Endpoint Modules

Endpoint module `.opsepm` files can be placed into the `endpoint_modules` volume. You can copy them in with:

```bash
docker compose cp ./my-module.opsepm ops:/var/lib/openpagingserver/endpointmodules/
```

Then restart the `ops` service for them to be loaded.
