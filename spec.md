# statichub-pkg — Package Catalog Repository

## Role

`statichub-pkg` is the package catalog for the StaticHub ecosystem. It contains:

- Package definitions (`meta.yaml`, optional `build.sh`) organized in a directory hierarchy.
- The local launcher homepage (`index.html`).
- An API version file (`api_version`).

It is cloned locally by the `statichub-cli` and kept up to date via `statichub update` (git pull).

**Default local clone paths:**

| OS      | Path                                            |
| ------- | ----------------------------------------------- |
| Linux   | `~/.local/share/statichub/repo/`                |
| macOS   | `~/Library/Application Support/statichub/repo/` |

---

## Repository Structure

```
manifest.json            # repository metadata (includes api_version)
index.html               # local launcher homepage
packages/
  <category>/
    <package-name>/
      meta.yaml          # package metadata and source definition
      build.sh           # optional build script (produces ./dist/)
```

Example packages:

```
packages/
  office/
    excalidraw/
      meta.yaml          # type: git, requires build.sh
      build.sh
  security/
    cyberchef/
      meta.yaml          # type: github_release, no build.sh needed
  doc/
    dev/
      lang/
        python/
          3.7/
            meta.yaml    # type: archive, versioned URL
          3.11/
            meta.yaml    # type: archive, versioned URL
```

---

## `manifest.json`

JSON file at the repository root containing repository metadata, including the `api_version` field — an integer representing the API contract between the CLI and this repository (meta.yaml schema, build.sh contract, catalog.json schema, index.html interface).

```json
{
  "api_version": 1
}
```

The CLI embeds its own `API_VERSION` and compares it on each operation:

| Situation     | Behavior                                                              |
| ------------- | --------------------------------------------------------------------- |
| `cli == repo` | OK — normal operation                                                 |
| `cli < repo`  | **Blocking error** — CLI too old, user must upgrade                   |
| `cli > repo`  | **Non-blocking warning** — repo behind API, user should run `update`  |

---

## Package Definition

### `meta.yaml`

```yaml
title: "CyberChef"
description: "Swiss army knife for data operations"
homepage: https://gchq.github.io/CyberChef/
live_url: "https://cyberchef.org/"  # optional — public live instance
license: Apache-2.0
tags:
  - security
  - encoding

source:
  type: github_release  # archive | github_release | gitlab_release | git | custom
  # ... type-specific fields (see below)

dependencies:           # optional — system binaries required by build.sh
  - npm
```

**Required fields:** `title`, `description`, `license`, `source.type`.

**Optional fields:** `live_url`, `dependencies`.

---

## Source Types

### `archive`

Download and extract an archive (zip, tar.gz, etc.).

#### Variant A — versioned URL (fixed version in URL)

```yaml
source:
  type: archive
  url: "https://docs.python.org/3.7/archives/python-3.7.18-docs-html.zip"
  format: zip      # zip | tar.gz | tar.bz2 | tar.xz — auto-detected if omitted
  strip: 1         # path components to strip on extraction (default: 0)

upstream_version: "3.7.18"  # required — version encoded in the URL
```

Update detection: compare `upstream_version` in `meta.yaml` against `catalog.json`. No network request needed.

#### Variant B — latest URL (no version in URL)

```yaml
source:
  type: archive
  url: "https://example.com/myapp/latest.tar.gz"
  format: tar.gz
  strip: 1
# no upstream_version
```

Update detection: `HEAD` request → read `ETag`, `Last-Modified`, or `Content-Length` headers → compare with values stored in `catalog.json`. Error if none of these headers are present.

---

### `github_release`

```yaml
source:
  type: github_release
  repo: "gchq/CyberChef"
  asset: "CyberChef_v*.zip"  # glob pattern on asset name (first asset if omitted)
  format: zip                 # optional, auto-detected
  strip: 0
```

Update detection: `GET /repos/{owner}/{repo}/releases/latest` → `tag_name` compared to `catalog.json`.

---

### `gitlab_release`

Same as `github_release` but uses the GitLab releases API.

---

### `git`

```yaml
source:
  type: git
  url: "https://github.com/excalidraw/excalidraw"
  ref: "master"  # branch, tag, or commit SHA
```

Update detection:
- **Branch:** `git ls-remote` → compare SHA with `catalog.json`.
- **Tag:** fixed version, updated only when `meta.yaml` is modified via PR.
- **Commit SHA:** never updated automatically.

Without `build.sh`: shallow clone, files copied to `dist/`.
With `build.sh`: shallow clone into temp dir, `build.sh` produces `./dist/`.

---

### `custom`

`build.sh` is **required**.

```yaml
source:
  type: custom

upstream_version: "1.2.3"  # required — updated manually
```

Update detection: compare `upstream_version` in `meta.yaml` against `catalog.json`.
`build.sh` handles all downloading, building, and producing `./dist/`.

---

## `build.sh` Contract

When present, `build.sh` is executed by the CLI in a temporary working directory with the source already present (extracted archive, cloned repo, or empty dir for `custom`). It **must produce `./dist/`** containing the final static files to deploy.

| Source type      | Without `build.sh`                      | With `build.sh`                                |
| ---------------- | --------------------------------------- | ---------------------------------------------- |
| `archive`        | Extract → copy `dist/` to dest          | Extract to temp dir → `build.sh` → `dist/`     |
| `github_release` | Resolve + download + extract → `dist/`  | Same + `build.sh` → `dist/`                    |
| `gitlab_release` | Resolve + download + extract → `dist/`  | Same + `build.sh` → `dist/`                    |
| `git`            | Shallow clone → copy files to `dist/`   | Shallow clone to temp dir → `build.sh` → `dist/` |
| `custom`         | **Error** — `build.sh` required         | `build.sh` produces `dist/` from empty temp dir |

---

## `index.html` — Local Launcher Homepage

Served from `<dest>/` after the first `statichub install`. The CLI copies it there on first install and updates it after `statichub update` if a newer version is available.

It reads `./catalog.json` at load time (client-side JavaScript) with no external requests.

**Features:**
- Cards with title, description, tags, installed version, install date.
- Each card links to `./{path}/index.html`.
- Tag filtering, text search, alphabetical / install date sorting.

---

## GitHub Action — `staticweb.json`

A GitHub Action triggered on each push to the main branch generates `staticweb.json` aggregating all package metadata from `meta.yaml` files. This file is pushed to the `statichub-web` repository and serves as the data contract for the public catalog website.

---

## Adding a Package

1. Fork `statichub-pkg`.
2. Create `packages/{path}/meta.yaml`. Add `build.sh` if needed.
3. Test locally:
   ```bash
   statichub install {path} --dest /tmp/test
   ```
4. Open a pull request on `statichub-pkg`.

---

## Constraints

| Constraint           | Decision                                                                              |
| -------------------- | ------------------------------------------------------------------------------------- |
| `api_version`        | Explicit contract in `manifest.json`; blocking error if CLI is too old                                   |
| `build.sh` optional  | Required only for `git` (with build step) and `custom`                                |
| No Windows support   | `build.sh` requires bash; Windows out of scope                                        |
| Rollback on failure  | CLI never modifies `<dest>/{path}/` or `catalog.json` if build fails                  |
| Homepage versioned   | `index.html` is part of this repo and updated in `<dest>/` after `statichub update`   |
