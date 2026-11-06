import { games } from './games.mjs';
import { build } from 'esbuild';
import { mkdir } from 'node:fs/promises';
for (const game of games) {
  const outdir = `games/${game}/dist`;
  await mkdir(outdir,{recursive:true});
  await build({entryPoints:[`games/${game}/src/index.ts`],outfile:`${outdir}/${game}.js`,loader:{'.css':'text','.html':'text'},bundle:true,format:'esm',target:['es2022'],minify:true,sourcemap:true,legalComments:'inline'});
  console.log('Built',game);
}
