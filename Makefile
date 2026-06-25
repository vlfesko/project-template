include .env.example
-include .env
-include Makefile.project.mk

.PHONY: help build pull up down start restart stop prune ps shell logs init-env preflight

default: up

SHELL := /bin/bash
DEFAULT_CONTAINER := $(or $(APP_CONTAINER),app-main)
DOCKER_COMPOSE := ./bin/docker-compose
HELP_FILES := Makefile Makefile.project.mk
PROXY_NETWORK ?= proxy
WRAPPER_FLAGS := $(if $(filter 1 true yes on,$(NO_DEV)),--no-dev) $(if $(filter 1 true yes on,$(NO_SRC)),--no-src)

## help	:	Print commands help.
help:
	@sed -n 's/^##//p' $(HELP_FILES)

## build	:	Build docker compose images.
build:
	@echo "Building images $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) build $(filter-out $@,$(MAKECMDGOALS))

## pull	:	Pull container images.
pull:
	@echo "Pulling container images for $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) pull $(filter-out $@,$(MAKECMDGOALS))

## preflight	:	Check external prerequisites (shared `$(PROXY_NETWORK)` network).
preflight:
	@if grep -qs '$(PROXY_NETWORK)' compose*.yaml && ! docker network inspect $(PROXY_NETWORK) >/dev/null 2>&1; then \
		echo ""; \
		echo "  WARNING: external Docker network '$(PROXY_NETWORK)' is missing."; \
		echo "  Services route through a shared Traefik on this network — 'up' will fail without it."; \
		echo "  Create it once with:  docker network create $(PROXY_NETWORK)"; \
		echo ""; \
		exit 1; \
	fi

## up	:	Start up containers.
##		Use `NO_SRC=1` to start without bind-mounts from `src/`.
##		Use `NO_DEV=1` to skip `compose.dev.yaml`.
up: preflight
	@echo "Starting up containers for $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) up -d --remove-orphans $(filter-out $@,$(MAKECMDGOALS))

## down	:	Stop and remove all containers.
down:
	@echo "Stopping and removing containers for $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) down $(filter-out $@,$(MAKECMDGOALS))

## start	:	Start containers without recreating.
start:
	@echo "Starting containers for $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) start $(filter-out $@,$(MAKECMDGOALS))

## restart	:	Restart containers.
restart:
	@echo "Restarting containers for $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) restart $(filter-out $@,$(MAKECMDGOALS))

## stop	:	Stop containers.
##		stop app-main	: Stop `app-main` container.
##		stop db app-main	: Stop `db` and `app-main` containers.
stop:
	@echo "Stopping containers for $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) stop $(filter-out $@,$(MAKECMDGOALS))

## prune	:	Remove containers and their volumes.
##		prune app-main	: Prune `app-main` and its volume.
##		prune db app-main	: Prune `db` and `app-main` and their volumes.
prune:
	@echo "Removing containers for $(PROJECT_NAME)..."
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) down -v $(filter-out $@,$(MAKECMDGOALS))

## ps	:	List running containers.
ps:
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) ps $(filter-out $@,$(MAKECMDGOALS))

## shell	:	Shell into the default container (APP_CONTAINER).
##		shell web	: Shell into `web` container.
##		Per-user config via MAKEFILE_SHELL_USERS_MAP (e.g. app-main=wodby db=root)
shell:
	@svc=$(or $(filter-out $@,$(MAKECMDGOALS)),$(DEFAULT_CONTAINER)); \
	user=$$(echo '$(MAKEFILE_SHELL_USERS_MAP)' | tr ' ' '\n' | grep "^$$svc=" | cut -d= -f2-); \
	[ -n "$$user" ] && flag="--user $$user" || flag=''; \
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) exec $$flag $$svc sh

## logs	:	Follow container logs (defaults to APP_CONTAINER).
##		logs web	: Follow `web` container logs.
##		logs db web	: Follow `db` and `web` logs.
logs:
	$(DOCKER_COMPOSE) $(WRAPPER_FLAGS) logs -f $(filter-out $@,$(MAKECMDGOALS))

## init-env	:	Create .env from .env.example (skips if .env already exists).
init-env:
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
	else \
		echo ".env already exists — skipping."; \
	fi

# https://stackoverflow.com/a/6273809/1826109
%:
	@:
