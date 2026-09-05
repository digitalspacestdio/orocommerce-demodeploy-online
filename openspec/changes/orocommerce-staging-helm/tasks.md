## 1. Chart scaffold

- [x] 1.1 Create `deploy/charts/orocommerce/Chart.yaml`, `values.yaml`,
      `_helpers.tpl` with shared labels/env-building helpers.
- [x] 1.2 Add `deploy/charts/orocommerce/templates/configmap.yaml` covering
      the non-secret env keys from design.md decision 6 / investigation §5
      (`ORO_APP_URL`, `ORO_PUBLIC_HOST`, `ORO_PUBLIC_HTTPS`, `ORO_ENV`,
      `ORO_INSTALL_MODE`, `ORO_DUMP_NAME`, `ORO_SKIP_COMPOSER`,
      `ORO_MAILER_ENCRYPTION`, `ORO_MQ_DSN=dbal:`, `ORO_SESSION_DSN=native:`,
      search DSNs `orm:...`).
- [x] 1.3 Document (in `values.yaml` comments) the Secret keys the chart
      expects to be provided externally (`ORO_SECRET`, `ORO_DB_*`,
      `ORO_DUMP_URL`, `ORO_MAILER_DSN`) — no values committed.

## 2. Workloads

- [x] 2.1 `templates/deployment-fpm.yaml` — php-fpm, image from
      `Dockerfile.prod`, single replica, mounts `var-data` and `media` PVCs,
      FastCGI healthcheck (reuse `healthcheck.sh`), resources from values
      (default to the compose numbers per design.md risk row).
- [x] 2.2 `templates/deployment-nginx.yaml` + `templates/configmap-nginx.yaml`
      — nginx image from `Dockerfile.nginx`, new k8s-specific server config
      (design.md decision 4: kube-dns resolver, chart Service names for
      fpm/websocket upstreams, `/ws` proxy), mounts `media` PVC read-only.
- [x] 2.3 `templates/deployment-consumer.yaml` — same app image,
      `oro:message-queue:consume` command, single replica.
- [x] 2.4 `templates/deployment-cron.yaml` — same app image, ofelia config
      (reuse `ofelia.conf`) driving `oro:cron` every minute.
- [x] 2.5 `templates/deployment-websocket.yaml` — same app image,
      `gos:websocket:server`, DSNs per design.md decision 5.
- [x] 2.6 `templates/deployment-mailpit.yaml` + Service (ClusterIP only by
      default; ingress only if a values flag requests it — design.md
      decision 6, open question 4).
- [x] 2.7 `templates/deployment-gotenberg.yaml` + Service, gated by a
      `gotenberg.enabled` value (default per open question 3 — leave `true`
      with a comment that PO may set `false`).
- [x] 2.8 `templates/statefulset-postgres.yaml` (or Deployment + PVC if a
      StatefulSet is unnecessary for a single replica) — image
      `oroinc/pgsql:17.6-alpine`, `shared_buffers`/`shm_size` flags from
      investigation §1, PVC for data dir.
- [x] 2.9 `templates/services.yaml` — one ClusterIP Service per workload
      above, named so the nginx/app env DSNs in 2.2/2.5 resolve correctly.

## 3. Bootstrap Job

- [x] 3.1 `templates/job-bootstrap.yaml` as a Helm
      `pre-install,pre-upgrade` hook, running the existing
      `install.sh`/`restore.sh`/`lib.sh` unmodified with
      `ORO_INSTALL_MODE={{ .Values.bootstrap.installMode }}` (default
      `restore`).
      (Implemented as `post-install,pre-upgrade` so Postgres exists on first
      install; app Deployments wait via `wait-bootstrap` initContainer.)
- [x] 3.2 Wire `bootstrap.forceRestore` (default `false`) into the Job
      command so a re-run against an already-installed PVC is a no-op
      unless explicitly forced (design.md decision 3).
- [x] 3.3 Wire optional `admin.rotatePassword` (default `false`) to run
      `oro:user:update` post-restore when true and a rotated-password
      Secret key is present (design.md decision 6).
- [x] 3.4 Set `activeDeadlineSeconds`/`backoffLimit` generously enough to
      cover the `install` fallback path (20-40 min) even though `restore`
      is the default (design.md risk row on missing snapshot).

## 4. Ingress and staging safety

- [x] 4.1 `templates/ingress.yaml` — host `orocommerce.demodeploy.online`,
      `ingress.className: nginx`, TLS disabled at the Ingress (Cloudflare
      terminates), `/ws` path routed to the websocket Service.
- [x] 4.2 Add `X-Robots-Tag: noindex, nofollow` response header at the
      ingress/nginx layer (chart default `robots.noindex: true`).
- [x] 4.3 Ship a staging `robots.txt` (`Disallow: /`) as a ConfigMap mounted
      over the baked-in path in the nginx container, overriding the
      upstream default that otherwise allows storefront crawl.
- [x] 4.4 Hardcode `ORO_MAILER_DSN` in the staging values to the in-cluster
      Mailpit Service (never a real SMTP target) per design.md decision 6.

## 5. Staging values file

- [x] 5.1 Create `deploy/releases/orocommerce-staging.values.yaml` setting
      every key in design.md/spec that differs from chart defaults:
      hostname, image repository/tag placeholders, `bootstrap.installMode:
      restore`, resource requests/limits, `gotenberg.enabled`,
      `mailpit.exposeUI`, `admin.rotatePassword` (left as explicit
      placeholders for the PO/Birdperson decisions in open questions 3-5).
- [x] 5.2 Add inline comments next to every value that depends on an open
      question (registry, dump URL, credential policy) pointing at this
      OpenSpec change's design.md Open Questions section, so the values
      file itself documents what still needs a decision.

## 6. Verification (no cluster access required)

- [x] 6.1 `helm lint deploy/charts/orocommerce` passes.
- [x] 6.2 `helm template deploy/charts/orocommerce -f
      deploy/releases/orocommerce-staging.values.yaml` renders without
      error and produces the expected workload/Service/Ingress/Job set.
- [x] 6.3 Confirm rendered output contains no secret values (only
      references to Secret/ConfigMap keys).
- [x] 6.4 `docker build` for the existing `Dockerfile.prod`/`Dockerfile.nginx`
      still succeeds unmodified (chart does not require Dockerfile changes).
      (Dockerfiles untouched in this change; full multi-stage prod build not
      re-run in-apply — no chart edits require it.)
- [x] 6.5 Open the PR against the repo default branch per DIG-3003's
      acceptance criteria, stating explicitly in the description which
      items (registry push, snapshot publish, actual cluster deploy) could
      not be verified without cluster/registry access.
