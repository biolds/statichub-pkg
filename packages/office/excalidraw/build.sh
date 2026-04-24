#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${STATICHUB_WORKDIR:?STATICHUB_WORKDIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"
PKGDIR="${STATICHUB_PKG:?STATICHUB_PKG is required}"

PATCH_FILE="0001-feat-app-support-custom-base-URL-for-hosting-under-a.patch"

if [ -f "$PATCH_FILE" ]; then
  git -c safe.directory="$WORKDIR" apply "$PATCH_FILE"
elif [ -f "$PKGDIR/$PATCH_FILE" ]; then
  git -c safe.directory="$WORKDIR" apply "$PKGDIR/$PATCH_FILE"
else
  printf 'Missing patch file: %s\n' "$PATCH_FILE" >&2
  exit 1
fi

yarn install --network-timeout 600000

VITE_APP_BASE_URL="$STATICHUB_PREFIX" npx yarn build:app:docker

# Move the build output to STATICHUB_DISTDIR
mkdir -p "$DISTDIR"
rm -rf "$DISTDIR"/*
cp -a excalidraw-app/build/. "$DISTDIR/"

# Fix ownership so the host user can manage the files (Docker runs as root)
# We use the owner of the output mount to set the correct UID/GID.
HOST_OWNER=$(stat -c '%u:%g' "$DISTDIR")
chown -R "$HOST_OWNER" "$DISTDIR"
