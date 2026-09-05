# CLAUDE.md

The rules for this repository live in [AGENTS.md](AGENTS.md); it is the single source of truth
for agents and contributors. Read it first and keep it updated instead of extending this file.

Quick pointers:

- This is the **OroCommerce demo site**: stock OroCommerce CE (branch `7.0.x` = upstream tag
  `7.0.4` + the Docker stack). Never customise the application code.
- Local stack (Docker only, never a server on the host): `make up`, then http://localhost:8092
  — see "Run it locally" in AGENTS.md.
- Default logins: back-office `admin` / `Admin1234!`; storefront demo customers use their e-mail
  as the password (`AmandaRCole@example.org`) — see "Default credentials" in AGENTS.md.
- Console: `make console CMD="cache:clear"` (runs `bin/console` inside the container as uid 1000).
- Demo data is installed automatically by `oro-install`; snapshots for fast deploys are made with
  `make dump` — see "Snapshots" in AGENTS.md.
- Deploy: `make prod-up` (Traefik) or `docker-compose.dokploy.yml` (Dokploy).
