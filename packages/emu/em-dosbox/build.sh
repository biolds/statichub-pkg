#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${STATICHUB_WORKDIR:?STATICHUB_WORKDIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"

write_entrypoint() {
  local target="$1"

  cat >"$DISTDIR/index.html" <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=$target">
    <title>Em-DOSBox</title>
  </head>
  <body>
    <script>
      window.location.replace(${target@Q});
    </script>
    <p>Redirecting to <a href="$target">$target</a>.</p>
  </body>
</html>
EOF
}

require_output() {
  local path="$1"

  if [ ! -f "$path" ]; then
    echo "Error: expected build output '$path' was not produced." >&2
    exit 1
  fi
}

cd "$WORKDIR"

export PATH="/emsdk:/emsdk/node/current/bin:/emsdk/upstream/bin:/emsdk/llvm/clang/bin:$PATH"

if [ -f /emsdk/emsdk_env.sh ]; then
  # The image already contains the configured SDK; sourcing keeps PATH/tool vars aligned.
  source /emsdk/emsdk_env.sh
fi

apt-get update -qq
apt-get install -y -qq autoconf automake libtool pkg-config m4 gettext python3 python-is-python3

./autogen.sh
embuilder build sdl2
emconfigure ./configure
emmake make

require_output "$WORKDIR/src/dosbox.html"
require_output "$WORKDIR/src/dosbox.js"
require_output "$WORKDIR/src/dosbox.wasm"
require_output "$WORKDIR/src/packager.py"

mkdir -p "$DISTDIR"
cp "$WORKDIR/src/dosbox.html" "$DISTDIR/"
cp "$WORKDIR/src/dosbox.js" "$DISTDIR/"
cp "$WORKDIR/src/dosbox.wasm" "$DISTDIR/"
cp "$WORKDIR/src/packager.py" "$DISTDIR/"

write_entrypoint "dosbox.html"
