# staging-deployment Specification

## Purpose
Defines the observable deployment behavior of the OroCommerce CE demo site
when released via Helm to the demodeploy staging cluster at
`orocommerce.demodeploy.online`, so the chart's correctness can be checked
independently of how it is implemented internally.
## Requirements
### Requirement: Workload topology matches the stock demo stack
The chart SHALL deploy exactly the workloads the stock demo stack runs
(nginx, php-fpm, PostgreSQL, message-queue consumer, cron, websocket, mail
capture) and SHALL NOT require Redis or Elasticsearch/OpenSearch, matching
the application's stock ORM/DBAL/native-session configuration.

#### Scenario: Long-running processes run as independent workloads
- **WHEN** the chart is rendered
- **THEN** the message-queue consumer, cron, and websocket server each render
  as a separate long-running workload from the web/php-fpm workload, so one
  can restart or crash-loop without affecting the others

#### Scenario: No unused infrastructure is required
- **WHEN** the chart is rendered with default values
- **THEN** no Redis or Elasticsearch/OpenSearch Deployment, StatefulSet, or
  Service is created

### Requirement: Public ingress serves the storefront and back-office over the staging hostname
The chart SHALL expose the storefront and back-office through an Ingress
resource bound to `orocommerce.demodeploy.online`, routed through the
cluster's ingress controller with TLS terminated upstream (Cloudflare),
rather than through the repository's embedded-Traefik configuration.

#### Scenario: Ingress host matches the staging domain
- **WHEN** the chart is rendered with the staging values file
- **THEN** the Ingress resource's host is `orocommerce.demodeploy.online` and
  its ingress class matches the cluster's ingress controller

#### Scenario: Websocket path is reachable over the public hostname
- **WHEN** a client requests `wss://orocommerce.demodeploy.online/ws`
- **THEN** the request is routed to the websocket workload, and the
  workload's configured public DSN matches that public HTTPS endpoint

### Requirement: Persistent state survives pod restarts; ephemeral state does not need to
The chart SHALL provision persistent storage for the database, private
application data, and media/attachments, and SHALL NOT require persistent
storage for cache, sessions, or bootstrap download scratch space.

#### Scenario: Pod restart does not lose the database or media
- **WHEN** the php-fpm or database pod restarts
- **THEN** previously stored orders/catalog data and previously uploaded
  media remain available after the restart

#### Scenario: Cache and session data may be lost on restart
- **WHEN** a php-fpm pod restarts
- **THEN** the system continues to function correctly even if its local
  cache and session files were not preserved (a fresh cache warm and a
  storefront re-login are acceptable)

### Requirement: Bootstrap is idempotent and does not require manual intervention on redeploy
The chart SHALL provide a bootstrap step that installs demo data on first
release and SHALL NOT destructively reinstall or wipe existing data on a
subsequent release unless explicitly requested.

#### Scenario: First release installs demo data
- **WHEN** the chart is installed against an empty database
- **THEN** the bootstrap step populates the database with the demo dataset
  and the site is reachable and browsable afterward

#### Scenario: Redeploy does not wipe existing data by default
- **WHEN** the chart is upgraded against a database that is already
  bootstrapped
- **THEN** the bootstrap step completes without destroying previously
  stored data, unless a values field explicitly requests a forced
  reinstall/restore

### Requirement: Staging is not indexable and does not send real outbound mail
The chart SHALL prevent the staging site from being indexed by search
engines and SHALL prevent any application-triggered email from reaching a
real external mailbox.

#### Scenario: Search engines are told not to index staging
- **WHEN** any page on `orocommerce.demodeploy.online` is requested
- **THEN** the response instructs crawlers not to index or follow the page
  (via response header or robots directive)

#### Scenario: Outgoing mail is captured, not delivered
- **WHEN** the application sends any email (order confirmation, cron
  notification, etc.)
- **THEN** the email is captured by an in-cluster mail catcher and is never
  delivered to a real external mailbox

### Requirement: Configuration is externalized and contains no secret values in the repository
The chart SHALL source all environment-specific and secret configuration
(application URL, database credentials, application secret, mail/queue/search
DSNs) from Kubernetes ConfigMaps/Secrets or Paperclip-managed secret values,
and the repository SHALL NOT contain real credential values for the staging
environment.

#### Scenario: Rendering the chart requires no repo-committed secret
- **WHEN** the chart's values files are inspected
- **THEN** no field contains a real database password, application secret,
  or other live credential — only key names, references, or documented
  placeholder demo defaults that are already public in the repository

#### Scenario: Changing a secret does not require a chart change
- **WHEN** an operator rotates the database password or application secret
  in the cluster's secret store
- **THEN** the chart's templates and values file need no code change to
  pick up the new value on the next rollout

