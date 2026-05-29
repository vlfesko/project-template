# adopt-template

Adopt or update an existing project to use docker-stack-template. Works for both first-time adoption (converting a project to use the template) and updating a project already on the template to pull in new template changes.

## What this skill does

1. Locates the template root (looks for `template/` in the project root, or asks)
2. Detects or confirms the project type (`generic` | `laravel` | `node`)
3. Inventories every template file against what the project currently has
4. For each file: adds if missing, skips if identical, shows a diff and proposes a merge strategy if it differs
5. Merges `.gitignore` additively (never replaces, only appends missing lines)
6. Handles `.env.example` conservatively: shows diff, lets the user choose to merge key-by-key or overwrite
7. Never touches project-specific source files (`src/`, application code, etc.)

## Instructions for Claude

### Step 1 — Orient

- Find `template/` relative to the current project root. If it's not there, ask the user where the template is.
- Read the project root to understand what already exists: `ls -la`, check for `composer.json`, `package.json`, `Makefile`, `bin/`, `compose.yaml`, `Makefile.project.mk`.

### Step 2 — Detect type

- `composer.json` present → **laravel**
- `package.json` present (and no `composer.json`) → **node**
- Otherwise → **generic**
- Tell the user what you detected and confirm before proceeding.

### Step 3 — Inventory

Compare every file in `template/bin/`, `template/Makefile`, `template/.gitignore.base`, and `template/types/<TYPE>/` against the project. Build a list with three categories:

- **MISSING** — file doesn't exist in the project yet
- **IDENTICAL** — byte-for-byte match, nothing to do
- **DIFFERS** — both exist but content is different

Present the full inventory to the user before making any changes.

### Step 4 — Apply changes

Work through each file, one at a time:

**MISSING files** → copy from template, report `[added] <path>`.

**DIFFERS files** — use judgment:

- `bin/*` scripts: these are template-managed infrastructure. Show a unified diff. For small diffs (e.g. a bug fix), propose applying it. For large rewrites, ask the user.
- `Makefile`: template-managed base. Show diff of base sections only (help, build, up, down, shell, logs, etc.). Project-specific targets in `Makefile.project.mk` are never touched.
- `Makefile.project.mk`: project-owned. Show what's new/changed in the template version and let the user decide to merge specific targets or ignore.
- `compose.yaml` / `compose.*.yaml`: project-owned structure, template provides a reference. Show diff, offer to sync specific service definitions (e.g. adding a new service the template now includes), but never wholesale replace.
- `.env.example`: compare key-by-key. Propose adding keys that exist in the template but not the project. Never remove or change existing keys.
- `docker/conf/*` (nginx template, php bashrc, crontab): show diff, ask to update.

**IDENTICAL files** → report `[ok] <path>` and skip.

### Step 5 — .gitignore merge

Read `template/.gitignore.base`. For each line in it, check if it already appears in the project's `.gitignore`. Append only the missing lines. Report what was added.

### Step 6 — Summary

After all changes, print a concise summary:
- N files added
- N files updated  
- N files skipped (identical)
- N files skipped (user declined)

Suggest running `make init` if env files were added.

## Guardrails

- Never delete files — only add or modify
- Never touch `src/`, `tests/`, `docker/data/`, or any application source files
- Never overwrite `.env` (only `.env.example`)
- If unsure whether a change is safe, ask before applying it
- Keep the user informed at every step — this is an interactive process
