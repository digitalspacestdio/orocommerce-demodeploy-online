OroCommerce Sample Application
==============================

Demo deployment (branch `7.0.x`)
--------------------------------

This branch is the unmodified `7.0.4` application plus a Docker stack that installs
OroCommerce **with demo data** and serves it — locally and on a server. See
[docs/demo-stack.md](docs/demo-stack.md).

```sh
make up          # or: docker compose up -d   (first run installs Oro, 20-40 min)
make logs        # installer progress
```

Storefront <http://localhost:8092>, back-office <http://localhost:8092/admin>, mail
<http://localhost:8026>. Logins: `admin` / `Admin1234!` for the back-office; storefront demo
customers sign in with their e-mail as both login and password, e.g. `AmandaRCole@example.org`.
Deploy with `docker-compose.prod.yml` (embedded Traefik) or `docker-compose.dokploy.yml` (Dokploy).

Rules and full instructions for this branch: [AGENTS.md](AGENTS.md).

What Is Included?
--------------------

This sample application includes OroCommerce Community Edition.

Other application distributions:
  * orocommerce-enterprise-application - OroCommerce Enterprise Edition
  * orocommerce-enterprise-nocrm-application - OroCommerce Enterprise Edition, without CRM modules
  * orocommerce-platform-application - OroCommerce Enterprise Edition, with additional marketplace modules


  * orocommerce-application-de - German-localized version of OroCommerce Community Edition
  * orocommerce-enterprise-application-de - German-localized version of OroCommerce Enterprise Edition


  * platform-application - OroPlatform Community Edition, without eCommerce/CRM/marketplace modules
  * crm-application - OroCRM Community Edition, without eCommerce/marketplace modules
  * crm-enterprise-application - OroCRM Enterprise Edition, without eCommerce/marketplace modules
  * oromarketplace-application - legacy version (4.2 compatible) of OroCommerce Enterprise Edition with additional marketplace modules

What is OroCommerce?
--------------------

OroCommerce is an open-source Business to Business Commerce application built with flexibility in mind. It can be customized and extended to fit any B2B commerce needs.
You can find out more about OroCommerce at [www.orocommerce.com](https://www.orocommerce.com/).

System Requirements
-------------------

Please see the OroCommerce online documentation for the complete list of [system requirements](https://doc.oroinc.com/backend/setup/system-requirements/).

Installation
------------

Please see the [OroCommerce and OroCRM Community Edition Installation Guide](https://doc.oroinc.com/backend/setup/dev-environment/manual-installation/commerce-ce/) for the detailed installation steps.

Resources
---------

  * [OroCommerce Documentation](https://doc.oroinc.com)
  * [Contributing](https://doc.oroinc.com/community/contribute/)

License
-------
 
[OSL-3.0](LICENSE) Copyright (c) 2024 Oro Inc.
