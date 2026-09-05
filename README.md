# OroCommerce demo site

Stock **OroCommerce Community Edition** with the Oro demo data, packaged as a Docker stack for a
public demo site. The application itself is the upstream sample application
([oroinc/orocommerce-application](https://github.com/oroinc/orocommerce-application)) — branch
`7.0.x` is its tag `7.0.4` plus the Docker stack in `docker/` and the compose files in the root.
No bundle, theme or configuration of the application is customised.

## Quick start

```sh
make up      # or: docker compose up -d   (creates .env from .env.example)
make logs    # installer progress
```

The first run installs OroCommerce with demo data (20-40 minutes); with a snapshot in
`docker/orocommerce/dumps/demo/` it takes about five.

| | |
| --- | --- |
| Storefront | <http://localhost:8092> |
| Back-office | <http://localhost:8092/admin> |
| Mail (Mailpit) | <http://localhost:8026> |

Logins: **`admin` / `Admin1234!`** for the back-office; storefront demo customers use their
e-mail as both login and password, for example `AmandaRCole@example.org`.

## Deploy

```sh
make prod-up                                        # Docker host, embedded Traefik + HTTPS
docker compose -f docker-compose.dokploy.yml up -d  # Dokploy, platform Traefik
```

Set `ORO_APP_URL`, `ORO_PUBLIC_HOST`, `ORO_PUBLIC_HTTPS`, `ORO_SECRET` and `TRAEFIK_HOST_RULE` in
`.env` first. Demo data is installed on every fresh environment automatically; `make dump` creates
a snapshot that `ORO_DUMP_URL` restores in minutes instead.

## Documentation

- [AGENTS.md](AGENTS.md) — rules, configuration, credentials, snapshots, deploy, troubleshooting
- [docs/demo-stack.md](docs/demo-stack.md) — short description of the stack
- [Upstream sample application](https://github.com/oroinc/orocommerce-application) — the
  application this branch is based on, and its other distributions
- [OroCommerce documentation](https://doc.oroinc.com)

## License

[OSL-3.0](LICENSE), Oro Inc. — the same license as the upstream application.
