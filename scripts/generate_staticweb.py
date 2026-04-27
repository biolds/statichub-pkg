#!/usr/bin/env python3
"""Generate staticweb.json from package metadata files."""

import datetime
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
import urllib.parse
import yaml
from datetime import datetime, timezone


PACKAGES_DIR = "packages"
OUTPUT_FILE = "staticweb.json"
GITHUB_API_BASE = "https://api.github.com"
RELEASES_API = f"{GITHUB_API_BASE}/repos"


def walk_packages(packages_dir):
    """Walk packages directory and yield paths containing meta.yaml."""
    for category in os.listdir(packages_dir):
        category_path = os.path.join(packages_dir, category)
        if not os.path.isdir(category_path):
            continue
        for package in os.listdir(category_path):
            package_path = os.path.join(category_path, package)
            meta_path = os.path.join(package_path, "meta.yaml")
            if os.path.isfile(meta_path):
                yield category, package, meta_path


def load_meta(meta_path):
    """Load and parse meta.yaml file."""
    with open(meta_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def make_path(category, package):
    """Construct package path from category and package name."""
    return f"{category}/{package}"


def detect_version_git(url, ref_pattern):
    """Detect version for git source using ls-remote."""
    if not url or not ref_pattern:
        return None
    try:
        import re
        pattern = re.compile(ref_pattern)
        result = subprocess.run(
            ["git", "ls-remote", "--refs", url],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return None
        lines = result.stdout.strip().split("\n")
        matching_refs = []
        for line in lines:
            parts = line.split()
            if len(parts) >= 2:
                ref = parts[1]
                if pattern.match(ref):
                    matching_refs.append(ref)
        if not matching_refs:
            return None
        last_ref = matching_refs[-1]
        if last_ref.startswith("refs/tags/"):
            last_ref = last_ref[len("refs/tags/"):]
        if last_ref.startswith("refs/heads/"):
            last_ref = last_ref[len("refs/heads/"):]
        if last_ref.endswith("^{}"):
            last_ref = last_ref[:-3]
        return last_ref
    except Exception:
        return None


def detect_version_github_release(repo):
    """Detect version for github_release source using GitHub API."""
    url = f"{RELEASES_API}/{repo}/releases/latest"
    try:
        req = urllib.request.Request(url)
        req.add_header("Accept", "application/vnd.github+json")
        if os.environ.get("GITHUB_TOKEN"):
            req.add_header("Authorization", f"token {os.environ['GITHUB_TOKEN']}")
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.load(resp)
            return data.get("tag_name")
    except Exception:
        return None


def detect_version_gitlab_release(repo):
    """Detect version for gitlab_release source using GitLab API."""
    project = urllib.parse.quote(repo, safe="")
    url = f"https://gitlab.com/api/v4/projects/{project}/releases/permalink/latest"
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            data = json.load(resp)
            return data.get("tag_name")
    except Exception:
        return None


def detect_version_archive(url, upstream_version):
    """Detect version for archive source using HTTP headers."""
    if upstream_version:
        return upstream_version
    try:
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=30) as resp:
            etag = resp.headers.get("ETag")
            if etag:
                return etag.strip('"')
            last_modified = resp.headers.get("Last-Modified")
            if last_modified:
                return last_modified
            return None
    except Exception:
        return None


def detect_version(meta):
    """Detect version based on source type."""
    source = meta.get("source", {})
    source_type = source.get("type", "")

    if source_type == "git":
        return detect_version_git(source.get("url", ""), source.get("ref_pattern", ""))

    if source_type == "github_release":
        return detect_version_github_release(source.get("repo", ""))

    if source_type == "gitlab_release":
        return detect_version_gitlab_release(source.get("repo", ""))

    if source_type == "archive":
        return detect_version_archive(
            source.get("url", ""),
            meta.get("upstream_version"),
        )

    if source_type == "custom":
        return meta.get("upstream_version")

    return None


def fetch_stars(repo):
    """Fetch star count from GitHub API."""
    url = f"{RELEASES_API}/{repo}"
    try:
        req = urllib.request.Request(url)
        req.add_header("Accept", "application/vnd.github+json")
        if os.environ.get("GITHUB_TOKEN"):
            req.add_header("Authorization", f"token {os.environ['GITHUB_TOKEN']}")
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.load(resp)
            return data.get("stargazers_count")
    except Exception:
        return None


def detect_icon(package_dir):
    """Return the icon filename if present, else None."""
    for candidate in ("icon.svg", "icon.png", "icon.jpg"):
        if os.path.isfile(os.path.join(package_dir, candidate)):
            return candidate
    return None


def process_package(category, package, meta_path):
    """Process a single package and return its metadata."""
    meta = load_meta(meta_path)
    if meta is None:
        return None

    path = make_path(category, package)
    source = meta.get("source", {})

    package_dir = os.path.dirname(meta_path)
    icon = detect_icon(package_dir)

    version = detect_version(meta)
    stars = None

    if source.get("type") == "github_release":
        repo = source.get("repo")
        if repo:
            stars = fetch_stars(repo)

    source_output = {
        "type": source.get("type"),
    }
    if source.get("repo"):
        source_output["repo"] = source.get("repo")

    return {
        "path": path,
        "title": meta.get("title", path),
        "description": meta.get("description", ""),
        "version": version,
        "stars": stars,
        "license": meta.get("license", ""),
        "homepage": meta.get("homepage", ""),
        "live_url": meta.get("live_url", ""),
        "source": source_output,
        "tags": meta.get("tags", []),
        "icon": icon,
    }


def generate(packages_dir):
    """Generate staticweb.json from package metadata."""
    packages = []

    for category, package, meta_path in walk_packages(packages_dir):
        try:
            pkg = process_package(category, package, meta_path)
            if pkg:
                packages.append(pkg)
                print(f"Processed: {pkg['path']}", file=sys.stderr)
            else:
                print(f"Failed to parse: {meta_path}", file=sys.stderr)
        except Exception as e:
            print(f"Error processing {category}/{package}: {e}", file=sys.stderr)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "packages": packages,
    }


def main():
    packages_dir = PACKAGES_DIR

    if not os.path.isdir(packages_dir):
        print(f"Packages directory not found: {packages_dir}", file=sys.stderr)
        sys.exit(1)

    data = generate(packages_dir)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"Generated {OUTPUT_FILE} with {len(data['packages'])} packages", file=sys.stderr)


if __name__ == "__main__":
    main()