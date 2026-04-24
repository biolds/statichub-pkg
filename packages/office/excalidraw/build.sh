#!/usr/bin/env bash
set -euo pipefail

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

# Move the build output to dist
mv excalidraw-app/build dist

# Fix ownership so the host user can manage the files (Docker runs as root)
# We use the owner of the current directory (host mount) to set the correct UID/GID
HOST_OWNER=$(stat -c '%u:%g' .)
chown -R "$HOST_OWNER" dist
