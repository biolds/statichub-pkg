#!/usr/bin/env bash
set -euo pipefail

DATADIR="${STATICHUB_DATADIR:?STATICHUB_DATADIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"

SOURCE_FILE="$DATADIR/doom.wad"
TARGET_FILE="$DISTDIR/doom1.wad"

if [ -f "$SOURCE_FILE" ]; then
  cp "$SOURCE_FILE" "$TARGET_FILE"
fi
