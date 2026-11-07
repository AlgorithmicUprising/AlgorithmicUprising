import sharp from 'sharp';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const ART_ROOT = resolve(here, '../games/cookie-wall/skins/fony');

const specs = Object.create(null);
function add(names, size, anchor, animation = null) {
  for (const name of names) specs[name] = { size, anchor, animation };
}
const range = (stem, count) => Array.from({ length: count }, (_, i) => stem + String(i).padStart(2, '0'));
add(['bg_court_00'], [320, 320], [0, 0]);
add(['blocker_idle_00'], [64, 16], [32, 8]);
add(range('blocker_hit_', 2), [64, 16], [32, 8], { fps: 12, loop: false });
add(['blocker_ad_idle_00'], [64, 16], [32, 8]);
add(range('blocker_ad_hit_', 2), [64, 16], [32, 8], { fps: 12, loop: false });
for (const kind of ['necessary', 'partners']) {
  add(['brick_' + kind + '_idle_00'], [34, 18], [17, 9]);
  add(range('brick_' + kind + '_break_', 3), [34, 18], [17, 9], { fps: 12, loop: false });
}
for (const kind of ['interest', 'reject']) {
  add(['brick_' + kind + '_idle_00', 'brick_' + kind + '_crack_00'], [34, 18], [17, 9]);
  add(range('brick_' + kind + '_break_', 3), [34, 18], [17, 9], { fps: 12, loop: false });
}
add(range('packet_spin_', 4), [12, 12], [6, 6], { fps: 8, loop: true });
add(range('tracker_idle_', 2), [32, 24], [16, 12], { fps: 4, loop: true });
add(range('fx_crumb_', 4), [8, 8], [4, 4], { fps: 12, loop: false });
add(['logo_title_00'], [320, 96], [0, 0]);
add(['ui_sound_on_00', 'ui_sound_off_00', 'ui_pause_00', 'ui_share_00', 'ui_settings_00'], [16, 16], [8, 8]);
add(range('ui_btn_launch_', 2), [64, 64], [32, 32], { fps: 8, loop: false });
export const FRAME_SPECS = Object.freeze(specs);

const readJSON = path => JSON.parse(readFileSync(path, 'utf8'));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const error = (errors, message) => errors.push(message);
function luminance(hex) {
  const values = hex.slice(1).match(/../g).map(x => parseInt(x, 16) / 255)
    .map(x => x <= .04045 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4);
  return .2126 * values[0] + .7152 * values[1] + .0722 * values[2];
}
function contrast(a, b) {
  const values = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (values[0] + .05) / (values[1] + .05);
}
function auditPalette(label, palette, errors) {
  const required = ['bg', 'panel', 'ink', 'muted', 'dark', 'accent', 'safe', 'hazard', 'interest', 'danger'];
  for (const key of required) {
    if (typeof palette[key] !== 'string' || !/^#[0-9a-f]{6}$/i.test(palette[key])) {
      error(errors, label + ' palette is missing a valid ' + key);
      return;
    }
  }
  for (const [fg, bg] of [['ink', 'bg'], ['ink', 'panel'], ['muted', 'bg'], ['muted', 'panel'], ['dark', 'accent']]) {
    const ratio = contrast(palette[fg], palette[bg]);
    if (ratio < 4.5) error(errors, label + ' palette contrast ' + fg + '/' + bg + ' is ' + ratio.toFixed(2) + ':1; needs 4.5:1');
  }
  for (const color of ['safe', 'hazard', 'interest', 'danger']) {
    const ratio = contrast(palette[color], palette.dark);
    if (ratio < 3) error(errors, label + ' icon contrast ' + color + '/dark is ' + ratio.toFixed(2) + ':1; needs 3:1');
  }
}

export async function validateCookieWallArt(root = ART_ROOT) {
  root = resolve(root);
  const errors = [], warnings = [];
  const framePath = resolve(root, 'frames.json');
  const skinPath = resolve(root, 'skin.json');
  const artSourcesPath = resolve(root, 'ART-SOURCES.md');
  const licensePath = resolve(root, 'LICENSE');
  for (const path of [framePath, skinPath, artSourcesPath, licensePath, resolve(root, 'source/build_art.py')]) {
    if (!existsSync(path)) error(errors, 'Required art-pack file is missing: ' + path);
  }
  if (errors.length) return { errors, warnings, checked: 0 };
  const metadata = readJSON(framePath);
  const skin = readJSON(skinPath);
  const placeholder = readJSON(resolve(root, '../placeholder/skin.json'));
  const auPath = resolve(root, '../au/skin.json');
  const au = readJSON(auPath);
  if (skin.game !== 'cookie-wall' || skin.id !== 'fony' || skin.extends !== 'placeholder') error(errors, 'Fony manifest identity or inheritance is invalid');
  if (au.game !== 'cookie-wall' || au.id !== 'au' || au.extends !== 'fony') error(errors, 'AU must extend Fony as a separate overlay');
  if (Object.keys(au.files ?? {}).length) error(errors, 'AU overlay must not include or copy image files');
  if (au.strings?.patch !== 'Ø') error(errors, 'AU patch must remain code-composited from the Ø string');
  const fonyLicense = readFileSync(licensePath, 'utf8');
  const provenance = readFileSync(artSourcesPath, 'utf8');
  if (!/CC BY 4\.0|Creative Commons Attribution 4\.0/i.test(fonyLicense)) error(errors, 'Fony art pack is missing its CC BY 4.0 license');
  if (!/CC BY 4\.0/i.test(provenance) || !/source\/build_art\.py/.test(provenance)) error(errors, 'Fony art provenance or generator reference is missing');
  if (!/all rights reserved/i.test(readFileSync(resolve(root, '../au/LICENSE'), 'utf8'))) error(errors, 'AU overlay license is not marked all-rights-reserved');

  const expectedKeys = Object.keys(FRAME_SPECS).sort();
  const metadataKeys = Object.keys(metadata).sort();
  const skinFiles = skin.files ?? {};
  const skinKeys = Object.keys(skinFiles).sort();
  if (!same(metadataKeys, expectedKeys)) error(errors, 'frames.json does not contain exactly the ' + expectedKeys.length + ' guide frames');
  if (!same(skinKeys, expectedKeys)) error(errors, 'Fony skin.json does not reference exactly the ' + expectedKeys.length + ' guide frames');

  let totalBytes = 0;
  for (const key of expectedKeys) {
    const spec = FRAME_SPECS[key];
    const frame = metadata[key];
    if (!frame) { error(errors, 'Missing frame metadata: ' + key); continue; }
    if (!same(frame.size, spec.size)) error(errors, key + ' size must be ' + spec.size.join('×'));
    if (!same(frame.anchor, spec.anchor)) error(errors, key + ' anchor must be ' + spec.anchor.join(','));
    if (spec.animation) {
      if (frame.fps !== spec.animation.fps || frame.loop !== spec.animation.loop) error(errors, key + ' animation timing must be ' + JSON.stringify(spec.animation));
    } else if (Object.hasOwn(frame, 'fps') || Object.hasOwn(frame, 'loop')) {
      error(errors, key + ' is static and must not declare animation timing');
    }
    if (!Array.isArray(frame.size) || !Array.isArray(frame.anchor) ||
        frame.anchor[0] < 0 || frame.anchor[0] >= frame.size[0] ||
        frame.anchor[1] < 0 || frame.anchor[1] >= frame.size[1]) error(errors, key + ' anchor falls outside its frame');
    if (skinFiles[key] !== frame.file) error(errors, key + ' skin path does not match frames.json');
    const path = resolve(root, frame.file ?? '');
    if (!path.startsWith(root + sep)) { error(errors, key + ' path escapes the Fony skin folder'); continue; }
    if (!existsSync(path)) { error(errors, 'Missing frame image: ' + key + ' → ' + frame.file); continue; }
    try {
      const stat = statSync(path); totalBytes += stat.size;
      const image = sharp(path, { failOn: 'error' });
      const details = await image.metadata();
      if (details.format !== 'png' && details.format !== 'webp') error(errors, key + ' must be PNG or WebP');
      if (details.width !== spec.size[0] || details.height !== spec.size[1]) {
        error(errors, key + ' image is ' + details.width + '×' + details.height + ', expected ' + spec.size.join('×'));
      }
      const { data } = await sharp(path).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      let visible = false;
      for (let i = 3; i < data.length; i += 4) if (data[i] > 0) { visible = true; break; }
      if (!visible) error(errors, key + ' image has no visible pixels');
    } catch (cause) {
      error(errors, key + ' cannot be decoded: ' + cause.message);
    }
  }
  if (totalBytes > 1_572_864) warnings.push('Fony art pack exceeds the 1.5 MB review threshold');
  const fonyPalette = { ...placeholder.palette, ...skin.palette };
  const auPalette = { ...fonyPalette, ...au.palette };
  auditPalette('Fony', fonyPalette, errors);
  auditPalette('AU', auPalette, errors);
  return { errors, warnings, checked: expectedKeys.length, bytes: totalBytes };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = await validateCookieWallArt();
  for (const warning of result.warnings) console.warn('warning:', warning);
  if (result.errors.length) {
    for (const message of result.errors) console.error('invalid:', message);
    process.exitCode = 1;
  } else console.log('valid Cookie Wall Fony art: ' + result.checked + ' guide frames, ' + result.bytes + ' bytes; Fony/AU palette contrast and licenses pass');
}
