import { connectArcadeEmbed, httpOrigin } from '../../../demo/embed-bridge.js';

const game = document.querySelector('cookie-wall');
const query = new URLSearchParams(location.search);
const embed = document.body.hasAttribute('data-embed');
const events = ['ready', 'skin-loaded', 'start', 'pause', 'resume', 'wall', 'over', 'share', 'sound', 'error'];
function explicitOrigin(raw) {
  if (!raw) return null;
  try {
    const url = new URL(raw);
    if (url.pathname !== '/' || url.search || url.hash) return null;
    return httpOrigin(url.href);
  } catch { return null; }
}
const referrer = httpOrigin(document.referrer);
const explicit = explicitOrigin(query.get('parent-origin'));
const validParent = embed && parent !== window && (!explicit || !referrer || explicit === referrer);
const parentOrigin = validParent ? referrer || explicit : null;
const firstParty = parentOrigin === 'https://algorithmicuprising.com' || parentOrigin === 'https://www.algorithmicuprising.com';
const knownOrientation = ['auto', 'landscape', 'portrait'].includes(query.get('orientation'));
if (knownOrientation) game.setAttribute('orientation', query.get('orientation'));
else if (firstParty) game.setAttribute('layout', 'portrait');
if (['on', 'off', 'auto'].includes(query.get('reduced-motion'))) game.setAttribute('reduced-motion', query.get('reduced-motion'));
if (['0', '1', 'true', 'false'].includes(query.get('muted'))) game.setAttribute('muted', query.get('muted'));
if (query.has('seed') && /^-?\d+$/.test(query.get('seed'))) game.setAttribute('seed', query.get('seed'));
const proposedSkin = query.get('skin') ?? (firstParty ? 'au' : 'fony');
const skinId = /^[a-z0-9-]{1,64}$/.test(proposedSkin) ? proposedSkin : 'placeholder';
const skinPath = id => '../skins/' + id + '/skin.json';
const selectSkin = id => id === 'placeholder' ? game.removeAttribute('skin') : game.setAttribute('skin', skinPath(id));
selectSkin(skinId);
const menu = document.querySelector('#skins');
if (menu) {
  if (!Array.from(menu.options).some(option => option.value === skinId)) menu.add(new Option(skinId, skinId));
  menu.value = skinId;
  menu.addEventListener('change', () => selectSkin(menu.value));
}
const log = document.querySelector('#events');
if (log) {
  for (const name of events) game.addEventListener('game:' + name, event => {
    log.textContent = (event.type + ' ' + JSON.stringify(event.detail) + '\n' + log.textContent).slice(0, 6000);
  });
}
connectArcadeEmbed(game, events, parentOrigin);
if (parentOrigin) window.addEventListener('message', event => {
  if (event.source !== parent || event.origin !== parentOrigin || event.data?.source !== 'punk-arcade') return;
  switch (event.data.type) {
    case 'pause': game.pause?.('host'); break;
    case 'resume': game.resume?.('host'); break;
    case 'mute': game.muted = true; break;
    case 'unmute': game.muted = false; break;
  }
});
await import('../dist/cookie-wall.js?v=20261113-scores');
