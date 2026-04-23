#!/usr/bin/env bash
set -euo pipefail

# Set umask to ensure standard permissions (files: 644, dirs: 755)
umask 0022

# Build Excalidraw as a self-contained static app.
# The CLI downloads the source tarball from the GitHub release (tarball_url),
# strips the top-level directory, and runs this script from the repo root.
# Output: ./dist/ with all assets bundled (no CDN, no remote resources).

PATCH_FILE="0001-feat-app-support-custom-base-URL-for-hosting-under-a.patch"

if [ -f "$PATCH_FILE" ]; then
  git apply "$PATCH_FILE"
elif [ -f "/pkg/$PATCH_FILE" ]; then
  git apply "/pkg/$PATCH_FILE"
else
  printf 'Missing patch file: %s\n' "$PATCH_FILE" >&2
  exit 1
fi

git config --global --add safe.directory /work

yarn install --network-timeout 600000

VITE_APP_BASE_URL="$STATICHUB_PREFIX" npx yarn build:app:docker

# Cleanup existing dist to avoid mv issues
rm -rf dist

# Move the build output to dist
mv excalidraw-app/build dist

# Fix ownership so the host user can manage the files (Docker runs as root)
# We use the owner of the current directory (host mount) to set the correct UID/GID
HOST_OWNER=$(stat -c '%u:%g' .)
chown -R "$HOST_OWNER" dist
