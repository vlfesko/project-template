.PHONY: init npm dev npm-build test

ENV_FILES :=

## init	:	Initialize .env and env/*.env from examples.
init: init-env
	@for name in $(ENV_FILES); do \
		if [ ! -f env/$$name.env ]; then \
			echo "Creating env/$$name.env from env/$$name.env.example..."; \
			cp env/$$name.env.example env/$$name.env; \
		else \
			echo "env/$$name.env already exists — skipping."; \
		fi; \
	done

## npm	:	Run npm in app-main. Usage: make npm install  /  make npm run lint
npm:
	$(DOCKER_COMPOSE) exec app-main npm $(filter-out $@,$(MAKECMDGOALS))

## dev	:	Start development server inside app-main.
dev:
	$(DOCKER_COMPOSE) exec app-main npm run dev

## npm-build	:	Build for production inside app-main.
npm-build:
	$(DOCKER_COMPOSE) exec app-main npm run build

## test	:	Run tests inside app-main. Usage: make test -- --grep pattern
test:
	$(DOCKER_COMPOSE) exec app-main npm test $(filter-out $@,$(MAKECMDGOALS))
