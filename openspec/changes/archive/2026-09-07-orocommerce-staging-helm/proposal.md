## Why

The OroCommerce demo site currently ships as a local Docker Compose stack plus two
single-host deploy variants (`docker-compose.prod.yml` with embedded Traefik,
`docker-compose.dokploy.yml`). None of these targets a Kubernetes cluster. Parent
issue DIG-3000 asks for the demo to be reachable at
`https://orocommerce.demodeploy.online` on the demodeploy staging cluster, which
requires a Helm chart and a k8s-shaped bootstrap/config path that does not exist
today. DIG-3001's read-only investigation supplied the concrete facts (topology,
reusable assets, gaps, risks, open questions) this proposal turns into a spec.

## What Changes

- Add a multi-workload Helm chart under `deploy/charts/orocommerce/` (web/nginx,
  php-fpm, message-queue consumer, cron, websocket, Mailpit, Gotenberg — no
  Redis/Elasticsearch, matching the stock demo topology) plus a staging values
  file `deploy/releases/orocommerce-staging.values.yaml`.
- Reuse the existing `Dockerfile.prod` / `Dockerfile.nginx` images as the deploy
  unit; no new Dockerfile. Tagging becomes deterministic (git SHA or app version),
  not the current floating `orocommerce-demo:7.0.4` / `orocommerce-demo-nginx:7.0.4`
  local names.
- Add a one-shot Kubernetes Job (Helm hook) that runs `install.sh` in
  `ORO_INSTALL_MODE=restore` against a published `ORO_DUMP_URL` snapshot, replacing
  ad hoc compose-time `oro-install`. The Job is idempotent/re-runnable and does not
  destroy data on repeat runs against an already-installed PVC.
- Add PVCs for Postgres data, `var/data`, and `public/media`; emptyDir for
  cache/sessions/dump-scratch, matching the AS-IS persistence split in the
  investigation.
- Add configmap/secret-driven environment covering the full key surface in
  investigation section 5 (public URL/websocket DSNs, DB DSN, `ORO_SECRET`,
  install-mode/dump keys, mailer/MQ/session/search DSNs pinned to
  Mailpit/DBAL/ORM, Gotenberg URL) — no values committed to the repo.
- Add staging-safety configuration: forced Mailpit/blackhole mailer DSN,
  `X-Robots-Tag: noindex, nofollow` (or `Disallow: /` in `robots.txt`) at the
  ingress/nginx layer, ingress-nginx + Cloudflare-terminated TLS per the
  demodeploy convention, and an explicit, PO-decided policy for the public demo
  admin/storefront credentials on a publicly reachable host.
- **BREAKING**: none — this is new deployment configuration; no application code,
  `composer.json`, or existing compose file changes.

Explicitly out of scope for this change (flagged as open questions, not decided
here — see design.md and tasks.md):
- Who publishes the demo snapshot archive and the canonical `ORO_DUMP_URL`.
- Which container registry hosts the built images.
- Whether Gotenberg ships in v1 staging or is deferred.
- Whether the Mailpit UI gets any ingress exposure for QA.
- Final decision on rotating vs. keeping the public demo admin password.
- Actually running `helm`/`kubectl` or deploying — that is Birdperson's child of
  DIG-3000, out of this repo-side change.

## Capabilities

### New Capabilities
- `staging-deployment`: Kubernetes/Helm deployment shape for the OroCommerce demo
  site on the demodeploy staging cluster — workloads, persistence, configuration
  surface, bootstrap, and staging-safety requirements.

### Modified Capabilities
(none — no existing `openspec/specs/` capabilities in this repo yet)

## Impact

- New files only, all under paths upstream OroCommerce does not ship (repo rule:
  never customise the application):
  - `deploy/charts/orocommerce/**` (new Helm chart)
  - `deploy/releases/orocommerce-staging.values.yaml` (new staging values)
  - Possibly a small nginx template variant for k8s Service DNS (see design.md
    gap on Docker embedded DNS vs. kube-dns), added as a new template file, not
    an edit to the existing `docker/orocommerce/default.conf.template` used by
    compose.
- No changes to `docker-compose*.yml`, `Dockerfile*`, `composer.json`,
  `package.json`, or anything under `src/`/`config/` that upstream ships.
- Downstream: DIG-3003 (Implement child) builds/pushes the image, authors the
  chart and values file, and opens a PR with `helm lint`/`helm template`
  evidence — no cluster access needed for that PR. Actual `helm`/`kubectl`
  execution against the demodeploy cluster is Birdperson's separate Deploy
  child of DIG-3000.
