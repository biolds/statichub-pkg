#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${STATICHUB_WORKDIR:?STATICHUB_WORKDIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"
PREFIX="${STATICHUB_PREFIX:?STATICHUB_PREFIX is required}"

ensure_command() {
  local command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$command_name"
    rm -rf /var/lib/apt/lists/*
    return 0
  fi

  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache "$command_name"
    return 0
  fi

  printf 'Required command not available: %s\n' "$command_name" >&2
  exit 1
}

ensure_command curl
ensure_command python3

python3 <<'PY'
from pathlib import Path

replacements = {
    "svelte.config.js": [
        (
            'import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";\n',
            'import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";\n\n'
            'const rawBasePath = process.env.STATICHUB_PREFIX || "";\n'
            'const normalizedBasePath =\n'
            '\trawBasePath === "/" ? "" : rawBasePath.replace(/\\/$/, "");\n',
        ),
        (
            '\t\tpaths: {\n\t\t\trelative: false,\n\t\t},\n',
            '\t\tpaths: {\n\t\t\tbase: normalizedBasePath,\n\t\t\trelative: false,\n\t\t},\n',
        ),
    ],
    "src/lib/components/functional/Uploader.svelte": [
        (
            '\timport { goto } from "$app/navigation";\n',
            '\timport { goto } from "$app/navigation";\n\timport { base } from "$app/paths";\n',
        ),
        (
            'goto("/convert")',
            'goto(`${base}/convert`)',
        ),
    ],
    "src/lib/components/layout/Footer.svelte": [
        (
            '<script lang="ts">\n',
            '<script lang="ts">\n\timport { base } from "$app/paths";\n',
        ),
        (
            'href="/privacy/"',
            'href={`${base}/privacy/`}',
        ),
    ],
    "src/lib/components/layout/Gradients.svelte": [
        (
            '<script lang="ts">\n',
            '<script lang="ts">\n\timport { base } from "$app/paths";\n',
        ),
        (
            '\t]);\n\n\tconst color = $derived(\n\t\tObject.values(colors).find((p) => p.matcher(page.url.pathname)) || {\n',
            '\t]);\n\n'
            '\tconst currentPath = $derived(\n'
            '\t\tpage.url.pathname.startsWith(base)\n'
            '\t\t\t? page.url.pathname.slice(base.length) || "/"\n'
            '\t\t\t: page.url.pathname,\n'
            '\t);\n\n'
            '\tconst color = $derived(\n'
            '\t\tObject.values(colors).find((p) => p.matcher(currentPath)) || {\n',
        ),
        (
            '{#if page.url.pathname === "/"}',
            '{#if currentPath === "/"}',
        ),
        (
            '{#if page.url.pathname === "/convert/" && files.files.length === 1}',
            '{#if currentPath === "/convert/" && files.files.length === 1}',
        ),
    ],
    "src/lib/components/layout/MobileLogo.svelte": [
        (
            '<script>\n',
            '<script>\n\timport { base } from "$app/paths";\n',
        ),
        (
            'href="/"',
            'href={`${base}/`}',
        ),
    ],
    "src/lib/components/layout/Navbar/Base.svelte": [
        (
            '<script lang="ts">\n\timport { browser } from "$app/environment";\n',
            '<script lang="ts">\n\timport { base } from "$app/paths";\n\timport { browser } from "$app/environment";\n',
        ),
        (
            '\timport Tooltip from "$lib/components/visual/Tooltip.svelte";\n\timport { m } from "$lib/paraglide/messages";\n\n',
            '\timport Tooltip from "$lib/components/visual/Tooltip.svelte";\n\timport { m } from "$lib/paraglide/messages";\n\n'
            '\tconst withBase = (pathname: string) => `${base}${pathname}`;\n'
            '\tconst normalizePath = (pathname: string) =>\n'
            '\t\tpathname.startsWith(base)\n'
            '\t\t\t? pathname.slice(base.length) || "/"\n'
            '\t\t\t: pathname;\n\n',
        ),
        ('url: "/",', 'url: withBase("/"),'),
        ('url: "/convert/",', 'url: withBase("/convert/"),'),
        ('url: "/settings/",', 'url: withBase("/settings/"),'),
        ('url: "/about/",', 'url: withBase("/about/"),'),
        (
            'items.findIndex((i) => i.activeMatch(page.url.pathname))',
            'items.findIndex((i) => i.activeMatch(normalizePath(page.url.pathname)))',
        ),
        (
            'item.activeMatch(page.url.pathname) && !browser',
            'item.activeMatch(normalizePath(page.url.pathname)) && !browser',
        ),
        (
            'href="/"',
            'href={`${base}/`}',
        ),
    ],
    "src/lib/converters/ffmpeg.svelte.ts": [
        (
            'import { FFmpeg } from "@ffmpeg/ffmpeg";\n',
            'import { FFmpeg } from "@ffmpeg/ffmpeg";\nimport { base } from "$app/paths";\n',
        ),
        (
            'const baseURL =\n\t\t\t\t\t"https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm";',
            'const baseURL = `${base}/ffmpeg`;',
        ),
        (
            'const baseURL =\n\t\t\t"https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm";',
            'const baseURL = `${base}/ffmpeg`;',
        ),
    ],
    "src/lib/converters/pandoc.svelte.ts": [
        (
            'import { Converter, FormatInfo } from "./converter.svelte";\n',
            'import { Converter, FormatInfo } from "./converter.svelte";\nimport { base } from "$app/paths";\n',
        ),
        (
            'fetch("/pandoc.wasm")',
            'fetch(`${base}/pandoc.wasm`)',
        ),
    ],
    "src/lib/sections/about/Donate.svelte": [
        (
            '\timport { goto } from "$app/navigation";\n',
            '\timport { goto } from "$app/navigation";\n\timport { base } from "$app/paths";\n',
        ),
        (
            'goto("/about")',
            'goto(`${base}/about`)',
        ),
    ],
    "src/routes/privacy/+page.svelte": [
        (
            '<script lang="ts">\n',
            '<script lang="ts">\n\timport { base } from "$app/paths";\n',
        ),
        (
            '"/about"',
            '`${base}/about`',
        ),
        (
            '"/settings"',
            '`${base}/settings`',
        ),
    ],
    "src/lib/util/sw.ts": [
        (
            'import { browser } from "$app/environment";\n',
            'import { browser } from "$app/environment";\nimport { base } from "$app/paths";\n',
        ),
        (
            '\t\ttry {\n\t\t\tthis.registration = await navigator.serviceWorker.register(\n\t\t\t\t"/sw.js",\n\t\t\t\t{\n\t\t\t\t\tscope: "/",\n\t\t\t\t},\n\t\t\t);\n',
            '\t\ttry {\n\t\t\tconst scope = base || "/";\n\t\t\tthis.registration = await navigator.serviceWorker.register(\n\t\t\t\t`${base}/sw.js`,\n\t\t\t\t{\n\t\t\t\t\tscope,\n\t\t\t\t},\n\t\t\t);\n',
        ),
    ],
    "src/routes/+layout.svelte": [
        (
            '\timport { goto, beforeNavigate, afterNavigate } from "$app/navigation";\n',
            '\timport { goto, beforeNavigate, afterNavigate } from "$app/navigation";\n\timport { base } from "$app/paths";\n',
        ),
        (
            'goto("/convert")',
            'goto(`${base}/convert`)',
        ),
        (
            '<link rel="manifest" href="/manifest.json" />',
            '<link rel="manifest" href={`${base}/manifest.json`} />',
        ),
    ],
    "static/manifest.json": [
        (
            '"start_url": "/"',
            '"start_url": "./"',
        ),
    ],
    "static/sw.js": [
        (
            'const CACHE_NAME = "vert-wasm-cache-v2"; // updated when workers update\n\nconst WASM_FILES = [\n\t"/pandoc.wasm",\n\t"https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm/ffmpeg-core.js",\n\t"https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm/ffmpeg-core.wasm",\n];\n',
            'const BASE_PATH = self.location.pathname.replace(/\\/sw\\.js$/, "");\nconst CACHE_NAME = "vert-wasm-cache-v3"; // updated when workers update\n\nconst WASM_FILES = [\n\t`${BASE_PATH}/pandoc.wasm`,\n\t`${BASE_PATH}/ffmpeg/ffmpeg-core.js`,\n\t`${BASE_PATH}/ffmpeg/ffmpeg-core.wasm`,\n];\n',
        ),
    ],
}

for relative_path, operations in replacements.items():
    path = Path(relative_path)
    text = path.read_text()
    for old, new in operations:
        if old not in text:
            raise SystemExit(f"Missing expected content in {relative_path}: {old!r}")
        text = text.replace(old, new)
    path.write_text(text)
PY

mkdir -p static/ffmpeg
curl -fsSL "https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm/ffmpeg-core.js" -o static/ffmpeg/ffmpeg-core.js
curl -fsSL "https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/esm/ffmpeg-core.wasm" -o static/ffmpeg/ffmpeg-core.wasm

cat > .env <<'EOF'
PUB_HOSTNAME=localhost
PUB_PLAUSIBLE_URL=
PUB_ENV=production
PUB_VERTD_URL=
PUB_DISABLE_ALL_EXTERNAL_REQUESTS=true
PUB_DISABLE_FAILURE_BLOCKS=true
PUB_DONATION_URL=
PUB_STRIPE_KEY=
EOF

STATICHUB_PREFIX="$PREFIX" bun install --frozen-lockfile
STATICHUB_PREFIX="$PREFIX" bun run build

mkdir -p "$DISTDIR"
rm -rf "$DISTDIR"/*
cp -a "$WORKDIR/build"/. "$DISTDIR/"
