import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { ART_ROOT, FRAME_SPECS, validateCookieWallArt } from '../tools/validate-cookie-wall-art.mjs';
import { buildTemplate } from '../tools/template-cookie-wall-art.mjs';

test('Cookie Wall guide frames have exact names, sizes, anchors, timing and visible image pixels', async () => {
  const result = await validateCookieWallArt();
  assert.deepEqual(result.errors, []);
  assert.equal(result.checked, 43);
  assert.ok(result.bytes < 1_572_864);
  assert.equal(Object.keys(FRAME_SPECS).length, 43);
});

test('sprite template stays generated from current frame bounds and anchors', () => {
  const frames = JSON.parse(readFileSync(resolve(ART_ROOT, 'frames.json'), 'utf8'));
  const actual = readFileSync(resolve(ART_ROOT, 'sprite-template.svg'), 'utf8');
  assert.equal(actual, buildTemplate(frames));
  for (const name of Object.keys(FRAME_SPECS)) assert.match(actual, new RegExp('data-frame="' + name + '"'));
});
