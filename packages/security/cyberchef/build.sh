#!/usr/bin/env bash
set -euo pipefail

html_files=(dist/CyberChef_v*.html)

if [ ${#html_files[@]} -ne 1 ]; then
  printf 'Expected exactly one CyberChef HTML file, found %s\n' "${#html_files[@]}" >&2
  exit 1
fi

mv "${html_files[0]}" dist/index.html
