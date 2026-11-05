import test from 'node:test';import assert from 'node:assert/strict';import{readFileSync}from'node:fs';
const chunks=JSON.parse(readFileSync('games/grind-the-terms/src/chunks.json','utf8'));
const maxSpeed={1:210,2:260,3:330,4:420};
test('every tier contains authored chunks and the first one is a safe rail',()=>{
 for(const tier of [1,2,3,4])assert.ok(chunks.some(c=>c.tier===tier));
 const intro=chunks.find(c=>c.id==='intro-rails');assert.ok(intro);assert.equal(intro.objects[0].kind,'rail');
});
test('all fixed hazards are jumpable and have a recovery margin',()=>{
 const airtime=2*620/1800;
 for(const chunk of chunks){
  assert.ok(chunk.width>=320 && chunk.width<=1200,chunk.id);
  const danger=chunk.objects.filter(o=>!['rail','token'].includes(o.kind));
  for(const o of chunk.objects){
   assert.ok(o.at>=60,chunk.id);
   assert.ok(o.at+o.w<=chunk.width-150,chunk.id);
   // Only gaps require clearing the full width in one jump. Consent boxes are
   // traversable platforms: wide tops are deliberately playable via landing/grinding.
   if(o.kind==='gap')assert.ok(o.w+24<maxSpeed[chunk.tier]*airtime,chunk.id);
   if(['accept','popup'].includes(o.kind))assert.ok(o.w>=48&&o.w<=180,chunk.id);
  }
  for(let i=1;i<danger.length;i++)assert.ok(danger[i].at-(danger[i-1].at+danger[i-1].w)>=200,chunk.id);
 }
});
test('all powerups in chunks have a recognized type',()=>{
 for(const c of chunks)for(const o of c.objects)if(o.kind==='token')assert.ok(['shield','airboost','coin'].includes(o.power),c.id);
});
