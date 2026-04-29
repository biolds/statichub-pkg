import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const webRoot = process.cwd();
const indexPath = path.join(webRoot, 'src', 'index.html');

async function readUtf8(filePath) {
  return readFile(filePath, 'utf8');
}

async function writeUtf8(filePath, content) {
  await writeFile(filePath, content, 'utf8');
}

function replaceOrThrow(content, searchValue, replaceValue, description) {
  if (content.includes(replaceValue)) {
    return content;
  }

  if (!content.includes(searchValue)) {
    throw new Error(`Could not find ${description}`);
  }

  return content.replace(searchValue, replaceValue);
}

async function adaptHtml() {
  let html = await readUtf8(indexPath);

  html = replaceOrThrow(
    html,
    '<meta name="description" content="OpenTTD - Open source transport simulation game in your browser">',
    '<meta name="description" content="Unofficial browser-based WebAssembly port of OpenTTD">',
    'the upstream meta description'
  );

  html = replaceOrThrow(
    html,
    `          <p class="footer-credits">\n            <a href="https://www.openttd.org" target="_blank" rel="noopener">OpenTTD</a> is free software licensed under <a href="https://www.gnu.org/licenses/old-licenses/gpl-2.0.html" target="_blank" rel="noopener">GPL-2.0</a>\n          </p>`,
    '          <p class="footer-credits">OpenTTD is free software licensed under GPL-2.0.</p>',
    'the footer credits block'
  );

  html = replaceOrThrow(
    html,
    `          <p class="footer-links">\n            <a href="#" id="legal-link">Legal Notice</a>\n            <span class="separator">|</span>\n            <a href="https://github.com/msadev/OpenTTD" target="_blank" rel="noopener">Web Port Source</a>\n            <span class="separator">|</span>\n            <a href="https://github.com/OpenTTD/OpenTTD" target="_blank" rel="noopener">Upstream</a>\n            <span class="separator">|</span>\n            <a href="https://wiki.openttd.org" target="_blank" rel="noopener">Wiki</a>\n          </p>`,
    '          <p class="footer-links"><a href="#" id="legal-link">Legal Notice</a></p>',
    'the footer links block'
  );

  html = replaceOrThrow(
    html,
    '<p>Network requests are limited to downloading the web build from this server, optionally connecting to a WebSocket proxy for multiplayer, and fetching release notes from GitHub. Standard server logs may include IP address and user agent for security and troubleshooting.</p>',
    '<p>Network requests are limited to downloading the web build from this server, optionally connecting to the OpenTTD content service for BaNaNaS, and optionally connecting to a WebSocket proxy for multiplayer. Standard server logs may include IP address and user agent for security and troubleshooting.</p>',
    'the privacy network paragraph'
  );

  await writeUtf8(indexPath, html);
}

await adaptHtml();
