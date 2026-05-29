.PHONY: init post-create cleanup artisan composer pint test refresh apidocs deploy migrate tail-logs

ENV_FILES := php db nginx

## init	:	Initialize .env, env/*.env and create src/ directory.
init: init-env
	@for name in $(ENV_FILES); do \
		if [ ! -f env/$$name.env ]; then \
			echo "Creating env/$$name.env from env/$$name.env.example..."; \
			cp env/$$name.env.example env/$$name.env; \
		else \
			echo "env/$$name.env already exists — skipping."; \
		fi; \
	done
	@[ -d src ] || (mkdir -p src && echo "Created src/")

## post-create	:	Install common dev packages (blueprint, larastan, debugbar, pint, ray).
post-create:
	$(DOCKER_COMPOSE) exec app-main composer require --dev \
		laravel-shift/blueprint \
		nunomaduro/larastan \
		barryvdh/laravel-debugbar \
		tightenco/pint \
		spatie/laravel-ray

## cleanup	:	Drop template git history and start fresh.
cleanup:
	@echo "Removing template git history..."
	@rm -rf .git
	@git init
	@git add .
	@git commit -m "chore: initialize Laravel project"
	@echo "Done — clean git history."

## artisan	:	Run Laravel Artisan. Usage: make artisan migrate
artisan:
	$(DOCKER_COMPOSE) exec app-main php artisan $(filter-out $@,$(MAKECMDGOALS))

## composer	:	Run Composer. Usage: make composer require vendor/pkg
composer:
	$(DOCKER_COMPOSE) exec app-main composer $(filter-out $@,$(MAKECMDGOALS))

## pint	:	Run Laravel Pint code formatter.
pint:
	$(DOCKER_COMPOSE) exec app-main ./vendor/bin/pint

## refresh	:	Fresh migration with seeders.
refresh:
	$(DOCKER_COMPOSE) exec app-main php artisan migrate:fresh --seed

## test	:	Run Pest/PHPUnit tests. Usage: make test MyFeatureTest
test:
	$(DOCKER_COMPOSE) exec app-main php artisan test \
		$(if $(filter-out $@,$(MAKECMDGOALS)),--filter $(filter-out $@,$(MAKECMDGOALS)))

## apidocs	:	Generate API docs via Scribe.
apidocs:
	$(DOCKER_COMPOSE) exec app-main php artisan scribe:generate

## deploy	:	Deploy: git pull → migrate → restart workers.
deploy:
	@echo "Deploying $(PROJECT_NAME)..."
	git pull
	$(MAKE) migrate
	$(DOCKER_COMPOSE) exec worker php artisan queue:restart
	@echo "Deployed."

## migrate	:	Run database migrations.
migrate:
	$(DOCKER_COMPOSE) exec app-main php artisan migrate --force

## tail-logs	:	Tail Laravel application logs.
tail-logs:
	$(DOCKER_COMPOSE) exec app-main tail -f storage/logs/laravel.log
