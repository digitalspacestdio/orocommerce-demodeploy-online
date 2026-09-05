# Demo stack (Docker)

OroCommerce Community Edition 7.0.4, unmodified, with the Oro demo data, running entirely in
Docker. Branch `7.0.x` is the application tag `7.0.4` plus this stack — no application code is
customised, so the branch can be rebased onto a later 7.0.x tag at any time.

## Layout

| Path                              | Purpose                                                        |
| --------------------------------- | -------------------------------------------------------------- |
| `docker-compose.yml`              | local stack (bind-mounted source, composer install in container) |
| `docker-compose.prod.yml`         | deploy on a Docker host, embedded Traefik with Let's Encrypt     |
| `docker-compose.dokploy.yml`      | deploy on Dokploy (platform Traefik, no host ports)              |
| `docker/compose/*.yml`            | service fragments included by the files above                    |
| `docker/orocommerce/Dockerfile`   | dev image (code bind-mounted)                                    |
| `docker/orocommerce/Dockerfile.prod` | production image: code, vendor and built assets baked in      |
| `docker/orocommerce/Dockerfile.nginx` | nginx image carrying the built `public/`                    |
| `docker/orocommerce/install.sh`   | idempotent installer run on every `up` (see below)               |
| `docker/orocommerce/dump.sh` / `restore.sh` | snapshot and restore database, media and assets        |
| `.env.example`                    | every setting with its default                                   |

Services: `oro-db` (PostgreSQL 17.6), `oro-fpm`, `oro-nginx`, `oro-consumer` (message queue),
`oro-cron` (ofelia → `oro:cron` each minute), `oro-websocket`, `mail` (Mailpit), `gotenberg` (PDF).
Search runs on the ORM engine, sessions are file-based, the message queue uses DBAL — no extra
infrastructure to operate for a demo.

## Local

```sh
cp .env.example .env          # optional, `make up` does it for you
make up                       # or: docker compose up -d
make logs                     # installer progress: composer install + oro:install (20-40 min)
```

- Storefront: <http://localhost:8092> — demo customers log in with their e-mail as login *and*
  password, e.g. `AmandaRCole@example.org` (Company A, administrator)
- Back-office: <http://localhost:8092/admin> — `admin` / `Admin1234!`
- Mail: <http://localhost:8026>

The full credential list is in [../AGENTS.md](../AGENTS.md#default-credentials).

`make reset` deletes all volumes and reinstalls; `make console CMD="cache:clear"` runs a console
command inside the container.

## Deploy

```sh
# .env: ORO_APP_URL=https://demo.example.com  ORO_PUBLIC_HOST=demo.example.com
#       ORO_PUBLIC_HTTPS=on  ORO_SECRET=<random>  TRAEFIK_HOST_RULE=Host(`demo.example.com`)
#       TRAEFIK_DOCKER_NETWORK=orodemo-edge  ACME_EMAIL=ops@example.com
make prod-up                  # docker compose -f docker-compose.prod.yml up -d --build
```

On Dokploy use `docker-compose.dokploy.yml` instead and set the same variables in the project
environment; the platform Traefik picks up the labels of `oro-nginx`.

## How the demo data gets there

`oro-install` is a one-shot service that every other service waits for. It is idempotent and runs
on each `up`, so a deploy on an empty host produces a ready demo site:

| `ORO_INSTALL_MODE` | Behaviour                                                                   |
| ------------------ | --------------------------------------------------------------------------- |
| `auto` (default)   | restore a snapshot if one is available, otherwise `oro:install --sample-data=y` |
| `install`          | always a fresh `oro:install` (skipped when the application is already installed) |
| `restore`          | require a snapshot (`ORO_DUMP_NAME` under `/dumps`, or download `ORO_DUMP_URL`) |

After installing or restoring it always: generates the OAuth2 server keys, points
`oro_ui.application_url` / `oro_website.url` at `ORO_APP_URL`, builds the public assets when
missing, loads the cron definitions and warms the cache.

A full `oro:install` with demo data takes 20-40 minutes. To make deploys fast, snapshot a
finished instance once and let the deploy restore it:

```sh
make dump NAME=demo                                   # → docker/orocommerce/dumps/demo/
tar -C docker/orocommerce/dumps -czf demo.tar.gz demo # publish this archive
# on the server: ORO_INSTALL_MODE=restore  ORO_DUMP_URL=https://.../demo.tar.gz
```

The restore rewrites the URL stored in the snapshot to `ORO_APP_URL`, so the same archive works
for any host name.
