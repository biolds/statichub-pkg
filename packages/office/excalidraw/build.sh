#!/usr/bin/env bash
set -euo pipefail

# Build Excalidraw as a self-contained static app.
# The CLI downloads the source tarball from the GitHub release (tarball_url),
# strips the top-level directory, and runs this script from the repo root.
# Output: ./dist/ with all assets bundled (no CDN, no remote resources).

yarn install --network-timeout 600000

yarn build:app:docker

mv excalidraw-app/build dist
