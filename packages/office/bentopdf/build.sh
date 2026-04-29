#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${STATICHUB_WORKDIR:?STATICHUB_WORKDIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"
PKGDIR="${STATICHUB_PKG:?STATICHUB_PKG is required}"
PREFIX="${STATICHUB_PREFIX:?STATICHUB_PREFIX is required}"

OCR_LANGUAGES="eng,fra,deu,spa,ita,por,nld,tur,rus,ukr,ara,jpn,kor,chi_sim,chi_tra"
TESSDATA_VERSION="4.0.0_best_int"
GS_TMP=""
CPDF_TMP=""
TESS_TMP=""

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

read_ts_constant() {
  local key="$1"

  KEY="$key" node <<'NODE'
const fs = require("fs");

const key = process.env.KEY;
const source = fs.readFileSync("src/js/const/cdn-version.ts", "utf8");
const pattern = new RegExp(`${key}\\s*:\\s*["']([^"']+)["']`);
const match = source.match(pattern);

if (!match) {
  throw new Error(`Missing ${key} version in src/js/const/cdn-version.ts`);
}

process.stdout.write(match[1]);
NODE
}

resolve_font_manifest() {
  OCR_LANGUAGE_SET="$OCR_LANGUAGES" node <<'NODE'
const fs = require("fs");

const source = fs.readFileSync("src/js/config/font-mappings.ts", "utf8");
const selected = (process.env.OCR_LANGUAGE_SET || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);
const sections = source.split("export const fontFamilyToUrl");
const languageSection = sections[0] || "";
const fontSection = sections[1] || "";
const languageToFamily = {};
const fontFamilyToUrl = {};
let match;
const languagePattern = /^\s*([a-z_]+):\s*'([^']+)',/gm;
while ((match = languagePattern.exec(languageSection)) !== null) {
  languageToFamily[match[1]] = match[2];
}
const fontPattern = /^\s*'([^']+)':\s*'([^']+)',/gm;
while ((match = fontPattern.exec(fontSection)) !== null) {
  fontFamilyToUrl[match[1]] = match[2];
}
const families = new Set(["Noto Sans"]);
for (const lang of selected) {
  families.add(languageToFamily[lang] || "Noto Sans");
}
const lines = Array.from(families)
  .sort()
  .map((family) => {
    const url = fontFamilyToUrl[family] || fontFamilyToUrl["Noto Sans"];
    const fileName = url.split("/").pop();
    return [family, url, fileName].join("\t");
  });

process.stdout.write(lines.join("\n"));
NODE
}

ensure_command curl
ensure_command git

PATCH_FILE="0001-disable-runtime-github-api-fetch.patch"
if [ -f "$PATCH_FILE" ]; then
  git -c safe.directory="$WORKDIR" apply "$PATCH_FILE"
elif [ -f "$PKGDIR/$PATCH_FILE" ]; then
  git -c safe.directory="$WORKDIR" apply "$PKGDIR/$PATCH_FILE"
else
  printf 'Missing patch file: %s\n' "$PATCH_FILE" >&2
  exit 1
fi

PYMUPDF_VERSION="$(read_ts_constant pymupdf)"
GS_VERSION="$(read_ts_constant ghostscript)"
TESSERACT_VERSION="$(node -p "require('./package.json').dependencies['tesseract.js'].replace(/^[^0-9]*/, '')")"
TESSERACT_CORE_VERSION="$(node -p "require('./package-lock.json').packages['node_modules/tesseract.js-core'].version")"
FONT_MANIFEST="$(resolve_font_manifest)"

npm install --no-fund --no-audit

rm -rf "$WORKDIR/dist"

BASE_URL="$PREFIX" \
VITE_WASM_PYMUPDF_URL="${PREFIX}wasm/pymupdf/" \
VITE_WASM_GS_URL="${PREFIX}wasm/gs/" \
VITE_WASM_CPDF_URL="${PREFIX}wasm/cpdf/" \
VITE_TESSERACT_WORKER_URL="${PREFIX}wasm/ocr/worker.min.js" \
VITE_TESSERACT_CORE_URL="${PREFIX}wasm/ocr/core" \
VITE_TESSERACT_LANG_URL="${PREFIX}wasm/ocr/lang-data" \
VITE_TESSERACT_AVAILABLE_LANGUAGES="$OCR_LANGUAGES" \
VITE_OCR_FONT_BASE_URL="${PREFIX}wasm/ocr/fonts" \
VITE_CORS_PROXY_URL="" \
npm run build

ASSET_ROOT="$WORKDIR/dist/wasm"
PYMUPDF_DIR="$ASSET_ROOT/pymupdf"
GS_DIR="$ASSET_ROOT/gs"
CPDF_DIR="$ASSET_ROOT/cpdf"
OCR_CORE_DIR="$ASSET_ROOT/ocr/core"
OCR_LANG_DIR="$ASSET_ROOT/ocr/lang-data"
OCR_FONT_DIR="$ASSET_ROOT/ocr/fonts"

mkdir -p "$PYMUPDF_DIR" "$GS_DIR" "$CPDF_DIR" "$OCR_CORE_DIR" "$OCR_LANG_DIR" "$OCR_FONT_DIR"

WASM_TMP="$(mktemp -d)"
trap 'rm -rf "$WASM_TMP" "$GS_TMP" "$CPDF_TMP" "$TESS_TMP"' EXIT

(cd "$WASM_TMP" && npm pack "@bentopdf/pymupdf-wasm@${PYMUPDF_VERSION}" --quiet >/dev/null)
tar -xzf "$WASM_TMP"/bentopdf-pymupdf-wasm-*.tgz -C "$PYMUPDF_DIR" --strip-components=1

(cd "$WASM_TMP" && npm pack "@bentopdf/gs-wasm@${GS_VERSION}" --quiet >/dev/null)
GS_TMP="$(mktemp -d)"
tar -xzf "$WASM_TMP"/bentopdf-gs-wasm-*.tgz -C "$GS_TMP"
if [ -d "$GS_TMP/package/assets" ]; then
  cp -a "$GS_TMP/package/assets/." "$GS_DIR/"
else
  cp -a "$GS_TMP/package/." "$GS_DIR/"
fi

CPDF_TMP="$(mktemp -d)"
(cd "$WASM_TMP" && npm pack coherentpdf --quiet >/dev/null)
tar -xzf "$WASM_TMP"/coherentpdf-*.tgz -C "$CPDF_TMP"
if [ -d "$CPDF_TMP/package/dist" ]; then
  cp -a "$CPDF_TMP/package/dist/." "$CPDF_DIR/"
else
  cp -a "$CPDF_TMP/package/." "$CPDF_DIR/"
fi

TESS_TMP="$(mktemp -d)"
(cd "$WASM_TMP" && npm pack "tesseract.js@${TESSERACT_VERSION}" --quiet >/dev/null)
tar -xzf "$WASM_TMP"/tesseract.js-*.tgz -C "$TESS_TMP"
cp "$TESS_TMP/package/dist/worker.min.js" "$ASSET_ROOT/ocr/worker.min.js"

(cd "$WASM_TMP" && npm pack "tesseract.js-core@${TESSERACT_CORE_VERSION}" --quiet >/dev/null)
tar -xzf "$WASM_TMP"/tesseract.js-core-*.tgz -C "$OCR_CORE_DIR" --strip-components=1

IFS=',' read -r -a OCR_LANGUAGE_LIST <<< "$OCR_LANGUAGES"
for lang in "${OCR_LANGUAGE_LIST[@]}"; do
  curl -fsSL "https://cdn.jsdelivr.net/npm/@tesseract.js-data/${lang}/${TESSDATA_VERSION}/${lang}.traineddata.gz" -o "$OCR_LANG_DIR/${lang}.traineddata.gz"
done

while IFS=$'\t' read -r _font_family font_url font_file; do
  [ -n "$font_file" ] || continue
  curl -fsSL "$font_url" -o "$OCR_FONT_DIR/$font_file"
done <<< "$FONT_MANIFEST"

cp -a "$WORKDIR/dist/coherentpdf.browser.min.js" "$CPDF_DIR/coherentpdf.browser.min.js"

mkdir -p "$DISTDIR"
rm -rf "$DISTDIR"/*
cp -a "$WORKDIR/dist/." "$DISTDIR/"
