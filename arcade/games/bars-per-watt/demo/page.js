const game = document.querySelector('bars-per-watt');
const query = new URLSearchParams(location.search);
const catalog = query.get('catalog');
if (catalog) {
  try {
    const url = new URL(catalog, location.href);
    if (url.origin === location.origin || [
      'https://algorithmicuprising.com', 'https://www.algorithmicuprising.com',
      'https://algorithmicuprising.github.io'
    ].includes(url.origin)) game.setAttribute('catalog', url.href);
  } catch { /* Invalid or disallowed catalogs fall back to the metadata-only entry. */ }
}
const embed = document.body.hasAttribute('data-embed');
const events = ['ready','skin-loaded','start','pause','resume','over','share','sound','error','loading','transport-error'];
function originOf(raw, onlyOrigin = false) {
  if (!raw) return null;
  try {
    const url = new URL(raw);
    if (!['http:','https:'].includes(url.protocol) || url.username || url.password) return null;
    if (onlyOrigin && (url.pathname !== '/' || url.search || url.hash)) return null;
    return url.origin;
  } catch { return null; }
}
const referrer = originOf(document.referrer);
const explicit = originOf(query.get('parent-origin'), true);
const validParent = embed && parent !== window && (!explicit || !referrer || explicit === referrer);
const parentOrigin = validParent ? referrer || explicit : null;
const firstParty = parentOrigin === 'https://algorithmicuprising.com' || parentOrigin === 'https://www.algorithmicuprising.com';
const orientation = query.get('orientation');
if (['auto','landscape','portrait'].includes(orientation)) game.setAttribute('orientation', orientation);
else if (firstParty) game.setAttribute('layout', 'portrait');
if (['0','1','true','false'].includes(query.get('muted'))) game.setAttribute('muted', query.get('muted'));
const skinId = /^[a-z0-9-]{1,64}$/.test(query.get('skin') || '') ?
  query.get('skin') : firstParty ? 'au' : 'fony';
const selectSkin = id => id === 'placeholder' ? game.removeAttribute('skin') :
  game.setAttribute('skin', '../skins/' + id + '/skin.json');
selectSkin(skinId);
const picker = document.querySelector('#skins');
if (picker) { picker.value = skinId; picker.addEventListener('change', () => selectSkin(picker.value)); }
const log = document.querySelector('#events');
for (const name of events) game.addEventListener('game:' + name, event => {
  if (log) log.textContent = (event.type + ' ' + JSON.stringify(event.detail) + '\n' + log.textContent).slice(0,6000);
  if (parentOrigin) parent.postMessage({ source:'punk-arcade', type:event.type, detail:event.detail }, parentOrigin);
});
if (parentOrigin) window.addEventListener('message', event => {
  if (event.source !== parent || event.origin !== parentOrigin || event.data?.source !== 'punk-arcade') return;
  switch (event.data.type) {
    case 'pause': game.pause?.('host'); break;
    case 'resume': game.resume?.('host'); break;
    case 'mute': game.muted = true; break;
    case 'unmute': game.muted = false; break;
  }
});
await import('../dist/bars-per-watt.js');
