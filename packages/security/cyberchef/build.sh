#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"

html_files=(CyberChef_v*.html)

if [ ${#html_files[@]} -ne 1 ]; then
  printf 'Expected exactly one CyberChef HTML file, found %s\n' "${#html_files[@]}" >&2
  exit 1
fi

mkdir -p "$DISTDIR"
mv "${html_files[0]}" "$DISTDIR/index.html"

for entry in *; do
  if [ "$entry" = "build.sh" ]; then
    continue
  fi

  mv "$entry" "$DISTDIR/"
done
