# docker-stack-template

Reusable Docker Compose project template with Traefik routing, environment-based
compose file layering, and configurable bin scripts.

## Project types

| Type | Description |
|------|-------------|
| `generic` | Any Docker-based stack (Python, Go, Rust, …) |
| `laravel` | PHP 8.x / Laravel via Wodby images, with Nginx, Redis, queue worker |
| `node` | Node.js application (Express, Fastify, Next.js, …) |

---

## Create a new project

```bash
./template/scripts/new-project.sh [type] [name] [destination]
```

Interactive if arguments are omitted. Copies shared `bin/`, `Makefile`, `.gitignore`, and
all type-specific files, substitutes the project name, and runs `git init`.

---

## Adopt an existing project

Use the Claude skill `/adopt-template` from inside the project root. It:

- Detects the project type automatically
- Shows what's missing vs. different vs. identical
- Adds missing files, diffs differing files, and asks before changing anything
- Merges `.gitignore` additively — never replaces
- Handles `.env.example` key-by-key

---

## Compose file loading order

`bin/docker-compose` loads files in this order (skips missing ones):

| File | Purpose |
|------|---------|
| `compose.yaml` | Base service definitions |
| `compose.${COMPOSE_ENV}.yaml` | Environment overlay (e.g. `compose.local.yaml`) |
| `compose.override.yaml` | Local user overrides — gitignored |
| `compose.healthcheck.yaml` | Optional health-check additions |
| `compose.src.yaml` | Source bind-mounts — skip with `NO_SRC=1` |
| `compose.${COMPOSE_ENV}.arm64v8.yaml` | ARM64 image overrides (macOS only) |
| `compose.dev.yaml` | Dev tools — skip with `NO_DEV=1` |

`COMPOSE_ENV` defaults to `local`. Set it in `.env` to switch environments.

---

## Local access & running projects in parallel

No project publishes a fixed host port. Every HTTP-facing service is reached by
hostname through a **shared local Traefik** instance, and databases are reached by
exec-ing into the container. Because Traefik multiplexes everything on `:80` / `:443`
by `Host:` header, any number of projects run at once without port collisions.

**Prerequisite:** a Traefik container attached to an external Docker network named
`proxy` must be running. Every type's `compose.local.yaml` joins it:

```yaml
networks:
  proxy:
    external: true
```

Create it once if it doesn't exist: `docker network create proxy`. `make up` runs a
preflight check and stops with this hint if the network is missing.

### How each service is reached locally

| Service | Reached via | Default host |
|---------|-------------|--------------|
| App (generic / node) | Traefik | `https://<project>.docker.localhost` |
| `web` (Laravel / Nginx) | Traefik | `https://<project>.docker.localhost` |
| `pma` (Laravel) | Traefik | `http://pma.<project>.docker.localhost` |
| Vite dev server (Laravel) | Traefik (WSS) | `https://vite.<project>.docker.localhost` |
| `db` (MariaDB / Mongo) | `bin/mysql` · `bin/mongo` (`docker compose exec`) | _no host port_ |
| `redis` | `bin/redis` (`docker compose exec`) | _no host port_ |

`*.docker.localhost` resolves to `127.0.0.1` automatically in Chrome and Firefox; no
hosts-file entry is needed. Host names are derived from `PROJECT_NAME` via the
`X_APP_DOMAIN` / `X_PMA_DOMAIN` / `X_VITE_DOMAIN` variables in `.env`.

> A database has no published port by design. To attach a GUI client, add a temporary
> binding in `compose.override.yaml` (gitignored) with a port that is free on your host.

### Vite HMR (Laravel)

The `node` service is routed at `X_VITE_DOMAIN`, so the app's `vite.config.js` must
advertise that host instead of `localhost:5173`:

```js
export default defineConfig({
  // ...
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    cors: true,
    allowedHosts: [process.env.VITE_DOMAIN],
    hmr: {
      host: process.env.VITE_DOMAIN, // e.g. vite.my-app.docker.localhost
      protocol: 'wss',
      clientPort: 443,
    },
  },
})
```

The `node` service's compose overlay already injects `VITE_DOMAIN` (from
`X_VITE_DOMAIN`) into the container, so the config above works as-is.

---

## Bin script configuration

All app-shell and copy scripts read from `.env.example` / `.env`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `APP_CONTAINER` | `app-main` | Main application service name |
| `APP_SHELL_USER` | _(empty)_ | User for `bin/bash` (e.g. `wodby` for Laravel) |
| `APP_ROOT` | `/app` | Container app root for copy scripts |
| `APP_LOCAL_SRC` | `./src` | Local source directory for copy scripts |

### Shared scripts (all types)

| Script | Purpose |
|--------|---------|
| `bin/docker-compose` | Multi-file compose wrapper |
| `bin/start` / `bin/stop` / `bin/restart` | Container lifecycle |
| `bin/log` | Follow logs (defaults to `APP_CONTAINER`) |
| `bin/make` | Run make with `--no-src` / `--no-dev` flag translation |
| `bin/bash` | Interactive shell as `APP_SHELL_USER` |
| `bin/cli` / `bin/clinotty` | Run a command in `APP_CONTAINER` (tty / no-tty) |
| `bin/root` / `bin/rootnotty` | Run as root in `APP_CONTAINER` |
| `bin/copyfromcontainer` | Copy paths from container to `APP_LOCAL_SRC` |
| `bin/copytocontainer` | Copy paths from `APP_LOCAL_SRC` to container |

### Service-specific scripts

| Script | Included for |
|--------|-------------|
| `bin/mongo` / `bin/mongodump` / `bin/mongorestore` | generic (MongoDB) |
| `bin/redis` | generic, laravel, node (when Redis is used) |
| `bin/mysql` | laravel |

---

## Makefile targets

Base targets (all types): `help`, `build`, `pull`, `up`, `down`, `start`, `restart`,
`stop`, `prune`, `ps`, `shell`, `logs`, `init-env`, `preflight`.

Project-specific targets live in `Makefile.project.mk` (included automatically).

### Laravel extras

`init`, `artisan`, `composer`, `pint`, `test`, `refresh`, `apidocs`,
`migrate`, `deploy`, `tail-logs`, `post-create`, `cleanup`

### Node extras

`init`, `npm`, `dev`, `npm-build`, `test`

---

## Template structure

```
template/
├── bin/                        shared scripts
├── Makefile                    base make targets
├── .gitignore.base             merged into new projects
├── types/
│   ├── generic/
│   │   ├── Makefile.project.mk
│   │   ├── compose.yaml
│   │   ├── compose.production.yaml
│   │   ├── compose.override.yaml.example
│   │   ├── .env.example
│   │   └── env/app.env.example
│   ├── laravel/
│   │   ├── Makefile.project.mk
│   │   ├── compose.yaml
│   │   ├── compose.local.yaml
│   │   ├── compose.local.arm64v8.yaml
│   │   ├── compose.production.yaml
│   │   ├── compose.override.yaml.example
│   │   ├── .env.example
│   │   ├── .gitignore
│   │   ├── env/php.env.example
│   │   └── docker/conf/{cron,nginx,php}
│   └── node/
│       ├── Makefile.project.mk
│       ├── compose.yaml
│       ├── compose.production.yaml
│       ├── compose.override.yaml.example
│       └── .env.example
├── scripts/
│   └── new-project.sh
└── .claude/
    └── commands/
        └── adopt-template.md   Claude skill for adoption/updates
```
