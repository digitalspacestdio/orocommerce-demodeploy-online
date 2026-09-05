## Context

See proposal.md - Why/What Changes. Facts below are from DIG-3001's investigation
document (read-only analysis, referenced by section number).

- Stock demo topology (investigation §1): nginx, php-fpm, Postgres 17.6, MQ
  consumer, cron, websocket, Mailpit, Gotenberg. No Redis, no Elasticsearch —
  sessions are `native:`, search/MQ are ORM/DBAL.
- `Dockerfile.prod` + `Dockerfile.nginx` already build immutable, non-bind-mount
  images with vendor/assets baked in, uid 1000, `php-fpm -R` entrypoint, FastCGI
  healthcheck (investigation §2). These are the only images this change builds
  from — no new Dockerfile.
- `install.sh` supports `auto`/`install`/`restore` modes; `restore` takes
  ~5 minutes vs. 20-40 minutes for `oro:install --sample-data=y` (investigation
  §3). No demo snapshot archive exists in the repo today (git-ignored,
  directory empty).
- Persistence split (investigation §4): Postgres, `var/data`, `public/media`
  must be PVCs; cache/sessions/dump-scratch are safely ephemeral.
- demodeploy staging convention (per deploy-ownership / demodeploy-staging
  skill referenced in the investigation): ingress-nginx + Cloudflare-terminated
  TLS, not the repo's embedded Traefik.

## Goals / Non-Goals

**Goals:**
- Define a Helm chart shape that maps 1:1 onto the existing multi-workload
  compose topology, reusing the prod images and scripts as-is.
- Define exactly which environment keys the staging values file must set,
  without inventing new configuration surface beyond what `install.sh`/
  `lib.sh`/the prod compose already read.
- Define the bootstrap Job so it is idempotent and safe to re-run without a
  human remembering not to.
- Make the staging-safety posture (mail, crawl, credentials) an explicit,
  reviewable configuration rather than an implicit side effect of copying
  compose env defaults.

**Non-Goals:**
- Deciding registry coordinates, dump-hosting infrastructure, or CI that
  builds/pushes the image — those are Delivery Ops/Birdperson concerns
  (investigation §8, open questions 1-2) and are tracked as open questions
  below, filled in as values at implement/deploy time, not part of this
  chart's design.
- Running `helm`/`kubectl` or performing the actual deploy — Birdperson's
  separate Deploy child of DIG-3000.
- Changing the demo's stock topology (e.g. introducing Redis/Elasticsearch,
  multi-replica web) — out of scope; single-replica everywhere per
  investigation §4 recommendation.
- Resolving the public-credentials policy question — a PO/business decision
  (investigation §7, §8 open question 5), captured here as a chart capability
  (values can rotate the admin password via the bootstrap Job) but not decided.

## Decisions

### 1. Chart shape: one custom multi-workload chart, not the demodeploy `webapp` chart

The stock demodeploy `webapp` chart is single-container (investigation §2 gap).
This demo needs five long-running workloads (nginx, php-fpm, consumer, cron,
websocket) plus two support services (Mailpit, optionally Gotenberg) sharing
config and two of them sharing PVCs. Bolting that onto `webapp` via sidecars
would hide the process boundaries the compose stack deliberately keeps separate
(investigation §6: `init: true` per-process reaping) and make independent
restart/scaling of the consumer/cron/websocket impossible.

**Decision:** author `deploy/charts/orocommerce/` as its own chart with one
Deployment per long-running workload, a Job for install/restore, and a
`_helpers.tpl` shared env/label block so the five workloads stay in sync.

Alternative considered: extend `webapp` with `extraContainers`. Rejected —
investigation flags this as "insufficient" and it would make cron/consumer
restarts affect the web pod's readiness, which compose does not do today.

### 2. Image: reuse `Dockerfile.prod`/`Dockerfile.nginx` unchanged, deterministic tag only

No new Dockerfile. The only change is how the tag is produced: replace the
floating local name `orocommerce-demo:7.0.4` with `<registry>/<repo>:<git-sha>`
(or a semver+build-metadata tag), so a staging release pins an exact, reusable
image rather than "whatever was last built locally." Registry coordinates are
an open question (investigation §8 Q2) — the chart takes the full image
reference as a value, not a hardcoded registry host.

### 3. Bootstrap: Kubernetes Job running `install.sh` in `restore` mode, gated by an `oro_is_installed` check

Investigation §3 recommendation: staging restores a published snapshot rather
than running `oro:install` at deploy time (20-40 min exceeds Helm `--wait`
patience). The Job:
- Runs the existing `install.sh`/`restore.sh`/`lib.sh` unmodified (already
  idempotent for the "already installed" case per `lib.sh`'s `oro_is_installed`
  guard), with `ORO_INSTALL_MODE=restore`.
- Mounts the same PVCs (`var/data`, `public/media`) and talks to the same
  Postgres Service the fpm/consumer/cron/websocket pods use, so a re-run against
  an already-restored PVC does not silently wipe data — `restore` mode replaces
  data by design (investigation §3), so the chart additionally exposes an
  `bootstrap.forceRestore` value (default `false`) that the Job command respects
  by skipping restore when `oro_is_installed` is true and the flag is false.
- Runs as a Helm `pre-upgrade,pre-install` hook Job (not a long-running
  Deployment), matching the compose `condition: service_completed_successfully`
  shape (investigation §2 gap row 2).

Alternative considered: run install inline in the fpm container's entrypoint
on every pod start. Rejected — races multiple fpm replicas/restarts against
one restore, and reruns become invisible to `helm --wait`.

### 4. Networking: kube Service DNS replaces Docker embedded DNS in the nginx template

`default.conf.template` currently resolves `oro-fpm`/`oro-websocket` via the
Docker embedded resolver `127.0.0.11` (investigation §2 gap row 3). The chart
ships a k8s-specific nginx config (new file under
`deploy/charts/orocommerce/files/`, not an edit to the compose template) using
the in-cluster `kube-dns`/`coredns` resolver and the chart's own Service names
for the fpm and websocket upstreams. The compose template is untouched — it
still serves local/prod compose use unchanged, satisfying "no edits to files
upstream ships or existing compose assets."

### 5. Websocket DSNs: HTTPS-public, Cloudflare-terminated

`ORO_WEBSOCKET_FRONTEND_DSN` must resolve to the public `wss://` endpoint
proxied through ingress-nginx + Cloudflare at `/ws`, matching the prod compose
pattern (`//*:443/ws`) since Cloudflare always presents HTTPS externally even
though the ingress itself terminates plain HTTP behind Cloudflare (investigation
§5, §8 risk row "Websocket behind Cloudflare"). `ORO_WEBSOCKET_BACKEND_DSN`
points at the in-cluster websocket Service (`tcp://<release>-websocket:8080`);
`ORO_WEBSOCKET_SERVER_DSN` binds `//0.0.0.0:8080` inside the pod.

### 6. Staging safety as chart values, not tribal knowledge

- `ORO_MAILER_DSN` is hardcoded in the staging values to the in-cluster Mailpit
  Service — never templated from a "real SMTP" value, so a values-file mistake
  can't leak outbound mail (investigation §7).
- Ingress template always sets `X-Robots-Tag: noindex, nofollow` on staging
  (chart default `robots.noindex: true`), plus ships a staging `robots.txt`
  override (`Disallow: /`) mounted over the baked-in `config/robots.txt.dist`
  behavior — stronger than the upstream default which allows storefront crawl.
- The bootstrap Job supports an optional `admin.rotatePassword` value (default
  `false`) that, when true and a `Secret` key is present, runs
  `oro:user:update` after restore to rotate the admin password. Whether to
  enable it is the PO's call (investigation §8 open question 5) — the
  capability exists in the chart either way so the decision is a values change,
  not a code change.
- Gotenberg and Mailpit UI are both ClusterIP-only by default; no public
  Ingress resource is created for either unless a values flag explicitly
  requests it (deferred to PO per open questions 6-7).

## Risks / Trade-offs

- [Doctrine `database_server_version: '13.7'` hardcoded in upstream
  `config/config.yml:10` vs. Postgres 17.6 image] → Not an application code
  change we can make (repo rule). Mitigation: pin the chart's Postgres DSN with
  an explicit `serverVersion=17.6` query parameter (already the compose
  pattern per investigation §1) and flag this as a spike item in tasks.md if
  restore-time behavior differs.
- [No published snapshot archive exists yet] → The bootstrap Job's `restore`
  path has nothing to restore until Delivery Ops publishes one. Mitigation:
  chart supports `bootstrap.installMode: install` as an explicit fallback value
  (accepting the 20-40 min cost) so the chart is usable before the snapshot
  pipeline exists; tasks.md tracks the snapshot publication as a named
  prerequisite, not an assumption.
- [Re-running `restore` wipes data] → Mitigated by decision 3's
  `oro_is_installed` guard; documented as a chart value, not implicit.
- [Chart complexity — multi-hour platform build] → Per repo confirmation-gate
  policy this proposal is being routed through board/CEO confirmation before
  DIG-3003 implementation starts (see handoff comment on DIG-3003/DIG-3002);
  this is a process control, not a design decision, so it is not itself an
  open question here.
- [Postgres `shared_buffers=512MB`/`shm 512m` + PHP `memory_limit=2G` +
  opcache `512m`] → Cluster resource headroom (investigation §8 risk row,
  open question 4) is unknown until Birdperson checks demodeploy node
  capacity. Chart exposes these as `resources.requests/limits` values with the
  compose numbers as documented defaults, not hardcoded, so they can be tuned
  without a chart change.

## Migration Plan

Not applicable in the rollback sense — this is a net-new deployment target,
not a migration of existing staging state. Rollout sequencing for
DIG-3003/Birdperson:
1. Publish image to the agreed registry (open question 2) and a demo snapshot
   to the agreed `ORO_DUMP_URL` (open question 1) — prerequisites, not part of
   this chart.
2. `helm install` runs the bootstrap Job (`restore` mode) before/with the
   Deployments' first rollout (Helm hook ordering).
3. Subsequent `helm upgrade` re-runs the Job; the `oro_is_installed` guard
   makes it a no-op unless `bootstrap.forceRestore=true`.
Rollback: `helm rollback` to the prior release; PVCs are not deleted by a
rollback, so data persists across chart-version rollbacks (only a values
change to `forceRestore` can destroy data, which is the intended safety
boundary).

## Open Questions

These are genuinely deferrable — they fill in values or infrastructure the
chart already has a slot for; none changes the chart shape, the approach above,
or the task breakdown:

1. Who publishes the first `demo.tar.gz` snapshot and what is the canonical
   `ORO_DUMP_URL`? (Delivery Ops/Birdperson — investigation §8 Q1)
2. Container registry + image repository names for the app/nginx images?
   (Delivery Ops/Birdperson — investigation §8 Q2)
3. Is Gotenberg in scope for v1 staging or deferred? (PO — investigation §8 Q6)
4. Is the Mailpit UI exposed for QA or ClusterIP-only? (PO — investigation §8 Q7)
5. Public demo credentials accepted as-is on `orocommerce.demodeploy.online`,
   or rotate admin + harden `/admin`? (PO — investigation §8 Q5; chart supports
   either via `admin.rotatePassword`)
6. Cluster resource headroom for the Postgres/PHP footprint above? (Birdperson
   — investigation §8 Q4; chart values are tunable either way)
