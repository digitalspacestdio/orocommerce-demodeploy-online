# Staging deploy — orocommerce.demodeploy.online

Execution is DevOps-only ([Birdperson](/DIG/agents/birdperson)) via the company skill
`demodeploy-staging`. Other roles file a deploy issue instead of running Helm themselves.

## Release coordinates (canonical)

| Item | Value |
|------|-------|
| Cluster | `demodeploy` (k3s, docker backend, origin `10.112.0.220`) |
| **Namespace** | **`orocommerce`** — a personal namespace, *not* the shared `staging` |
| Release | `orocommerce` |
| Host | `orocommerce.demodeploy.online` (Cloudflare terminates TLS; cluster serves HTTP :80) |
| Chart | `deploy/charts/orocommerce` |
| Values | `deploy/releases/orocommerce-staging.values.yaml` |
| Secret | `orocommerce-secrets` in the `orocommerce` namespace |

**Why its own namespace.** This release owns a Postgres StatefulSet and two RWO PVCs
(`-var-data`, `-media`). Shared `staging` is for stateless demo apps; putting a stateful
release there mixes its lifecycle (and `helm uninstall` blast radius) with everyone else's.
The first attempt at DIG-3005 landed in `staging` and was moved.

## Install / upgrade

```bash
helm upgrade --install orocommerce deploy/charts/orocommerce \
  -n orocommerce --create-namespace \
  -f deploy/releases/orocommerce-staging.values.yaml \
  --set image.repository=orocommerce-demo --set image.tag=<git-sha> \
  --set nginx.image.repository=orocommerce-demo-nginx --set nginx.image.tag=<git-sha> \
  --wait --timeout 90m
```

`--timeout 90m` is not optional on a first install. The bootstrap Job is a normal manifest
resource, so `--wait` waits for it too, and a first `oro:install` with demo data takes
20–40 minutes. The default 5m timeout would mark the release `failed` mid-install.

Prefer the node-local image path while there is no registry: `docker save` the two images on
the build host, `docker load` them on the demodeploy node (k3s runs the docker backend), and
keep `pullPolicy: IfNotPresent` so the kubelet never tries to pull the tag.

## Bootstrap: why it is not a Helm hook

`job-bootstrap.yaml` runs `oro-install`; every app workload has a `wait-bootstrap` init
container that blocks until it finishes. When the Job was a `post-install` hook this
deadlocked the very first install:

1. `helm ... --wait` blocks until the Deployments are Ready.
2. The Deployments' pods block in `wait-bootstrap`.
3. The post-install hook that would run bootstrap only fires *after* `--wait` returns.

The release stayed in `pending-install`, no bootstrap Job was ever created, and the Helm
client eventually left (DIG-3005). Recovery required applying the Job by hand and patching
the release secret back to `deployed`.

The Job is now an ordinary manifest resource:

- created in the same pass as the Deployments, so it starts immediately;
- it waits for Postgres itself (`bootstrap.postgresWaitRetries`), so no hook ordering is needed;
- on success it writes `/var/www/var/data/.bootstrap/<release-revision>` on the shared
  `var-data` PVC;
- `wait-bootstrap` waits for *that revision's* marker, which keeps the upgrade ordering the
  old `pre-upgrade` hook provided — new app pods do not serve traffic until the new
  revision's migrations have run.

The Job name carries the release revision (`orocommerce-bootstrap-<rev>`) because a Job spec
is immutable; Helm prunes the previous revision's Job on upgrade. A side effect of the
revision marker is that every `helm upgrade` rolls the app pods, including a no-op upgrade —
acceptable for a demo site, and the price of guaranteed ordering.

Set `bootstrap.enabled=false` to manage installation out of band; `wait-bootstrap` then falls
back to polling `oro_is_installed` instead of waiting for a marker that nothing writes.

## Recovering a stuck release

```bash
helm status orocommerce -n orocommerce
# pending-install with no bootstrap Job => the old hook deadlock; on this chart it
# should not recur. If a release is stuck anyway:
helm rollback orocommerce -n orocommerce      # if a previous revision exists
helm uninstall orocommerce -n orocommerce     # otherwise; PVCs survive, so data is kept
```

## Verify

```bash
curl -sI https://orocommerce.demodeploy.online/
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: orocommerce.demodeploy.online' http://10.112.0.220/
kubectl -n orocommerce get pods,job
kubectl -n orocommerce logs job/orocommerce-bootstrap-<rev> --tail=50
```

Back-office `/admin` — `admin` / `Admin1234!`; storefront demo customers use their e-mail as
the password. See AGENTS.md "Default credentials".
