#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${STATICHUB_WORKDIR:?STATICHUB_WORKDIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"
PKGDIR="${STATICHUB_PKG:?STATICHUB_PKG is required}"

if [ ! -d "$WORKDIR/web" ]; then
  printf 'Expected upstream web directory at %s\n' "$WORKDIR/web" >&2
  exit 1
fi

if [ ! -f "$WORKDIR/COPYING.md" ]; then
  printf 'Expected upstream license file at %s\n' "$WORKDIR/COPYING.md" >&2
  exit 1
fi

cd "$WORKDIR/web"

npm ci
node "$PKGDIR/adapt-upstream.mjs"
npm run build

mkdir -p "$DISTDIR"
cp -a dist/. "$DISTDIR/"
cp "$WORKDIR/COPYING.md" "$DISTDIR/"

HOST_OWNER=$(stat -c '%u:%g' "$DISTDIR")
chown -R "$HOST_OWNER" "$DISTDIR"
