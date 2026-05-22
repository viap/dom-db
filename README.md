# dom-db

`dom-db` provisions the MongoDB stack used by the DOM project. It includes:

- MongoDB 8.0 (pinned to `mongo:8.0`)
- `mongo-express` for web-based database access
- persistent external Docker volumes for database storage
- one-time database initialization through [mongo-init.js](./mongo-init.js)

This repository is focused on practical day-to-day operations: starting the stack, stopping it, creating dumps, and restoring data.

## Environment Variables

Create a local `.env` file with the variables expected by [docker-compose.yml](./docker-compose.yml):

```env
MONGO_INITDB_ROOT_USERNAME=
MONGO_INITDB_ROOT_PASSWORD=
ME_CONFIG_BASICAUTH_USERNAME=
ME_CONFIG_BASICAUTH_PASSWORD=
MONGO_EXPRESS_OUTPUT_PORT=
```

Do not copy production secrets into documentation or commit them to the repository.

## Prerequisites

- Docker and Docker Compose installed locally
- External Docker volumes `domDB` and `domDBConfig` created before startup
- A populated `.env` file in the project root

## First-Time Setup

Create the external volumes if they do not already exist:

```bash
docker volume create domDB
docker volume create domDBConfig
```

If you need existing data, restore it from a dump before using the stack normally.

## Start

Run the containers in detached mode:

```bash
docker-compose up -d
```

## Stop

Stop and remove the running containers:

```bash
docker-compose down
```

## Access

- MongoDB is exposed on `127.0.0.1:27017`
- `mongo-express` is exposed on `http://localhost:<MONGO_EXPRESS_OUTPUT_PORT>`
- Container names:
  - MongoDB: `mongodb`
  - Admin UI: `mongo-express`

## Dump and Restore

Create a database dump:

```bash
docker exec -i mongodb /usr/bin/mongodump \
  --username <USER> \
  --password <PASSWORD> \
  --authenticationDatabase admin \
  --db <DB_NAME> \
  --archive > <ARCHIVE_FILE_PATH>
```

Restore a database from a dump:

```bash
docker exec -i mongodb /usr/bin/mongorestore \
  --username <USER> \
  --password <PASSWORD> \
  --authenticationDatabase admin \
  --nsInclude="<DB_NAME>.*" \
  --archive < <ARCHIVE_FILE_PATH>
```

Restore a gzipped archive:

```bash
gunzip -c <ARCHIVE_FILE_PATH>.gz | docker exec -i mongodb mongorestore \
  --username <USER> \
  --password '<PASSWORD>' \
  --authenticationDatabase admin \
  --archive \
  --gzip
```

## Restore Into a Different Database Name

Use namespace remapping when the source and target database names differ:

```bash
docker exec -i mongodb /usr/bin/mongorestore \
  --username <USER> \
  --password <PASSWORD> \
  --authenticationDatabase admin \
  --nsFrom="<OLD_NAME>.*" \
  --nsTo="<NEW_NAME>.*" \
  --archive < <ARCHIVE_FILE_PATH>
```

## Notes

- The init script in `/docker-entrypoint-initdb.d` only runs the first time the MongoDB data directory is initialized.
- The `domDB` and `domDBConfig` volumes are marked as external in [docker-compose.yml](./docker-compose.yml), so startup will fail if they do not already exist.
- Never start this stack with a lower MongoDB major version than the one that last wrote to `domDB` (for example, do not run MongoDB 7 against data already upgraded to FCV 8.0).
- Do not run `docker compose down -v` unless you intentionally want to destroy local database volumes and data.
- `.env.prod` is intended for deployment and runtime handling. Treat it as an operational reference, not something to reproduce inside the README.

## Legacy Reference

Older Russian-language operational notes are preserved in [docs/archive/README](./docs/archive/README) for historical reference.
