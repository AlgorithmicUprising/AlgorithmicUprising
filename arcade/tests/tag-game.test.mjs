import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {transformSync} from 'esbuild';
const source=transformSync(readFileSync('games/tag-before-training/src/game.ts','utf8'),{loader:'ts',format:'esm',target:'es2022'}).code;
const {TagGame,waveKinds}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const step=(g,seconds)=>{for(let i=0;i<Math.round(seconds*60);i++)g.step(1/60)};
const drone=(kind='scout',overrides={})=>({id:1,kind,x:484,y:177,target:6,phase:'lock',timer:2.5,lockTime:2.5,paint:0,photos:0,age:0,spin:0,touchCooldown:0,...overrides});

test('spray follows facing and completes a wall tag once, at the paint cost',()=>{
 const g=new TagGame(1);g.x=484;g.y=190;g.facing=-Math.PI/2;g.input('spray',true);step(g,1);
 assert.equal(g.tags[6].fill,1);assert.equal(g.score,100);assert.equal(g.stats.tagsSprayed,1);assert.ok(g.paint>74&&g.paint<76);
 step(g,.5);assert.equal(g.score,100);
 const away=new TagGame(1);away.x=484;away.y=190;away.facing=Math.PI/2;away.input('spray',true);step(away,1);assert.equal(away.stats.tagsSprayed,0);
});
test('painting a drone cancels its capture and awards the bonus only once',()=>{
 const g=new TagGame(1);g.x=484;g.y=208;g.facing=-Math.PI/2;g.meter=20;g.tags[6].fill=1;g.tags[6].ever=true;g.drones=[drone()];g.input('spray',true);step(g,.7);
 assert.equal(g.stats.dronesTagged,1);assert.equal(g.meter,15);assert.equal(g.score,250);assert.equal(g.drones[0].phase,'tagged');step(g,.5);assert.equal(g.stats.dronesTagged,1);assert.equal(g.score,250);
});
test('upper and lower panels can be sprayed across their width, including diagonal approaches',()=>{
 for(const row of [0,1])for(const offset of [-35,-24,0,24,35]){
  const g=new TagGame(1),t=g.tags[row*12+6];g.x=t.x+offset;g.y=row?488:190;g.facing=row?Math.PI/2:-Math.PI/2;g.input('spray',true);step(g,1);
  assert.ok(g.stats.tagsSprayed>=1,`row ${row}, horizontal offset ${offset}`);
 }
 for(const facing of [-Math.PI/4,-Math.PI*3/4]){
  const g=new TagGame(1);g.x=484;g.y=190;g.facing=facing;g.input('spray',true);step(g,1);assert.ok(g.stats.tagsSprayed>=1,`diagonal ${facing}`);
 }
 const distant=new TagGame(1);distant.x=484;distant.y=225;distant.facing=-Math.PI/2;distant.input('spray',true);step(distant,1);assert.equal(distant.stats.tagsSprayed,0);
});
test('a completed photo scrapes the tag and ends the game at 100 percent',()=>{
 const g=new TagGame(1);g.meter=90;g.tags[6].fill=1;g.tags[6].ever=true;g.drones=[drone('scout',{timer:.001})];g.step(1/60);
 assert.equal(g.meter,100);assert.equal(g.alive,false);assert.equal(g.tags[6].scraped,true);assert.equal(g.tags[6].cooldown,3);assert.equal(g.stats.tagsScraped,1);
});
test('Hoover captures adjacent bays; Watermarker extends the retag lock',()=>{
 const g=new TagGame(2);for(const i of [5,6,7]){g.tags[i].fill=1;g.tags[i].ever=true}g.drones=[drone('hoover',{timer:.001})];g.step(1/60);assert.equal(g.meter,30);assert.equal(g.stats.tagsScraped,3);
 g.drones=[drone('marker',{timer:.001})];g.step(1/60);assert.equal(g.tags[6].cooldown,8);assert.equal(g.meter,30);
});
test('paint pickups refill a can and release clears continuous input',()=>{
 const g=new TagGame(1);g.paint=20;g.x=270;g.y=335;g.step(1/60);assert.equal(g.paint,70);assert.equal(g.pickups.length,0);
 g.moveAxis(1,0);step(g,.4);assert.ok(g.vx>0);g.release();step(g,.5);assert.equal(g.vx,0);assert.equal(g.spraying,false);
});
test('paint cans collect on a nearby pass, with a finite pickup boundary',()=>{
 const near=new TagGame(1);near.x=311;near.y=335;near.paint=20;near.step(1/60);assert.equal(near.paint,70);assert.equal(near.pickups.length,0);
 const far=new TagGame(1);far.x=313;far.y=335;far.paint=20;far.step(1/60);assert.equal(far.paint,20);assert.equal(far.pickups.length,1);
});
test('seeded waves replay, empty walls are safe and score no wave bonus',()=>{
 const a=new TagGame(123),b=new TagGame(123);step(a,40);step(b,40);assert.deepEqual(a.drones,b.drones);assert.equal(a.wave,b.wave);assert.ok(a.wave>1);assert.equal(a.score,0);assert.equal(a.meter,0);
 assert.equal(waveKinds(1).length,2);assert.equal(waveKinds(3).filter(k=>k==='swarm').length,3);assert.ok(waveKinds(5).includes('hoover'));assert.ok(waveKinds(7).includes('marker'));
});
