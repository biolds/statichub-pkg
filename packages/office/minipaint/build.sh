#!/usr/bin/env bash
set -euo pipefail

DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"

if ! command -v git >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y git
    rm -rf /var/lib/apt/lists/*
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache git
  else
    printf 'git is required to install npm dependencies for miniPaint\n' >&2
    exit 1
  fi
fi

npm install
npm run build

mkdir -p "$DISTDIR"
rm -rf "$DISTDIR"/*
cp -a index.html images dist "$DISTDIR/"
