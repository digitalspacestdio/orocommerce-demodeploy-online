# Convenience wrapper around the Docker stack (see docs/demo-stack.md).
COMPOSE       ?= docker compose
COMPOSE_PROD  ?= docker compose -f docker-compose.prod.yml
EXEC          ?= $(COMPOSE) exec -u 1000:1000 oro-fpm

.PHONY: up down logs install console dump restore reset prod-build prod-up prod-logs

# start the local demo stack (installs Oro with demo data on first run)
up:
	@test -f .env || cp .env.example .env
	$(COMPOSE) up -d
	@echo "demo site: $$(grep -E '^ORO_APP_URL=' .env | cut -d= -f2-)"

# stop the stack (keeps the database)
down:
	$(COMPOSE) down

# follow the installer log
logs:
	$(COMPOSE) logs -f oro-install

# re-run the idempotent installer
install:
	$(COMPOSE) run --rm oro-install

# bin/console inside the container: make console CMD="oro:cron"
console:
	$(EXEC) bin/console $(CMD)

# snapshot the current instance into docker/orocommerce/dumps/$(NAME)
dump:
	$(EXEC) oro-dump $(or $(NAME),demo)

# re-import a snapshot over the current database (destructive)
restore:
	$(COMPOSE) run --rm -e ORO_INSTALL_MODE=restore oro-install

# delete all data and reinstall from scratch
reset:
	$(COMPOSE) down -v
	$(COMPOSE) up -d

# build the production images
prod-build:
	$(COMPOSE_PROD) build

# deploy on a Docker host with embedded Traefik
prod-up:
	$(COMPOSE_PROD) up -d --build

prod-logs:
	$(COMPOSE_PROD) logs -f oro-install
