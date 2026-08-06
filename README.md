# MusicBrainz Docker — Automated Mirror Deployment

Forked from https://github.com/metabrainz/musicbrainz-docker.

This fork removes the manual `docker compose exec`/`run` setup steps and replaces
them with a single `init` service that runs once on first deployment.

## What changed

- Removed manual-only setup instructions from the README.
- Removed hardcoded workstation paths; all persistent directories are
  parameterized via `HOST_DATA_PATH`, `HOST_CONFIG_PATH`, and `HOST_SECRETS_PATH`.
- Removed development-only services/files (`build/musicbrainz-dev`,
  `build/sir-dev`, `compose/musicbrainz-dev.yml`, `compose/sir-dev.yml`, etc.).
- Removed committed default secrets; `POSTGRES_PASSWORD` and the replication
  token must be supplied by the operator.
- Added an `init` service that:
  1. Waits for `db`, `search`, and `valkey` to be healthy.
  2. Creates/fetches the PostgreSQL dump (`createdb.sh -fetch`).
  3. Fetches and loads pre-built Solr indexes.
  4. Removes downloaded archives.
  5. Writes the replication token from `REPLICATION_TOKEN` or a mounted secret.
  6. Activates the replication crontab.
  7. Writes `/var/lib/musicbrainz/.init-complete` so the step is idempotent.

## Required environment variables

|             Variable            |                Purpose                         |
|---------------------------------|------------------------------------------------|
| `HOST_DATA_PATH`                | Base host directory for all persistent data    |
| `HOST_CONFIG_PATH`              | Base host directory for config overrides       |
| `HOST_SECRETS_PATH`             | Base host directory for secrets                |
| `POSTGRES_PASSWORD`             | PostgreSQL superuser password                  |
| `POSTGRES_VERSION`              | PostgreSQL major version (used as image tag)   |
| `MB_SOLR_VERSION`               | Solr search server version (used as image tag) |
| `MUSICBRAINZ_BASE_DOWNLOAD_URL` | Base URL for dumps and indexes                 |
| `REPLICATION_TOKEN`             | MetaBrainz replication access token            |

## Optional environment variables

|                 Variable               |                Default                |
|----------------------------------------|---------------------------------------|
| `POSTGRES_USER`                        | `musicbrainz`                         |
| `POSTGRES_DB`                          | `musicbrainz`                         |
| `MUSICBRAINZ_POSTGRES_SERVER`          | `db`                                  |
| `MUSICBRAINZ_POSTGRES_READONLY_SERVER` | `db`                                  |
| `MUSICBRAINZ_VALKEY_SERVER`            | `valkey`                              |
| `SIR_CONFIG_PATH`                      | `/code/config.ini`                    |
| `MUSICBRAINZ_CRONTAB_PATH`             | `/etc/cron.d/musicbrainz-replication` |
| `MUSICBRAINZ_BASE_FTP_URL`             | empty                                 |
| `MUSICBRAINZ_WEB_SERVER_HOST`          | `localhost`                           |
| `MUSICBRAINZ_WEB_SERVER_PORT`          | `5000`                                |
| `MUSICBRAINZ_SERVER_PROCESSES`         | `10`                                  |

## Standalone testing (Part 1)

1. Clone your fork and create directories:

```bash
export HOST_DATA_PATH=/srv/musicbrainz/data
export HOST_CONFIG_PATH=/srv/musicbrainz/config
export HOST_SECRETS_PATH=/srv/musicbrainz/secrets
sudo mkdir -p \
  "${HOST_DATA_PATH}"/{db,search,valkey,dbdump,solrdump,musicbrainz} \
  "${HOST_CONFIG_PATH}" \
  "${HOST_SECRETS_PATH}"
sudo cp default/indexer.ini "${HOST_CONFIG_PATH}/indexer.ini"
sudo cp default/replication.cron "${HOST_CONFIG_PATH}/replication.cron"
printf '%s' 'YOUR_TOKEN' > "${HOST_SECRETS_PATH}/metabrainz_access_token"
