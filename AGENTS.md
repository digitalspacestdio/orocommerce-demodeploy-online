# AGENTS.md — orocommerce-demodeploy-online

Rules and operating instructions for AI agents and contributors working in this repository.
This file is the single source of truth; `CLAUDE.md` only points here.

## What this repository is

The OroCommerce **demo site**: OroCommerce Community Edition, **unmodified**, installed with the
Oro demo data and deployed in Docker. Branch **`7.0.x`** is the upstream application tag
**`7.0.4`** plus the Docker stack in `docker/` and the compose files in the root — no application
code, bundle or theme is customised here.

Why it matters: the branch must stay rebasable onto a later `7.0.x` tag. Everything this
repository adds lives in files upstream does not ship, with one exception — the root
`docker-compose.yml`, which replaces the Symfony local-server file (still available as
`git show 7.0.4:docker-compose.yml`).

## Rules

- **Do not customise the application.** No bundles in `src/`, no theme overrides, no changes to
  `config/`, `composer.json`, `package.json` or anything else the upstream tag ships. A demo of
  stock OroCommerce is the whole point. If a demo needs a change, it is a configuration change
  (`oro:config:update`, an environment variable, or a setting made in the back-office and
  captured in a snapshot) — never a code change.
- **Branch from the tag.** `7.0.x` = tag `7.0.4` + this stack. To move to a newer patch release,
  rebase this branch onto the new tag; do not merge upstream `master` (it is 7.1).
- **English** in documentation, comments, commit messages and identifiers.
- **No secrets in git.** `.env` is ignored; `.env.example` holds defaults only. The demo admin
  password (`Admin1234!`) is a deliberate, published demo credential — never reuse it anywhere real.
- **Snapshots stay out of git** (`docker/orocommerce/dumps/` is ignored): they contain a full
  database. Publish the archive and point `ORO_DUMP_URL` at it.
- **Docker only.** Never run PHP, composer, pnpm or a web server directly on the host; every
  command goes through the containers (`make console CMD="…"`).

## Layout

```
AGENTS.md                     this file
CLAUDE.md                     pointer to AGENTS.md
docs/demo-stack.md            short human-facing description of the stack
docker-compose.yml            local stack (bind-mounted source, composer install in container)
docker-compose.prod.yml       Docker host + embedded Traefik (HTTPS via Let's Encrypt)
docker-compose.dokploy.yml    Dokploy (platform Traefik, no host ports)
docker/compose/
  infrastructure.yml          oro-db (PostgreSQL 17.6), mail (Mailpit), gotenberg (PDF)
  orocommerce.yml             local Oro services
  orocommerce.prod.yml        production Oro services (image with vendor and assets baked in)
  traefik-labels.yml          routing labels for oro-nginx
  traefik.prod.yml            embedded Traefik (docker-compose.prod.yml only)
docker/orocommerce/
  Dockerfile                  local runtime image (code bind-mounted)
  Dockerfile.prod             production image: code + vendor + built assets
  Dockerfile.nginx            nginx image carrying the built public/
  default.conf.template       nginx config (storefront, back-office, /ws websocket)
  entrypoint.sh               root → fix volume ownership → drop to uid 1000
  lib.sh                      shared helpers (DB parsing, console, public URL, assets, cache)
  install.sh                  idempotent installer, runs on every `up`
  dump.sh / restore.sh / dump-exists.sh   snapshots
  healthcheck.sh              php-fpm FastCGI ping
  php.ini, ofelia.conf        PHP overrides, cron (oro:cron every minute)
  dumps/                      snapshots (git-ignored)
.env.example                  every setting with its default
Makefile                      thin wrapper around the compose commands
```

Services: `oro-db`, `oro-fpm`, `oro-nginx` (public entry point), `oro-consumer` (message queue),
`oro-cron` (ofelia → `oro:cron` each minute), `oro-websocket`, `mail`, `gotenberg`.
Search runs on the ORM engine, sessions are files, the message queue is DBAL — no Elasticsearch,
no Redis, nothing extra to operate for a demo.

## Run it locally

```sh
make up            # or: docker compose up -d   (creates .env from .env.example)
make logs          # installer progress
```

First run: image build + `composer install` + `oro:install --sample-data=y`, 20-40 minutes.
With a snapshot present in `docker/orocommerce/dumps/demo/` it is ~5 minutes instead.

- Storefront <http://localhost:8092>
- Back-office <http://localhost:8092/admin>
- Mail <http://localhost:8026>
- PostgreSQL 127.0.0.1:5433 (`oro_db_user` / `oro_db_pass`)

Other targets: `make down` (stop, keep data), `make reset` (delete volumes and reinstall),
`make install` (re-run the installer), `make console CMD="cache:clear"`, `make dump`, `make restore`.

Oro in dev mode: set `ORO_ENV=dev` in `.env` and `docker compose up -d` again (slower, verbose
errors). Theme assets rebuild on change with `docker compose --profile assets up -d oro-assets-watch`.

## Default credentials

Demo credentials, published on purpose — never reuse them anywhere real.

**Back-office** (<http://localhost:8092/admin>, `/admin` on any host):

| Login | Password |
| --- | --- |
| `admin` | `Admin1234!` |

Created by `oro:install` from `ORO_USER_NAME` / `ORO_USER_PASSWORD` / `ORO_USER_EMAIL`
(`admin@example.com`). Change them in `.env` **before the first install** — afterwards the user
already exists, and the password has to be changed in the back-office or with
`make console CMD="oro:user:update admin"`. The demo data adds ~50 more back-office users; only
`admin` has a known password.

**Storefront** (<http://localhost:8092/customer/user/login>): the demo customer users all have
**the password equal to their e-mail**.

| Login = password | Customer | Role |
| --- | --- | --- |
| `AmandaRCole@example.org` | Company A | Administrator |
| `BrandaJSanborn@example.org` | Company A | Buyer |
| `NancyJSallee@example.com` | Wholesaler B | Administrator |
| `JuanaPBrzezinski@example.net` | Partner C | Administrator |

Twelve users come with the demo data; the full list with customers and roles is in
`vendor/oro/customer-portal/src/Oro/Bundle/CustomerBundle/Migrations/Data/Demo/ORM/data/customer-users.csv`,
or query it: `docker compose exec -T oro-db psql -U oro_db_user -d oro_db -c "select email from oro_customer_user"`.

## Configuration

All settings live in `.env` (copy of `.env.example`); every one of them also has a default in
`docker/compose/*.yml`, so an empty `.env` still produces a working demo.

| Variable | Meaning |
| --- | --- |
| `HTTP_PORT`, `ORO_APP_URL`, `ORO_PUBLIC_HOST`, `ORO_PUBLIC_HTTPS` | public address; the three must agree |
| `ORO_ENV` | `prod` (default) or `dev` |
| `ORO_SECRET` | Symfony secret; set a random value for a public deployment |
| `ORO_USER_NAME`, `ORO_USER_PASSWORD`, `ORO_USER_EMAIL`, `ORO_ORGANIZATION_NAME` | admin created by `oro:install` |
| `ORO_SAMPLE_DATA` | `y` (default) installs the Oro demo data |
| `ORO_INSTALL_MODE` | `auto` (default) / `install` / `restore` — see below |
| `ORO_DUMP_NAME`, `ORO_DUMP_URL` | snapshot to restore, local name or remote `.tar.gz` |
| `ORO_DB_*`, `MAIL_UI_PORT`, `HOST_UID`, `HOST_GID` | infrastructure |
| `TRAEFIK_*`, `ACME_EMAIL`, `ORO_IMAGE`, `ORO_NGINX_IMAGE` | production only |

**`.env` is read twice** — for `${VAR}` substitution in the compose files and as `env_file` of the
Oro containers. The `env_file` parser keeps everything after `=`, so **never write an inline
comment after a value** (`ORO_DUMP_URL=   # optional` makes the comment the value and the deploy
tries to download it). Comments go on their own line.

## How the demo data gets there

`oro-install` is a one-shot service that every other service waits for
(`condition: service_completed_successfully`). It is idempotent and runs on every `up`, so
deploying to an empty host produces a ready demo site without manual steps.

| `ORO_INSTALL_MODE` | Behaviour |
| --- | --- |
| `auto` (default) | restore a snapshot when one is available, otherwise `oro:install --sample-data=y` |
| `install` | always a fresh `oro:install` (skipped when the application is already installed) |
| `restore` | require a snapshot (`ORO_DUMP_NAME` under `/dumps`, or download `ORO_DUMP_URL`) |

Every mode then: generates the OAuth2 server keys, points `oro_ui.application_url`,
`oro_website.url` and `oro_website.secure_url` at `ORO_APP_URL`, builds the public assets when
missing, loads the cron definitions and warms the cache. In production (`ORO_SKIP_COMPOSER=1`)
the composer step is skipped because vendor is baked into the image.

## Snapshots (fast deploys)

A full `oro:install` with demo data takes 20-40 minutes; restoring a snapshot takes ~5.

```sh
make dump NAME=demo                                    # → docker/orocommerce/dumps/demo/
tar -C docker/orocommerce/dumps -czf demo.tar.gz demo  # ~42 MB, publish this archive
# deploy: ORO_INSTALL_MODE=restore  ORO_DUMP_URL=https://…/demo.tar.gz
```

A snapshot holds `db.sql.gz`, `files.tar.gz` (`public/media`, `var/data`), `assets.tar.gz`
(built `public/build`, `bundles`, `js` — restoring them skips the asset build) and `meta.json`
with the source URL. `oro-restore` rewrites that URL to `ORO_APP_URL` with `sed` while importing,
so one archive serves any host name. **Restoring replaces all data.**

Refresh the snapshot whenever the demo content changes: restore or install locally, adjust the
data in the back-office, then `make dump` and publish the new archive.

## Deploy

Plain Docker host, embedded Traefik:

```sh
# .env: ORO_APP_URL=https://demo.example.com  ORO_PUBLIC_HOST=demo.example.com
#       ORO_PUBLIC_HTTPS=on  ORO_SECRET=<random>  TRAEFIK_HOST_RULE=Host(`demo.example.com`)
#       TRAEFIK_DOCKER_NETWORK=orodemo-edge  ACME_EMAIL=ops@example.com
make prod-up        # docker compose -f docker-compose.prod.yml up -d --build
make prod-logs
```

Dokploy: use `docker-compose.dokploy.yml`, set the same variables in the project environment
(`TRAEFIK_DOCKER_NETWORK=dokploy-network`); the platform Traefik picks up the labels of
`oro-nginx`. Neither production file publishes host ports.

Production differences: the image carries code, vendor and built assets (`Dockerfile.prod`),
`ORO_SKIP_COMPOSER=1`, persistent volumes for `var/data` and `public/media`, and `mail`/`oro-db`
are internal only. Set a real `ORO_MAILER_DSN` if the demo must send mail.

Redeploy after a change to this repository: `make prod-up` again (rebuild + restart);
`oro-install` re-runs, sees the application installed and only re-applies URL, assets and caches.

## Console and debugging

```sh
make console CMD="oro:cron"                       # any bin/console command
docker compose exec -u 1000:1000 oro-fpm bash     # shell as the application user
docker compose logs -f oro-install oro-fpm oro-consumer
docker compose exec -T oro-db psql -U oro_db_user -d oro_db -c "select count(*) from oro_product"
```

Always run console commands as uid 1000; a command run as root leaves cache files the
application user cannot overwrite (the entrypoint repairs `var/` on the next start).

## Known gotchas

- **`var/data/oauth` must exist before composer runs.** One of the post-install scripts generates
  the OAuth2 keys at `ORO_OAUTH_PRIVATE_KEY_PATH` and does not create the directory;
  `install.sh` creates it up front. Do not remove that `mkdir`.
- **No inline comments in `.env`** (see Configuration above).
- **Host port conflicts.** The demo defaults to 8092 because 8090/8091 are used by other stacks on
  the development machine. Change `HTTP_PORT`, `ORO_APP_URL` and `ORO_PUBLIC_HOST` together.
- **A container left over from a failed `up`** can hold the published port and lose its network
  (`getent hosts oro-fpm` empty inside `oro-nginx`, nginx answers 502 with
  `oro-fpm could not be resolved`). Fix: `docker compose down` (keeps volumes), then `up -d`.
- **The first `up` takes 20-40 minutes** without a snapshot. `docker compose logs -f oro-install`
  is the only progress indicator; do not interrupt it.
