## StaticHub Home package

This package supports extra launcher entries through injection data.

Place a `custom-links.json` file in the package data directory to add links that do not come from the installed `catalog.json`. This is useful for search engines, dashboards, internal tools, or any other shortcut you want to keep in the launcher.

The package also supports custom icons:

- Set `icon` on each entry.
- If `icon` is a relative path, place the matching file under `icons/` in the same data directory.
- If `icon` is an absolute URL, it can be used directly.

### Expected files

```text
<data-dir>/custom-links.json
<data-dir>/icons/
```

### `custom-links.json` example

```json
{
  "packages": [
    {
      "title": "DuckDuckGo",
      "path": "https://duckduckgo.com/",
      "description": "Private search engine",
      "icon": "https://duckduckgo.com/assets/logo_homepage.normal.v108.svg",
      "tags": ["search", "web"],
      "external": true
    },
    {
      "title": "DuckDuckGo Lite",
      "path": "https://lite.duckduckgo.com/",
      "description": "Lightweight DuckDuckGo entry with a local icon",
      "icon": "icons/duckduckgo.svg",
      "tags": ["search", "lite"],
      "external": true
    }
  ]
}
```

At minimum, each entry must define `title` and `path`.

When `external` is omitted or set to `false`, `path` is treated like a normal StaticHub package path.
