#!/usr/bin/env bash
set -euo pipefail

DATADIR="${STATICHUB_DATADIR:?STATICHUB_DATADIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"

STATE_DIR="$DISTDIR/_statichub"
STATE_HTML="$STATE_DIR/launch.html"
STATE_DATA="$STATE_DIR/launch.data"
CONTRACT_FILE="$DATADIR/statichub.json"

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

reset_to_default() {
  rm -rf "$STATE_DIR"
  write_entrypoint "dosbox.html"
}

if [ ! -f "$CONTRACT_FILE" ]; then
  reset_to_default
  exit 0
fi

if [ ! -f "$DISTDIR/packager.py" ] || [ ! -f "$DISTDIR/dosbox.html" ] || [ ! -f "$DISTDIR/dosbox.js" ] || [ ! -f "$DISTDIR/dosbox.wasm" ]; then
  echo "Error: installed Em-DOSBox runtime is incomplete; expected dosbox runtime files and packager.py." >&2
  exit 1
fi

validation_json="$({
  python3 - "$DATADIR" "$CONTRACT_FILE" <<'PY'
import json
import os
import sys

data_dir = sys.argv[1]
contract_path = sys.argv[2]

with open(contract_path, 'r', encoding='utf-8') as handle:
    contract = json.load(handle)

if not isinstance(contract, dict):
    raise SystemExit('Error: statichub.json must contain a JSON object.')

allowed_keys = {'executable', 'args'}
unknown_keys = sorted(set(contract.keys()) - allowed_keys)
if unknown_keys:
    raise SystemExit('Error: statichub.json contains unsupported keys: ' + ', '.join(unknown_keys))

result = {}

if 'executable' in contract:
    executable = contract['executable']
    if not isinstance(executable, str) or not executable:
        raise SystemExit('Error: statichub.json executable must be a non-empty string.')
    if '\\' in executable:
        raise SystemExit('Error: statichub.json executable must use forward slashes only.')
    if executable.startswith('/'):
        raise SystemExit('Error: statichub.json executable must be a relative path.')

    segments = executable.split('/')
    if any(segment in ('', '.', '..') for segment in segments):
        raise SystemExit('Error: statichub.json executable contains an invalid path segment.')

    target_path = os.path.join(data_dir, *segments)
    if not os.path.isfile(target_path):
        raise SystemExit('Error: statichub.json executable target was not found: ' + executable)

    extension = os.path.splitext(executable)[1].upper()
    if extension not in ('.EXE', '.COM', '.BAT'):
        raise SystemExit('Error: statichub.json executable must end in .EXE, .COM, or .BAT.')

    result['executable'] = executable

args = contract.get('args', [])
if not isinstance(args, list):
    raise SystemExit('Error: statichub.json args must be an array of strings.')
for index, value in enumerate(args):
    if not isinstance(value, str):
        raise SystemExit(f'Error: statichub.json args[{index}] must be a string.')
    if value == '':
        raise SystemExit(f'Error: statichub.json args[{index}] must not be empty.')

result['args'] = args

print(json.dumps(result))
PY
})"

workdir="$(mktemp -d)"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

cp "$DISTDIR/dosbox.html" "$workdir/"
cp "$DISTDIR/packager.py" "$workdir/"

python3 - "$validation_json" "$workdir" "$DATADIR" <<'PY'
import json
import os
import subprocess
import sys

contract = json.loads(sys.argv[1])
workdir = sys.argv[2]
data_dir = sys.argv[3]

cmd = [sys.executable, 'packager.py', 'launch', data_dir]
if 'executable' in contract:
    cmd.append(contract['executable'])

subprocess.run(cmd, cwd=workdir, check=True)
PY

if [ ! -f "$workdir/launch.html" ] || [ ! -f "$workdir/launch.data" ]; then
  echo "Error: upstream packager did not produce launch.html and launch.data." >&2
  exit 1
fi

patched_html="$workdir/launch.patched.html"
python3 - "$validation_json" "$workdir/launch.html" "$patched_html" <<'PY'
import json
import re
import sys

contract = json.loads(sys.argv[1])
source_path = sys.argv[2]
target_path = sys.argv[3]

if 'executable' in contract:
    arguments = [f'./{contract["executable"]}', *contract['args']]
else:
    arguments = contract['args']

arguments_js = ', '.join(json.dumps(value) for value in arguments)

with open(source_path, 'r', encoding='utf-8') as handle:
    html = handle.read()

html = html.replace('src="dosbox.js"', 'src="../dosbox.js"')
html = html.replace("src='dosbox.js'", "src='../dosbox.js'")
html = html.replace('src=dosbox.js', 'src=../dosbox.js')

html, replacements = re.subn(
    r"Module\['arguments'\] = \[[^\n]*\];",
    "Module['arguments'] = [ " + arguments_js + " ];",
    html,
    count=1,
)

if replacements != 1:
    raise SystemExit('Error: could not update launch arguments in generated launch.html.')

with open(target_path, 'w', encoding='utf-8') as handle:
    handle.write(html)
PY

rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
mv "$patched_html" "$STATE_HTML"
mv "$workdir/launch.data" "$STATE_DATA"

write_entrypoint "_statichub/launch.html"
