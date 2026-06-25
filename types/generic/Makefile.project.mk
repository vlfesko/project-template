.PHONY: init

# List service env files (without .env suffix) to copy from env/*.env.example
ENV_FILES := app

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
