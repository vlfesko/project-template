.PHONY: init install post-create cleanup artisan composer pint test refresh apidocs deploy migrate tail-logs

ENV_FILES := php db nginx
LARAVEL_BIN := /home/wodby/.composer/vendor/bin/laravel

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

## install	:	Bootstrap a fresh Laravel app into src/ and bring the stack online.
##		Installs via laravel/installer (--livewire --pest), wires Vite HMR for
##		Traefik, migrates, installs dev packages. DB/Redis/Mail connection comes
##		from the container env (compose.yaml), so src/.env is never edited.
##		Aborts if src/ already contains an app.
install: preflight
	@if [ -f src/artisan ]; then \
		echo "Aborting: src/artisan exists — src/ already contains a Laravel app."; \
		exit 1; \
	fi
	@$(MAKE) init
	@$(MAKE) up
	@echo "==> Installing Laravel via laravel/installer (this can take a few minutes)..."
	@$(DOCKER_COMPOSE) exec -T app-main sh -lc 'set -e; \
		[ -x "$(LARAVEL_BIN)" ] || composer global require laravel/installer; \
		cd /var/www/html; \
		rm -rf .laravel-new; \
		"$(LARAVEL_BIN)" new .laravel-new --livewire --pest --force --database mariadb --no-interaction || true; \
		[ -f .laravel-new/artisan ] || { echo "laravel new did not produce an app"; exit 1; }; \
		cp -a .laravel-new/. ./; \
		rm -rf .laravel-new'
	@echo "==> Configuring Vite for Traefik HMR (reads VITE_DOMAIN from the node container)..."
	@perl -0pi -e 's/server:\s*\{/server: {\n        host: "0.0.0.0",\n        origin: process.env.VITE_DOMAIN ? "https:\/\/" + process.env.VITE_DOMAIN : undefined,\n        allowedHosts: true,\n        hmr: process.env.VITE_DOMAIN ? { host: process.env.VITE_DOMAIN, protocol: "wss", clientPort: 443 } : undefined,/' src/vite.config.js
	@grep -q VITE_DOMAIN src/vite.config.js \
		&& echo "    vite.config.js patched." \
		|| echo "    WARNING: no 'server:' block in src/vite.config.js — set the HMR host manually (see README)."
	@echo "==> Dropping npm-driven composer hooks (npm lives in the node service, not app-main)..."
	@python3 -c "import json; p='src/composer.json'; d=json.load(open(p)); s=d.get('scripts',{}); h=s.get('post-update-cmd'); s['post-update-cmd']=[x for x in h if not (isinstance(x,str) and 'install:features' in x)] if isinstance(h,list) else h; json.dump(d,open(p,'w'),indent=4); open(p,'a').write('\n')"
	@echo "==> Running migrations..."
	@$(MAKE) migrate
	@echo "==> Installing dev packages..."
	@$(MAKE) post-create
	@echo "==> Restarting services to pick up the freshly installed app..."
	@$(DOCKER_COMPOSE) restart app-main web node worker
	@echo ""
	@echo "Laravel is ready:"
	@echo "  App  : $(X_APP_URL)"
	@echo "  PMA  : http://$(X_PMA_DOMAIN)"
	@echo "  Vite : https://$(X_VITE_DOMAIN)"

## post-create	:	Install common dev packages (blueprint, larastan, debugbar, pint, ray).
post-create:
	$(DOCKER_COMPOSE) exec app-main composer require --dev \
		laravel-shift/blueprint \
		larastan/larastan \
		barryvdh/laravel-debugbar \
		laravel/pint \
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
