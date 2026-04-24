#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

html_files=(CyberChef_v*.html)

if [ ${#html_files[@]} -ne 1 ]; then
  printf 'Expected exactly one CyberChef HTML file, found %s\n' "${#html_files[@]}" >&2
  exit 1
fi

mkdir -p dist
mv "${html_files[0]}" dist/index.html

for entry in *; do
  if [ "$entry" = "build.sh" ] || [ "$entry" = "dist" ]; then
    continue
  fi

  mv "$entry" dist/
done
