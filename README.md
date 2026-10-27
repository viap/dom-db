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
- `mongo-express` is published on `<MONGO_EXPRESS_OUTPUT_PORT>` on all interfaces (in production `8180`, reachable from the internet behind HTTP basic auth). Docker-published ports bypass ufw. Planned hardening: bind it to `127.0.0.1` and publish it through nginx with TLS; do not change the binding before that proxy exists, or the UI is only reachable over an SSH tunnel
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

## Automated Backups (production)

Production backups run on the `dom` host from `/root/scripts/mongo_backup.sh`
(root crontab, daily at 03:15, log in `/var/log/mongo-backup/`). The script is
not in this repository; a copy of the previous version is
`/root/scripts/mongo_backup.sh.bak`.

What it does:

1. `mongodump --archive --gzip` of all databases from the `mongodb` container
   into `/root/backups/mongodb/mongo_<host>_<date>.archive.gz` (kept 7 days).
2. Uploads the dump to Google Drive with rclone: `gdrive-crypt:mongodb`.
3. Verifies the upload with `rclone cryptcheck` and fails the run on mismatch.
4. Deletes remote copies older than 30 days (Drive keeps them 30 more days in
   its trash).

Off-host storage:

- `gdrive` is an rclone Google Drive remote using its own OAuth client (Desktop
  app) in the Google Cloud project `dom-backups`, published, scope `drive.file`
  (rclone sees only files it created). Its `root_folder_id` is the
  `dom-backups` folder, currently inside the Drive folder `DOM`; the folder can
  be moved in Drive without changing rclone.
- `gdrive-crypt` is an rclone `crypt` remote over `gdrive:`. File contents and
  names are encrypted; Google only stores ciphertext.
- The rclone config and both crypt passwords (`password`, `password2`) are kept
  in the team password manager. Without them the backups cannot be decrypted.
  Never commit them or paste them into chats.

Restore from Google Drive (on any machine with the saved rclone config):

```bash
rclone ls gdrive-crypt:mongodb
rclone copy gdrive-crypt:mongodb/<file>.archive.gz /tmp/restore/
gzip -t /tmp/restore/<file>.archive.gz
docker exec -i mongodb mongorestore -u <USER> -p '<PASSWORD>' \
  --authenticationDatabase admin --archive --gzip --drop \
  --nsInclude='domData.*' < /tmp/restore/<file>.archive.gz
```

`--drop` replaces the existing collections; restore into another database name
first (see above) when in doubt.

Periodic check (every few months, writes nothing): copy the newest dump from
`gdrive-crypt:mongodb`, run `gzip -t`, then `mongorestore --archive --gzip
--dryRun` against it.

If the Google token stops working (`invalid_grant`): `rclone config reconnect
gdrive:`, answer `n` to the browser question, run the printed `rclone authorize`
command on a machine with a browser and paste the token back.

## Notes

- The init script in `/docker-entrypoint-initdb.d` only runs the first time the MongoDB data directory is initialized.
- The `domDB` and `domDBConfig` volumes are marked as external in [docker-compose.yml](./docker-compose.yml), so startup will fail if they do not already exist.
- Never start this stack with a lower MongoDB major version than the one that last wrote to `domDB` (for example, do not run MongoDB 7 against data already upgraded to FCV 8.0).
- Do not run `docker compose down -v` unless you intentionally want to destroy local database volumes and data.
- `.env.prod` is intended for deployment and runtime handling. Treat it as an operational reference, not something to reproduce inside the README.

## Legacy Reference

Older Russian-language operational notes are preserved in [docs/archive/README](./docs/archive/README) for historical reference.
