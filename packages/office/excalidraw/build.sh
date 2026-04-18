#!/usr/bin/env bash
set -euo pipefail

# Build Excalidraw as a self-contained static app.
# The CLI downloads the source tarball from the GitHub release (tarball_url),
# strips the top-level directory, and runs this script from the repo root.
# Output: ./dist/ with all assets bundled (no CDN, no remote resources).

export VITE_APP_DISABLE_TRACKING=true

npm ci --prefer-offline

npm run build:app

# Ensure fonts are bundled locally so no CDN is needed at runtime
FONTS_SRC="node_modules/@excalidraw/excalidraw/dist/prod/fonts"
if [ -d "$FONTS_SRC" ]; then
  cp -rn "$FONTS_SRC/." packages/excalidraw-app/build/fonts/ 2>/dev/null || true
fi

# Inject EXCALIDRAW_ASSET_PATH so fonts resolve from local path, not CDN
sed -i 's|</head>|<script>window.EXCALIDRAW_ASSET_PATH = "/";</script>\n</head>|' \
  packages/excalidraw-app/build/index.html

mv packages/excalidraw-app/build dist
