import {cp,mkdir,rm,writeFile,stat,readFile} from 'node:fs/promises';
import {join} from 'node:path';
const root='.pages';
await rm(root,{recursive:true,force:true});
await mkdir(root,{recursive:true});
await cp('demo',join(root,'demo'),{recursive:true});
for(const game of ['grind-the-terms','tag-before-training']){
  await mkdir(join(root,'games',game),{recursive:true});
  await cp(join('games',game,'dist'),join(root,'games',game,'dist'),{recursive:true});
  await cp(join('games',game,'skins'),join(root,'games',game,'skins'),{recursive:true});
  await cp(join('games',game,'demo'),join(root,'games',game,'demo'),{recursive:true});
}
// GitHub Pages receives .pages/ as its site root. A root index is essential;
// visitors should land on the arcade rather than the GitHub Pages 404 screen.
const landing=`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="0;url=./demo/">
<title>Punk Arcade — Algorithmic Uprising</title>
<meta name="description" content="Play Punk Arcade's browser-based skate and graffiti game prototypes.">
<link rel="canonical" href="./demo/">
<style>
body{font:16px/1.6 monospace;margin:0;background:#101017;color:#f7f1e8;min-height:100vh;display:grid;place-content:center;text-align:center;padding:1rem}
h1{color:#c0ff39}a{color:#ff5ea9}
</style>
<script>window.location.replace(new URL('./demo/',window.location.href));</script>
</head>
<body><main><h1>PUNK ARCADE</h1><p>Redirecting to the arcade...</p><p><a href="./demo/">Enter Punk Arcade</a></p></main></body>
</html>`;
await writeFile(join(root,'index.html'),landing);
await writeFile(join(root,'.nojekyll'),'');
// Fail deployment before upload if a required entrypoint or game bundle is missing.
for(const path of ['index.html','demo/index.html','games/grind-the-terms/demo/index.html','games/grind-the-terms/demo/embed.html','games/grind-the-terms/dist/grind-the-terms.js','games/tag-before-training/dist/tag-before-training.js','games/tag-before-training/demo/index.html','games/tag-before-training/demo/embed.html','games/tag-before-training/skins/au/background.png','games/tag-before-training/skins/au/skater.png']){
  const file=join(root,path),s=await stat(file);
  if(!s.isFile()||s.size===0)throw new Error('Missing/empty Pages file: '+file);
}
const demo=await readFile(join(root,'demo/index.html'),'utf8');
if(!demo.includes('../games/grind-the-terms/dist/grind-the-terms.js')||!demo.includes('../games/tag-before-training/dist/tag-before-training.js'))throw new Error('Demo entrypoint references unexpected bundle locations');
for(const page of ['games/grind-the-terms/demo/index.html','games/grind-the-terms/demo/embed.html']){
 const content=await readFile(join(root,page),'utf8');
 for(const expected of ['src="../dist/grind-the-terms.js"','skin="../skins/au/skin.json"']){
  if(!content.includes(expected))throw Error('Standalone resource path invalid in '+page+': '+expected);
 }
}
for(const page of ['games/tag-before-training/demo/index.html','games/tag-before-training/demo/embed.html']){
 const content=await readFile(join(root,page),'utf8');
 for(const expected of ['src="../dist/tag-before-training.js','skin="../skins/au/skin.json'])if(!content.includes(expected))throw Error('Standalone Tag resource path invalid: '+page);
}
console.log('Pages staged and validated. Root redirects to ./demo/; both game bundles present.');

