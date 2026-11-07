import { games } from './games.mjs';
import { build } from 'esbuild';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
for (const game of games) {
  const outdir = `games/${game}/dist`;
  await mkdir(outdir,{recursive:true});
  await build({entryPoints:[`games/${game}/src/index.ts`],outfile:`${outdir}/${game}.js`,loader:{'.css':'text','.html':'text'},bundle:true,format:'esm',target:['es2022'],minify:true,sourcemap:true,legalComments:'inline'});
  if (game === 'cookie-wall') {
    // The feature branch has no Pages deployment. Give reviewers one file they can open directly.
    const entry = await readFile('games/cookie-wall/demo/embed.html', 'utf8');
    const bundle = await readFile(outdir + '/cookie-wall.js', 'utf8');
    const skin = JSON.parse(await readFile('games/cookie-wall/skins/fony/skin.json', 'utf8'));
    for (const [key, path] of Object.entries(skin.files)) {
      const image = await readFile('games/cookie-wall/skins/fony/' + path);
      skin.files[key] = 'data:' + (path.endsWith('.webp') ? 'image/webp' : 'image/png') + ';base64,' + image.toString('base64');
    }
    const inlineSkin = 'data:application/json;base64,' + Buffer.from(JSON.stringify(skin)).toString('base64');
    const skinElement = '<cookie-wall skin="' + inlineSkin + '"></cookie-wall>';
    const withSkin = entry.replace('<cookie-wall></cookie-wall>', skinElement);
    if (withSkin === entry) throw new Error('Could not add the bundled Fony skin');
    const safeScript = bundle.replace(/<\/script/gi, '<\\/script').replace(/^\/\/# sourceMappingURL=.*$/gm, '');
    const standalone = withSkin.replace('<script type="module" src="./page.js"></script>',
      () => '<script type="module">' + safeScript + '</script>');
    await writeFile(outdir + '/Cookie-Wall.html', standalone);
  }
  console.log('Built',game);
}
