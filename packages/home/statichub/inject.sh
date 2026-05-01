#!/usr/bin/env bash
set -euo pipefail

DATADIR="${STATICHUB_DATADIR:?STATICHUB_DATADIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"

if ! command -v jq >/dev/null 2>&1; then
  apk add --no-cache jq >/dev/null
fi

SOURCE_FILE="$DATADIR/custom-links.json"
TARGET_FILE="$DISTDIR/custom-links.json"

if [ ! -f "$SOURCE_FILE" ]; then
  rm -f "$TARGET_FILE"
  exit 0
fi

jq -e '
  type == "object" and
  (.packages | type == "array") and
  (.packages | all(
    type == "object" and
    (.path | type == "string") and
    (.title | type == "string") and
    ((has("external") | not) or (.external | type == "boolean")) and
    ((has("icon") | not) or (.icon | type == "string")) and
    ((has("description") | not) or (.description | type == "string")) and
    ((has("tags") | not) or (.tags | type == "array" and (.tags | all(type == "string"))))
  ))
' "$SOURCE_FILE" >/dev/null

cp "$SOURCE_FILE" "$TARGET_FILE"

if [ -d "$DATADIR/icons" ]; then
  rm -rf "$DISTDIR/icons"
  cp -r "$DATADIR/icons" "$DISTDIR/icons"
  chmod -R u+rw "$DISTDIR/icons"
else
  rm -rf "$DISTDIR/icons"
fi
