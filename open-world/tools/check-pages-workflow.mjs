// The live site has one publisher. This fails if a second deploy appears
// or if a main run can be cancelled out from under deploy-pages.
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const workflowDir = join(repo, '.github', 'workflows');
const files = readdirSync(workflowDir).filter((name) => name.endsWith('.yml') || name.endsWith('.yaml'));
const failures = [];

function fail(message) {
  failures.push(message);
}

const deployFiles = [];
const uploadFiles = [];
for (const name of files) {
  const text = readFileSync(join(workflowDir, name), 'utf8');
  if (text.includes('uses: actions/deploy-pages')) deployFiles.push(name);
  if (text.includes('uses: actions/upload-pages-artifact')) uploadFiles.push(name);
}
if (deployFiles.length !== 1 || deployFiles[0] !== 'arcade.yml') {
  fail('actions/deploy-pages must appear only in .github/workflows/arcade.yml, found ' + deployFiles.join(', '));
}
if (uploadFiles.length !== 1 || uploadFiles[0] !== 'arcade.yml') {
  fail('actions/upload-pages-artifact must appear only in arcade.yml, found ' + uploadFiles.join(', '));
}

const arcade = readFileSync(join(workflowDir, 'arcade.yml'), 'utf8');
if (!arcade.includes('group: punk-arcade-${{ github.workflow }}-${{ github.ref }}')) {
  fail('main and pull requests must not share one concurrency group');
}
if (!/cancel-in-progress:\s*\$\{\{\s*github\.ref\s*!=\s*'refs\/heads\/main'\s*\}\}/.test(arcade)) {
  fail('main publishes must not set cancel-in-progress true');
}
if (arcade.includes('\n  cancel-in-progress: true\n')) {
  fail('arcade.yml still cancels every in-progress run');
}
if (!arcade.includes("github.ref == 'refs/heads/main'") || !arcade.includes("github.event_name != 'pull_request'")) {
  fail('deploy-main must be limited to a main push or a main workflow_dispatch');
}
const into = arcade.indexOf('stage-composite.mjs --into-staged');
const upload = arcade.indexOf('actions/upload-pages-artifact');
const deploy = arcade.indexOf('actions/deploy-pages');
if (into < 0 || upload < 0 || deploy < 0 || !(into < upload && upload < deploy)) {
  fail('the combined tree must be staged before the Pages artifact is uploaded');
}
if (arcade.includes('ref:') && /checkout@v4[\s\S]{0,180}ref:/.test(arcade)) {
  fail('checkout must use the workflow SHA, not a pinned ref');
}

const composite = readFileSync(join(workflowDir, 'open-world-pages-composite.yml'), 'utf8');
if (composite.includes('uses: actions/deploy-pages') || composite.includes('uses: actions/upload-pages-artifact') || composite.includes('pages: write')) {
  fail('the open-world composite workflow must not be able to publish Pages');
}

const stage = readFileSync(join(repo, 'open-world', 'tools', 'stage-composite.mjs'), 'utf8');
if (!stage.includes('Arcade file changed in the composite') || !stage.includes("rootIndex.includes('./demo/')")) {
  fail('stage-composite must keep arcade bytes and the ./demo/ landing');
}

if (failures.length) {
  console.error(failures.join('\n'));
  process.exit(1);
}
console.log('pages workflow checks ok');
