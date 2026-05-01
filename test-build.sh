#!/usr/bin/env bash
set -euo pipefail

# test-build.sh - Manually verify a package build

if [ $# -ne 1 ]; then
  echo "Usage: $0 <package-path>"
  echo "Example: $0 office/excalidraw"
  exit 1
fi

PKG_PATH="$1"
PKG_DIR="packages/$PKG_PATH"
META_FILE="$PKG_DIR/meta.yaml"
BUILD_SH="$PKG_DIR/build.sh"
INJECT_SH="$PKG_DIR/inject.sh"
SRC_DIR="$PKG_DIR/src"
WORK_DIR="$PKG_DIR/work"
DIST_DIR="$PKG_DIR/dist"
BUILD_DIR="$PKG_DIR/build"

resolve_latest_matching_git_tag() {
  local url="$1"
  local pattern="$2"
  local matches=()
  local ref_name=""
  local tag=""

  while IFS=$'\t' read -r _ ref_name; do
    tag="${ref_name#refs/tags/}"
    if [[ "$tag" =~ ^${pattern}$ ]]; then
      matches+=("$tag")
    fi
  done < <(git ls-remote --tags --refs "$url")

  if [ ${#matches[@]} -eq 0 ]; then
    return 1
  fi

  printf '%s\n' "${matches[@]}" | sort -V | tail -n 1
}

if [ ! -d "$PKG_DIR" ]; then
  echo "Error: Package directory '$PKG_DIR' not found."
  exit 1
fi

if [ ! -f "$META_FILE" ]; then
  echo "Error: '$META_FILE' not found."
  exit 1
fi

# 1. Extract metadata
echo "--- Extracting metadata ---"
BUILD_DOCKER_IMAGE=$(yq -r '.build_docker_image // ""' "$META_FILE")
INJECT_DOCKER_IMAGE=$(yq -r '.inject_docker_image // ""' "$META_FILE")
SOURCE_TYPE=$(yq -r '.source.type' "$META_FILE")

if [ -f "$BUILD_SH" ] && [ -z "$BUILD_DOCKER_IMAGE" ]; then
  echo "Error: 'build_docker_image' not specified in meta.yaml"
  exit 1
fi

if [ -f "$INJECT_SH" ] && [ -z "$INJECT_DOCKER_IMAGE" ]; then
  echo "Error: 'inject_docker_image' not specified in meta.yaml"
  exit 1
fi

echo "Package: $PKG_PATH"
echo "Build:   ${BUILD_DOCKER_IMAGE:-<none>}"
echo "Inject:  ${INJECT_DOCKER_IMAGE:-<none>}"
echo "Source:  $SOURCE_TYPE"

BUILD_PREFIX="${STATICHUB_PREFIX:-/}"
echo "Prefix:  $BUILD_PREFIX"

# 2. Handle Source Download
if [ ! -d "$SRC_DIR" ]; then
  echo "--- Downloading sources into src/ ---"
  mkdir -p "$SRC_DIR"

  STRIP=$(yq -r '.source.strip // 0' "$META_FILE")

  case "$SOURCE_TYPE" in
  git)
    URL=$(yq -r '.source.url' "$META_FILE")
    REF=$(yq -r '.source.ref' "$META_FILE")
    REF_TYPE=$(yq -r '.source.ref_type // "ref"' "$META_FILE")

    case "$REF_TYPE" in
    ref)
      ;;
    tag_pattern)
      REF_PATTERN="$REF"
      echo "Resolving latest tag matching '$REF_PATTERN'..."
      if ! REF=$(resolve_latest_matching_git_tag "$URL" "$REF_PATTERN"); then
        echo "Error: Could not resolve any tag matching '$REF_PATTERN' from $URL"
        exit 1
      fi
      echo "Resolved tag pattern '$REF_PATTERN' to '$REF'"
      ;;
    *)
      echo "Error: Unsupported git ref type '$REF_TYPE'"
      exit 1
      ;;
    esac

    echo "Cloning $URL ($REF)..."
    git clone --depth 1 --branch "$REF" "$URL" "$SRC_DIR"
    ;;

  github_release)
    REPO=$(yq -r '.source.repo' "$META_FILE")
    ASSET_PATTERN=$(yq -r '.source.asset' "$META_FILE")
    echo "Fetching latest release for $REPO..."

    RELEASE_JSON=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")

    if [ "$ASSET_PATTERN" == "null" ] || [[ "$ASSET_PATTERN" == *"tarball"* ]]; then
      DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.tarball_url')
      FORMAT="tar.gz"
    else
      # Filter assets by regex
      DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r --arg pat "$ASSET_PATTERN" '.assets[] | select(.browser_download_url | test($pat)) | .browser_download_url' | head -n 1)
      # Detect format from URL
      if [[ "$DOWNLOAD_URL" == *.zip ]]; then FORMAT="zip"; else FORMAT="tar.gz"; fi
    fi

    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
      echo "Error: Could not find download URL for $REPO"
      exit 1
    fi

    echo "Downloading $DOWNLOAD_URL..."
    TEMP_ARCHIVE=$(mktemp)
    curl -L -o "$TEMP_ARCHIVE" "$DOWNLOAD_URL"

    if [ "$FORMAT" == "zip" ]; then
      unzip -q "$TEMP_ARCHIVE" -d "$SRC_DIR"
      # Handle strip manually for zip if needed (unzip doesn't have --strip-components)
      if [ "$STRIP" -gt 0 ]; then
        # This is a simplified strip for 1 level
        TOP_DIR=$(ls -1 "$SRC_DIR" | head -n 1)
        mv "$SRC_DIR/$TOP_DIR"/* "$SRC_DIR/"
        rmdir "$SRC_DIR/$TOP_DIR"
      fi
    else
      tar -xzf "$TEMP_ARCHIVE" -C "$SRC_DIR" --strip-components="$STRIP"
    fi
    rm "$TEMP_ARCHIVE"
    ;;

  archive)
    URL=$(yq -r '.source.url' "$META_FILE")
    echo "Downloading $URL..."
    TEMP_ARCHIVE=$(mktemp)
    curl -L -o "$TEMP_ARCHIVE" "$URL"
    # Detect format (simplified)
    if [[ "$URL" == *.zip ]]; then
      unzip -q "$TEMP_ARCHIVE" -d "$SRC_DIR"
      if [ "$STRIP" -gt 0 ]; then
        TOP_DIR=$(ls -1 "$SRC_DIR" | head -n 1)
        mv "$SRC_DIR/$TOP_DIR"/* "$SRC_DIR/"
        rmdir "$SRC_DIR/$TOP_DIR"
      fi
    else
      tar -xzf "$TEMP_ARCHIVE" -C "$SRC_DIR" --strip-components="$STRIP"
    fi
    rm "$TEMP_ARCHIVE"
    ;;

  custom)
    echo "Custom source: nothing to download."
    ;;

  *)
    echo "Error: Unsupported source type '$SOURCE_TYPE'"
    exit 1
    ;;
  esac
else
  echo "--- Reusing existing src/ directory ---"
fi

# 3. Prepare Build Or Direct Install Content
if [ -f "$BUILD_SH" ]; then
  echo "--- Preparing build ---"
  rm -rf "$WORK_DIR" "$DIST_DIR"
  mkdir -p "$WORK_DIR" "$DIST_DIR"
  cp -a "$SRC_DIR"/. "$WORK_DIR/"

  find "$PKG_DIR" -maxdepth 1 -not -path "$PKG_DIR" -not -name "meta.yaml" -not -name "src" -not -name "work" -not -name "dist" -not -name "build" -exec cp -r {} "$WORK_DIR/" \;

  echo "--- Running build in Docker ($BUILD_DOCKER_IMAGE) ---"
  chmod +x "$WORK_DIR/build.sh"

  DOCKER_ARGS=(
    run
    --rm
    -e "STATICHUB_PREFIX=$BUILD_PREFIX"
    -e "STATICHUB_WORKDIR=/work"
    -e "STATICHUB_DISTDIR=/dist"
    -e "STATICHUB_PKG=/pkg"
    -v "$(pwd)/$WORK_DIR:/work"
    -v "$(pwd)/$DIST_DIR:/dist"
    -v "$(pwd)/$PKG_DIR:/pkg:ro"
    -w /work
    "$BUILD_DOCKER_IMAGE"
    sh
    -lc
    'umask "${STATICHUB_UMASK:-0022}" && exec bash build.sh'
  )

  docker "${DOCKER_ARGS[@]}"

  docker run --rm \
    -e "STATICHUB_HOST_UID=$(id -u)" \
    -e "STATICHUB_HOST_GID=$(id -g)" \
    -v "$(pwd)/$DIST_DIR:/dist" \
    "$BUILD_DOCKER_IMAGE" \
    sh -lc 'chown -R "$STATICHUB_HOST_UID:$STATICHUB_HOST_GID" /dist'

  if [ -d "$DIST_DIR" ] && [ -n "$(ls -A "$DIST_DIR")" ]; then
    echo "--- Moving output to build/ ---"
    rm -rf "$BUILD_DIR"
    mv "$DIST_DIR" "$BUILD_DIR"
  else
    echo "Error: Build did not produce any output in '/dist'."
    exit 1
  fi
else
  echo "--- No build.sh, using source files directly ---"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  cp -a "$SRC_DIR"/. "$BUILD_DIR/"
fi

if [ -f "$INJECT_SH" ]; then
  echo "--- Running inject in Docker ($INJECT_DOCKER_IMAGE) ---"
  DATA_DIR="$PKG_DIR/inject_data"
  if [ ! -d "$DATA_DIR" ]; then
    DATA_DIR=$(mktemp -d)
    trap 'rm -rf "$DATA_DIR"' EXIT
  fi

  INJECT_WORK_DIR=$(mktemp -d)
  trap 'rm -rf "$INJECT_WORK_DIR"' EXIT
  cp -a "$PKG_DIR"/. "$INJECT_WORK_DIR/"
  chmod +x "$INJECT_WORK_DIR/inject.sh"

  docker run --rm \
    -e "STATICHUB_WORKDIR=/work" \
    -e "STATICHUB_DISTDIR=/dist" \
    -e "STATICHUB_PKG=/pkg" \
    -e "STATICHUB_DATADIR=/data" \
    -v "$INJECT_WORK_DIR:/work" \
    -v "$(pwd)/$BUILD_DIR:/dist" \
    -v "$(pwd)/$PKG_DIR:/pkg:ro" \
    -v "$(pwd)/$DATA_DIR:/data:ro" \
    -w /work \
    "$INJECT_DOCKER_IMAGE" \
    sh -lc 'umask "${STATICHUB_UMASK:-0022}" && exec bash inject.sh'

  docker run --rm \
    -e "STATICHUB_HOST_UID=$(id -u)" \
    -e "STATICHUB_HOST_GID=$(id -g)" \
    -v "$(pwd)/$BUILD_DIR:/dist" \
    "$INJECT_DOCKER_IMAGE" \
    sh -lc 'chown -R "$STATICHUB_HOST_UID:$STATICHUB_HOST_GID" /dist'
fi

echo "Success! Final output is in '$BUILD_DIR'"
