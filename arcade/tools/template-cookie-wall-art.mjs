import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const artRoot = resolve(here, '../games/cookie-wall/skins/fony');
const escapeXML = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');

export function buildTemplate(frames) {
  const entries = Object.entries(frames);
  const columns = 3, cellW = 360, cellH = 360, headerH = 104, previewMax = 280;
  const rows = Math.ceil(entries.length / columns);
  const width = columns * cellW, height = headerH + rows * cellH;
  const bits = [
    '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '">',
    '<title>Cookie Wall guide frame template</title>',
    '<desc>Blank frame slots sized to the Cookie Wall guide. Cyan crosses mark each frame anchor. Names and dimensions are review labels outside the art bounds.</desc>',
    '<defs><pattern id="checker" width="16" height="16" patternUnits="userSpaceOnUse"><rect width="16" height="16" fill="#17131e"/><path d="M0 0h8v8H0zM8 8h8v8H8z" fill="#211c2a"/></pattern></defs>',
    '<rect width="100%" height="100%" fill="#0e0b13"/>',
    '<text x="28" y="38" fill="#f4efd8" font-family="monospace" font-size="24" font-weight="700">COOKIE WALL · SPRITE TEMPLATE</text>',
    '<text x="28" y="70" fill="#a0fff0" font-family="monospace" font-size="14">43 GUIDE FRAMES · BLANK ART BOUNDS · CYAN CROSS = ANCHOR · LABELS OUTSIDE SPRITES</text>'
  ];
  entries.forEach(([name, frame], index) => {
    const col = index % columns, row = Math.floor(index / columns);
    const x = col * cellW + 8, y = headerH + row * cellH + 8;
    const [w, h] = frame.size, [ax, ay] = frame.anchor;
    const scale = Math.min(4, previewMax / Math.max(w, h));
    const sw = w * scale, sh = h * scale;
    const ox = x + (cellW - 16 - sw) / 2, oy = y + 58 + (previewMax - sh) / 2;
    bits.push('<g data-frame="' + escapeXML(name) + '">');
    bits.push('<rect x="' + x + '" y="' + y + '" width="344" height="344" rx="5" fill="#17131e" stroke="#554667"/>');
    bits.push('<text x="' + (x + 14) + '" y="' + (y + 24) + '" fill="#f4efd8" font-family="monospace" font-size="13" font-weight="700">' + escapeXML(name) + '</text>');
    bits.push('<text x="' + (x + 14) + '" y="' + (y + 43) + '" fill="#a0fff0" font-family="monospace" font-size="11">' + w + '×' + h + ' · anchor ' + ax + ',' + ay + '</text>');
    bits.push('<rect x="' + ox + '" y="' + oy + '" width="' + sw + '" height="' + sh + '" fill="url(#checker)" stroke="#d6cbe1" stroke-width="1"/>');
    const px = ox + ax * scale, py = oy + ay * scale;
    bits.push('<path d="M' + (px - 7) + ' ' + py + 'H' + (px + 7) + ' M' + px + ' ' + (py - 7) + 'V' + (py + 7) + '" fill="none" stroke="#35dfcc" stroke-width="2"/>');
    bits.push('<circle cx="' + px + '" cy="' + py + '" r="2" fill="#ff637a"/>');
    bits.push('</g>');
  });
  bits.push('</svg>');
  return bits.join('\n') + '\n';
}

export function regenerateTemplate() {
  const frames = JSON.parse(readFileSync(resolve(artRoot, 'frames.json'), 'utf8'));
  const target = resolve(artRoot, 'sprite-template.svg');
  const contents = buildTemplate(frames);
  writeFileSync(target, contents);
  return target;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log('wrote ' + regenerateTemplate());
}
