#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

usage() {
  cat <<EOF
Usage: $0 [TYPE] [PROJECT_NAME] [DESTINATION]

  TYPE          Project type: generic | laravel | node
  PROJECT_NAME  Alphanumeric with hyphens (e.g. my-api)
  DESTINATION   Directory to create (default: ./<project-name>)

Arguments are interactive if omitted.
EOF
  exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

# ── Prompts ───────────────────────────────────────────────────────────────────

TYPE=${1:-}
PROJECT_NAME=${2:-}
DEST=${3:-}

if [ -z "$TYPE" ]; then
  echo "Select project type:"
  PS3="Enter number: "
  select TYPE in generic laravel node; do
    [ -n "$TYPE" ] && break
    echo "Invalid selection, try again."
  done
fi

if [ ! -d "$TEMPLATE_ROOT/types/$TYPE" ]; then
  echo "Unknown type: $TYPE — available: generic, laravel, node"
  exit 1
fi

if [ -z "$PROJECT_NAME" ]; then
  read -rp "Project name: " PROJECT_NAME
fi
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

if [ -z "$DEST" ]; then
  DEST="./$PROJECT_NAME"
fi

# ── Preflight ─────────────────────────────────────────────────────────────────

if [ -d "$DEST" ]; then
  echo "Error: destination already exists: $DEST"
  exit 1
fi

echo ""
echo "Creating $TYPE project '$PROJECT_NAME' at $DEST"
echo ""

# ── Copy shared files ─────────────────────────────────────────────────────────

mkdir -p "$DEST"

echo "  bin/"
cp -r "$TEMPLATE_ROOT/bin" "$DEST/"
chmod +x "$DEST/bin/"*

echo "  Makefile"
cp "$TEMPLATE_ROOT/Makefile" "$DEST/"

echo "  .gitignore"
cp "$TEMPLATE_ROOT/.gitignore.base" "$DEST/.gitignore"

# ── Copy type-specific files ──────────────────────────────────────────────────

echo "  types/$TYPE/"
(
  cd "$TEMPLATE_ROOT/types/$TYPE"
  find . -type f | while IFS= read -r file; do
    file="${file#./}"
    dest_dir=$(dirname "$DEST/$file")
    mkdir -p "$dest_dir"
    cp "$file" "$DEST/$file"
    echo "    + $file"
  done
)

# ── Substitute project name in .env.example ───────────────────────────────────

if [ -f "$DEST/.env.example" ]; then
  sed -i.bak "s/^PROJECT_NAME=.*/PROJECT_NAME=$PROJECT_NAME/" "$DEST/.env.example"
  rm -f "$DEST/.env.example.bak"
fi

# ── Ensure env/ placeholder exists ────────────────────────────────────────────

mkdir -p "$DEST/env"

# ── Git init ──────────────────────────────────────────────────────────────────

(
  cd "$DEST"
  git init -q
  git add .
  git commit -q -m "chore: initialize $TYPE project from docker-stack-template"
)

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "Done. Project '$PROJECT_NAME' created at $DEST"
echo ""
echo "Next steps:"
echo "  cd $DEST"
echo "  make init      # copy .env and env/*.env from examples"
echo "  make build"
echo "  make up"
