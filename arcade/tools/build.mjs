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
    const safeScript = bundle.replace(/<\/script/gi, '<\\/script').replace(/^\/\/# sourceMappingURL=.*$/gm, '');
    const standalone = entry.replace('<script type="module" src="./page.js"></script>',
      () => '<script type="module">' + safeScript + '</script>');
    await writeFile(outdir + '/Cookie-Wall.html', standalone);
  }
  console.log('Built',game);
}
