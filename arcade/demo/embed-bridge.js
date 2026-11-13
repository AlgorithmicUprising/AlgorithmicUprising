export function httpOrigin(value) {
  try {
    const url = new URL(value);
    if (['http:', 'https:'].includes(url.protocol) && !url.username && !url.password) return url.origin;
  } catch {}
  return null;
}

const arcadeHosts = new Set([
  'https://algorithmicuprising.com',
  'https://www.algorithmicuprising.com',
  'https://algorithmic-uprising.free-grass-2381.chatgpt.site',
]);

export function connectArcadeEmbed(game, events, parentOrigin = httpOrigin(document.referrer)) {
  if (parent === window || !parentOrigin) return;
  const types = [...events];
  if (arcadeHosts.has(parentOrigin) && new URLSearchParams(location.search).get('score-save') === '1') {
    game.setAttribute('save-score', '');
    types.push('save-score');
  }
  for (const name of types) {
    game.addEventListener('game:' + name, ({ type, detail }) => {
      parent.postMessage({ source: 'punk-arcade', type, detail }, parentOrigin);
    });
  }
}
