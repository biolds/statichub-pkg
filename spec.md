# statichub-pkg — Package Catalog Repository

## Role

`statichub-pkg` is the package catalog for the StaticHub ecosystem. It contains:

- Package definitions (`meta.yaml`, optional `build.sh`) organized in a directory hierarchy.
- Homepage packages such as `home/statichub`, installed like any other package.
- A repository manifest file (`manifest.json`).

It is cloned locally by the `statichub-cli` and kept up to date via `statichub update` (git pull).

**Fundamental constraint:** every installed package must be **self-contained** — once installed in `<dest>/{path}/`, it must work fully without any Internet connection. No CDN, no external API calls, no remotely loaded resources (fonts, scripts, stylesheets, images). All dependencies must be bundled into the final installed files; for packages with `build.sh`, that means writing them into `STATICHUB_DISTDIR`.

**Default local clone paths:**

| OS    | Path                                            |
| ----- | ----------------------------------------------- |
| Linux | `~/.local/share/statichub/repo/`                |
| macOS | `~/Library/Application Support/statichub/repo/` |

---

## Repository Structure

```
manifest.json            # repository metadata (includes api_version)
packages/home/statichub/ # launcher package definition
packages/
  <category>/
    <package-name>/
      meta.yaml          # package metadata and source definition
      build.sh           # optional build script (writes to STATICHUB_DISTDIR)
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

| Situation     | Behavior                                                             |
| ------------- | -------------------------------------------------------------------- |
| `cli == repo` | OK — normal operation                                                |
| `cli < repo`  | **Blocking error** — CLI too old, user must upgrade                  |
| `cli > repo`  | **Non-blocking warning** — repo behind API, user should run `update` |

---

## Package Definition

### `meta.yaml`

```yaml
title: "CyberChef"
description: "Swiss army knife for data operations"
homepage: https://gchq.github.io/CyberChef/
live_url: "https://cyberchef.org/" # optional — public live instance
license: Apache-2.0
tags:
  - security
  - encoding

source:
  type: github_release # archive | github_release | gitlab_release | git | custom
  # ... type-specific fields (see below)

docker_image: "node:22-alpine" # required when build.sh is present — Docker image used to run the build
docker_requires_root: true # optional — run the Docker build as root, then reconcile dist ownership back to the caller
```

**Required fields:** `title`, `description`, `license`, `source.type`.

**Required when `build.sh` is present:** `docker_image` — Docker image used to run `build.sh` inside an ephemeral container.

**Optional fields:** `live_url`, `docker_requires_root`.

---

## Source Types

### `archive`

Download and extract an archive (zip, tar.gz, etc.).

#### Variant A — versioned URL (fixed version in URL)

```yaml
source:
  type: archive
  url: "https://docs.python.org/3.7/archives/python-3.7.18-docs-html.zip"
  format: zip # zip | tar.gz | tar.bz2 | tar.xz — auto-detected if omitted
  strip: 1 # path components to strip on extraction (default: 0)

upstream_version: "3.7.18" # required — version encoded in the URL
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
  asset: 'CyberChef_v.*\.zip' # regexp matched against asset URLs (see WARNING below)
  format: zip # optional, auto-detected
  strip: 0
```

The `asset` field is a **regular expression** matched against the following fields returned by `GET /repos/{owner}/{repo}/releases/latest`:

- `assets[].browser_download_url` — uploaded release assets
- `tarball_url` — source tarball (API URL, not the web UI URL)
- `zipball_url` — source zipball (API URL, not the web UI URL)

If `asset` is omitted: the single entry in `assets[]` is used automatically; if there are zero or more than one, the install fails with an explicit error.

> **WARNING — API URLs differ from the GitHub web UI**
>
> The values matched by `asset` come directly from the GitHub API response, not from what is displayed in the GitHub web UI. Always use `curl` or similar to inspect the real values before writing your regexp.
>
> Example for `excalidraw/excalidraw` at `v0.18.0`:
>
> | Field                            | Value                                                                                      |
> | -------------------------------- | ------------------------------------------------------------------------------------------ |
> | `assets[0].browser_download_url` | `https://github.com/excalidraw/excalidraw/releases/download/v0.18.0/excalidraw-0.18.0.tgz` |
> | `tarball_url`                    | `https://api.github.com/repos/excalidraw/excalidraw/tarball/v0.18.0`                       |
> | `zipball_url`                    | `https://api.github.com/repos/excalidraw/excalidraw/zipball/v0.18.0`                       |
>
> Note that `tarball_url` points to `api.github.com`, **not** to the `github.com/…/archive/…` URL shown in the web UI download section.

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
  ref_pattern: "^refs/tags/v.*$" # regexp matched against full remote ref names
```

`ref_pattern` is a regular expression matched against the full remote ref names returned by `git ls-remote --refs`. Only branch refs under `refs/heads/*` and tag refs under `refs/tags/*` are considered.

Update detection: resolve `ref_pattern` again. If multiple refs match, the CLI selects the newest one by Git date; ties are resolved by lexicographic ref name. A git package is up to date when both the resolved `git_ref` and `git_commit` stored in `catalog.json` still match the remote resolution result. `version` remains the short display name of the resolved ref.

Without `build.sh`: shallow clone, files copied directly to `<dest>/{path}/`.
With `build.sh`: shallow clone into temp dir, `build.sh` writes its output to `STATICHUB_DISTDIR`.

---

### `custom`

`build.sh` is **required**.

```yaml
source:
  type: custom

upstream_version: "1.2.3" # required — updated manually
```

Update detection: compare `upstream_version` in `meta.yaml` against `catalog.json`.
`build.sh` handles all downloading, building, and writing the final static files into `STATICHUB_DISTDIR`.

---

## `build.sh` Contract

When present, `build.sh` is executed by the CLI in a temporary working directory with the source already present (extracted archive, cloned repo, or empty dir for `custom`). It **must write the final static files into `STATICHUB_DISTDIR`**.

By default, `build.sh` runs inside an ephemeral Docker container (`docker run --rm --user <uid>:<gid> -e STATICHUB_WORKDIR=/work -e STATICHUB_DISTDIR=/dist -e STATICHUB_PKG=/pkg -e STATICHUB_UMASK=<umask> -v <workdir>:/work -v <distdir>:/dist -v <pkgdefdir>:/pkg:ro -w /work <docker_image> sh -lc 'umask "$STATICHUB_UMASK" && exec bash build.sh'`) using the image declared in `docker_image`.

If `meta.yaml` sets `docker_requires_root: true`, the CLI prints `Package "<name>" requires root inside the Docker build container`, runs the main Docker build as container root, then launches a second container with the same image to `chown` `STATICHUB_DISTDIR` back to the caller UID/GID. If that reconciliation step fails, the install fails. The `--no-docker` flag on `install`/`upgrade` bypasses Docker and runs `build.sh` directly on the host with temporary directories exposed through the same environment variables.

The CLI provides four build variables:

- `STATICHUB_PREFIX` contains the full access path (e.g., `/prefix/category/package/`).
- `STATICHUB_WORKDIR` points to the prepared source tree.
- `STATICHUB_DISTDIR` points to the output directory that must be populated.
- `STATICHUB_PKG` points to the package definition directory.

Package maintainers should use these variables instead of hard-coded `/work`, `/dist`, or `/pkg` paths.

| Source type      | Without `build.sh`                     | With `build.sh`                                  |
| ---------------- | -------------------------------------- | ------------------------------------------------ |
| `archive`        | Extract → copy files to dest           | Extract to temp dir → `build.sh` → `STATICHUB_DISTDIR`       |
| `github_release` | Resolve + download + extract → copy files to dest | Same + `build.sh` → `STATICHUB_DISTDIR`                      |
| `gitlab_release` | Resolve + download + extract → copy files to dest | Same + `build.sh` → `STATICHUB_DISTDIR`                      |
| `git`            | Shallow clone → copy files to dest     | Shallow clone to temp dir → `build.sh` → `STATICHUB_DISTDIR` |
| `custom`         | **Error** — `build.sh` required        | `build.sh` populates `STATICHUB_DISTDIR` from empty temp dir  |

---

## Homepage Packages

Launchers are normal packages installed under their package paths, for example `<dest>/home/statichub/`.

The CLI keeps them in `catalog.json`, but the homepage runtime may hide its own package entry from the visible grid. The CLI also generates a root redirect page at `<dest>/index.html` that points to the selected homepage package path.

The homepage package reads `../../catalog.json` at load time with no external requests.

**Features:**

- Cards with title, description, tags, installed version, install date.
- Each card links to `./{path}/index.html`.
- Tag filtering, text search, alphabetical / install date sorting.

---

## GitHub Actions

### `validate.yml` — triggered on `push` and `pull_request`

Validates any package added or modified in the PR/push.

**Steps:**

1. Detect modified packages: `git diff --name-only origin/main...HEAD` filtered on `packages/` → extract unique package paths.
2. Validate `manifest.json`: assert `api_version` is present and is an integer (`yq e '.api_version | tag == "!!int"' manifest.json`).
3. For each modified package:
   - Validate `meta.yaml` with `yq`:
     - Required fields present: `title`, `description`, `license`, `source.type`.
     - Type-specific rules:
       - `source.type: custom` → `build.sh` must be present.
       - `source.type: archive` with no `upstream_version` → `source.url` must be present.
       - `source.type: github_release` → `source.repo` must be present.
        - `source.type: git` → `source.url` and `source.ref_pattern` must be present.
      - If `build.sh` is present → `docker_image` must be declared.
      - If `docker_requires_root` is present → it must be a boolean.
   - If `build.sh` is present: assert it is executable (`test -x build.sh`).
   - Install the CLI from the latest GitHub release of `statichub-cli` (download pre-compiled asset for the runner OS/arch).
   - Run `statichub install {path} --dest /tmp/test`.
   - Assert `/tmp/test/{path}/` exists and is non-empty.

---

### `staticweb.yml` — scheduled daily (`0 3 * * *`)

Generates `staticweb.json` from all package metadata and publishes it to the `statichub-web` Netlify site.

**Steps:**

1. Walk all `packages/**/meta.yaml` files, sorted alphabetically by path.
2. For each package, extract: `path`, `title`, `description`, `homepage`, `live_url`, `license`, `tags`, `source.type`, and `source.repo` / `source.url` where applicable.
3. For packages with `source.type: github_release` or `source.type: git` with a `github.com` URL: call `GET /repos/{owner}/{repo}` (authenticated via `GITHUB_TOKEN` secret) → read `stargazers_count`.
4. Write `staticweb.json` (see format below).
5. Publish to Netlify: `netlify deploy --prod --dir=. --message="staticweb daily update"` using secrets `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID`.

**`staticweb.json` format:**

```json
{
  "generated_at": "2026-04-18T03:00:00Z",
  "packages": [
    {
      "path": "security/cyberchef",
      "title": "CyberChef",
      "description": "Swiss army knife for data operations",
      "homepage": "https://gchq.github.io/CyberChef/",
      "live_url": "https://cyberchef.org/",
      "license": "Apache-2.0",
      "tags": ["security", "encoding"],
      "source_type": "github_release",
      "source_repo": "gchq/CyberChef",
      "github_stars": 42000
    }
  ]
}
```

| Field          | Always present | Description                                                                                 |
| -------------- | -------------- | ------------------------------------------------------------------------------------------- |
| `path`         | yes            | Relative path under `packages/`                                                             |
| `title`        | yes            |                                                                                             |
| `description`  | yes            |                                                                                             |
| `license`      | yes            |                                                                                             |
| `tags`         | yes            | Empty array if not set                                                                      |
| `source_type`  | yes            | Value of `source.type`                                                                      |
| `homepage`     | no             | Omitted if not set in `meta.yaml`                                                           |
| `live_url`     | no             | Omitted if not set in `meta.yaml`                                                           |
| `source_repo`  | no             | `source.repo` for `github_release`/`gitlab_release`, owner/repo from `source.url` for `git` |
| `github_stars` | no             | Only for `github_release` and `git` hosted on `github.com`                                  |

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

| Constraint              | Decision                                                                                                                                                         |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `api_version`           | Explicit contract in `manifest.json`; blocking error if CLI is too old                                                                                           |
| `build.sh` optional     | Required only for `git` (with build step) and `custom`                                                                                                           |
| `docker_image` required | Required in `meta.yaml` whenever `build.sh` is present; validated by CI                                                                                          |
| `docker_requires_root` optional | Boolean opt-in for Docker-root builds; when set, the CLI runs a second Docker container to restore caller ownership on `STATICHUB_DISTDIR` |
| No Windows support      | `build.sh` requires bash; Windows out of scope                                                                                                                   |
| Rollback on failure     | CLI never modifies `<dest>/{path}/` or `catalog.json` if build fails                                                                                             |
| Homepage versioned      | Homepage launchers are versioned packages in `packages/`; the CLI generates the root redirect page in `<dest>/index.html`                                         |
| **Self-contained**      | Every installed package must work without Internet access; no CDN, no remote resources, no external API calls at runtime — all assets must be bundled into the final installed files, and into `STATICHUB_DISTDIR` when `build.sh` is used |
