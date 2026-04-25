#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${STATICHUB_WORKDIR:?STATICHUB_WORKDIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"
PREFIX="${STATICHUB_PREFIX:-/}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends ruby-full bundler build-essential
rm -rf /var/lib/apt/lists/*

corepack enable

bundle config set path vendor/bundle
bundle install
pnpm install --frozen-lockfile

node --input-type=module <<'EOF'
import fs from 'node:fs'

function replaceOne(filePath, searchValue, replaceValue) {
  const source = fs.readFileSync(filePath, 'utf8')
  if (!source.includes(searchValue)) {
    throw new Error(`Expected snippet not found in ${filePath}`)
  }

  fs.writeFileSync(filePath, source.replace(searchValue, replaceValue))
}

replaceOne(
  'astro.config.mjs',
  "import tailwind from '@astrojs/tailwind'\n\n// https://astro.build/config\nexport default defineConfig({\n  site: 'https://devhints.io',\n",
  "import tailwind from '@astrojs/tailwind'\n\nconst base = process.env.STATICHUB_PREFIX || '/'\n\n// https://astro.build/config\nexport default defineConfig({\n  site: 'https://devhints.io',\n  base,\n"
)

replaceOne(
  'src/config.ts',
  "export const site = {\n  url: 'https://devhints.io',\n  title: 'Devhints.io cheatsheets'\n} as const\n\n",
  "export const site = {\n  url: 'https://devhints.io',\n  title: 'Devhints.io cheatsheets'\n} as const\n\nexport const basePath = import.meta.env.BASE_URL\n\n"
)

replaceOne('src/config.ts', "enabled: true,", 'enabled: false,')
replaceOne('src/config.ts', 'enabled: isProd,', 'enabled: false,')
replaceOne('src/config.ts', 'enabled: isProd,', 'enabled: false,')

replaceOne(
  'src/components/BaseLayout.astro',
  "import GoogleAnalytics from '~/analytics/GoogleAnalytics.astro'\nimport { googleAnalytics } from '~/config'\n",
  "import GoogleAnalytics from '~/analytics/GoogleAnalytics.astro'\nimport { basePath, googleAnalytics } from '~/config'\n"
)
replaceOne(
  'src/components/BaseLayout.astro',
  'href="/assets/favicon.png"',
  'href={`${basePath}assets/favicon.png`}'
)

replaceOne(
  'src/components/TopNav.astro',
  "import SocialList from './SocialList.astro'\nimport { getEditLink } from '~/lib/links'\n",
  "import SocialList from './SocialList.astro'\nimport { basePath } from '~/config'\nimport { getEditLink } from '~/lib/links'\n"
)
replaceOne('src/components/TopNav.astro', 'href="/"', 'href={basePath}')

replaceOne(
  'src/components/V2017Sheet/SearchFooter.astro',
  "---\nimport SearchForm from './SearchForm.astro'\n---\n",
  "---\nimport { basePath } from '~/config'\nimport SearchForm from './SearchForm.astro'\n---\n"
)
replaceOne('src/components/V2017Sheet/SearchFooter.astro', 'href="/"', 'href={basePath}')

replaceOne(
  'src/components/V2017Sheet/RelatedPosts.astro',
  "import { getPages, type SheetPage } from '~/lib/page'\nimport { getTopPages, getRelatedPages } from '~/lib/page/queries'\nimport { etc } from '~/config'\n",
  "import { getPages, type SheetPage } from '~/lib/page'\nimport { getTopPages, getRelatedPages } from '~/lib/page/queries'\nimport { basePath, etc } from '~/config'\n"
)
replaceOne('src/components/V2017Sheet/RelatedPosts.astro', 'href="/"', 'href={basePath}')

replaceOne(
  'src/components/V2017Sheet/SearchForm.astro',
  "import 'autocompleter/autocomplete.css'\n\nimport { etc } from '../../config'\n",
  "import 'autocompleter/autocomplete.css'\n\nimport { basePath, etc } from '../../config'\n"
)
replaceOne('src/components/V2017Sheet/SearchForm.astro', 'action="/"', 'action={basePath}')

replaceOne(
  'src/components/V2017Sheet.astro',
  "import CarbonBox from './V2017/CarbonBox.astro'\nimport { getSEOPropsForPage } from '~/lib/seo/seo'\n",
  "import CarbonBox from './V2017/CarbonBox.astro'\nimport { disqus } from '~/config'\nimport { getSEOPropsForPage } from '~/lib/seo/seo'\n"
)
replaceOne(
  'src/components/V2017Sheet.astro',
  '  <CommentsArea identifier={page.slug} />\n',
  '  {disqus.enabled ? <CommentsArea identifier={page.slug} /> : null}\n'
)

replaceOne(
  'src/pages/404.astro',
  "import BaseLayout from '~/components/BaseLayout.astro'\nimport TopNav from '~/components/TopNav.astro'\n",
  "import BaseLayout from '~/components/BaseLayout.astro'\nimport { basePath } from '~/config'\nimport TopNav from '~/components/TopNav.astro'\n"
)
replaceOne('src/pages/404.astro', 'href="/"', 'href={basePath}')

replaceOne(
  'src/lib/fuseSearch/fuseSearch.ts',
  "export async function fetchFuse() {\n  const res = await fetch('/searchindex.json')\n",
  "export async function fetchFuse() {\n  const res = await fetch(`${import.meta.env.BASE_URL}searchindex.json`)\n"
)

replaceOne(
  'src/lib/render.ts',
  "import { renderKramdown } from './kramdown'\nimport { plugin as rehypeSectionize } from '@rstacruz/rehype-sectionize'\n",
  "import { renderKramdown } from './kramdown'\nimport { plugin as rehypeSectionize } from '@rstacruz/rehype-sectionize'\nimport { basePath } from '~/config'\n"
)
replaceOne(
  'src/lib/render.ts',
  "  html = await processRehype(html)\n  html = removeBlankHeadings(html)\n  return { html }\n}\n",
  "  html = await processRehype(html)\n  html = removeBlankHeadings(html)\n  html = rewriteRootRelativeUrls(html)\n  return { html }\n}\n"
)
replaceOne(
  'src/lib/render.ts',
  "function removeBlankHeadings(html: string): string {\n  return html.replace(/<h3><\\/h3>/g, '').replace(/<h2><\\/h2>/g, '')\n}\n\n/**\n * Runs through Rehype to add syntax highlighting and more.\n */\n",
  "function removeBlankHeadings(html: string): string {\n  return html.replace(/<h3><\\/h3>/g, '').replace(/<h2><\\/h2>/g, '')\n}\n\nfunction rewriteRootRelativeUrls(html: string): string {\n  return html.replace(/(href|src)=\"\\/(?!\\/)/g, `$1=\"${basePath}`)\n}\n\n/**\n * Runs through Rehype to add syntax highlighting and more.\n */\n"
)
EOF

pnpm build

node --input-type=module <<'EOF'
import fs from 'node:fs'
import path from 'node:path'

const distDir = 'dist'
const prefix = (process.env.STATICHUB_PREFIX || '/').replace(/\/$/, '') + '/'

function walk(dirPath) {
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    const entryPath = path.join(dirPath, entry.name)

    if (entry.isDirectory()) {
      walk(entryPath)
      continue
    }

    if (!entry.name.endsWith('.html')) {
      continue
    }

    const source = fs.readFileSync(entryPath, 'utf8')
    const updated = source.replace(
      /(href|src|action)="\/(?!\/|doc\/devhints\/|~partytown\/|_astro\/)/g,
      `$1="${prefix}`
    )

    fs.writeFileSync(entryPath, updated)
  }
}

walk(distDir)
EOF

mkdir -p "$DISTDIR"
rm -rf "$DISTDIR"/*
cp -a dist/. "$DISTDIR/"

# Fix ownership for files created as root inside Docker.
HOST_OWNER=$(stat -c '%u:%g' "$DISTDIR")
chown -R "$HOST_OWNER" "$DISTDIR"
