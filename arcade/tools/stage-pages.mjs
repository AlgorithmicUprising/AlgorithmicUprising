import {cp,mkdir,rm,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
const root='.pages';
await rm(root,{recursive:true,force:true});
await mkdir(root,{recursive:true});
await cp('demo',join(root,'demo'),{recursive:true});
for(const game of ['grind-the-terms','tag-before-training']){
  await mkdir(join(root,'games',game),{recursive:true});
  await cp(join('games',game,'dist'),join(root,'games',game,'dist'),{recursive:true});
  await cp(join('games',game,'skins'),join(root,'games',game,'skins'),{recursive:true});
}
await writeFile(join(root,'.nojekyll'),'');
console.log('Ready to publish .pages/demo/ with built games and per-game skins');
