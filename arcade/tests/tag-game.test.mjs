import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {transformSync} from 'esbuild';
const source=transformSync(readFileSync('games/tag-before-training/src/game.ts','utf8'),{loader:'ts',format:'esm',target:'es2022'}).code;
const {TagGame,waveKinds,CAN_CAPACITY,MAX_CANS,HUNT_AFTER}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const step=(g,seconds)=>{for(let i=0;i<Math.round(seconds*60);i++)g.step(1/60)};
const drone=(kind='scout',overrides={})=>({id:1,kind,x:484,y:177,target:6,phase:'lock',timer:2.5,lockTime:2.5,paint:0,photos:0,age:0,spin:0,touchCooldown:0,...overrides});
const officer=(side,overrides={})=>({id:side+10,x:480+side*18,y:335,side,paint:0,tagged:false,timer:0,spin:0,...overrides});

test('spray follows facing and completes a wall tag once, at the paint cost',()=>{
 const g=new TagGame(1);g.x=484;g.y=190;g.facing=-Math.PI/2;g.input('spray',true);step(g,1);
 assert.equal(g.tags[6].fill,1);assert.equal(g.score,100);assert.equal(g.stats.tagsSprayed,1);assert.ok(g.paint>174&&g.paint<176);
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
 const distant=new TagGame(1);distant.x=484;distant.y=265;distant.facing=-Math.PI/2;distant.input('spray',true);step(distant,1);assert.equal(distant.stats.tagsSprayed,0);
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
 const g=new TagGame(1);g.paint=20;g.x=270;g.y=335;g.step(1/60);assert.equal(g.paint,220);assert.equal(g.pickups.length,0);
 g.moveAxis(1,0);step(g,.4);assert.ok(g.vx>0);g.release();step(g,.5);assert.equal(g.vx,0);assert.equal(g.spraying,false);
});
test('paint cans collect on a nearby pass, with a finite pickup boundary',()=>{
 const near=new TagGame(1);near.x=311;near.y=335;near.paint=20;near.step(1/60);assert.equal(near.paint,220);assert.equal(near.pickups.length,0);
 const far=new TagGame(1);far.x=313;far.y=335;far.paint=20;far.step(1/60);assert.equal(far.paint,20);assert.equal(far.pickups.length,1);
});
test('seeded chases replay and idling without art eventually ends in arrest',()=>{
 const a=new TagGame(123),b=new TagGame(123);step(a,40);step(b,40);assert.deepEqual(a.drones,b.drones);assert.deepEqual(a.police,b.police);assert.equal(a.wave,b.wave);assert.equal(a.score,0);assert.equal(a.meter,0);assert.equal(a.alive,false);assert.equal(a.result().cause,'arrested');assert.equal(a.stats.scansTriggered,1);
 assert.equal(waveKinds(1).length,2);assert.equal(waveKinds(3).filter(k=>k==='swarm').length,3);assert.ok(waveKinds(5).includes('hoover'));assert.ok(waveKinds(7).includes('marker'));
});
test('three double-size cans cap inventory; a partial can keeps its slot',()=>{
 const g=new TagGame(1);assert.equal(g.paint,CAN_CAPACITY);g.x=270;g.y=335;g.step(1/60);assert.equal(g.cans,2);
 g.pickups=[{x:g.x,y:g.y,phase:0}];g.step(1/60);assert.equal(g.paint,CAN_CAPACITY*MAX_CANS);assert.equal(g.cans,3);
 g.paint-=10;g.pickups=[{x:g.x,y:g.y,phase:0}];g.step(1/60);assert.equal(g.pickups.length,1);assert.equal(g.paint,590);
 g.pickups=[];g.paint=205;g.input('spray',true);step(g,.4);assert.ok(g.paint<200&&g.paint>190);assert.equal(g.cans,1);assert.equal(g.spraying,true);
});
test('watermark restamping does not prevent the ten-second hunt',()=>{
 const g=new TagGame(1);g.tags[6].scraped=true;g.tags[6].ever=true;g.drones=[drone('marker',{timer:.001})];step(g,9.9);assert.ok(g.noFreshArtTime<HUNT_AFTER);step(g,.2);assert.ok(g.noFreshArtTime>=HUNT_AFTER);assert.ok(g.drones.some(d=>d.phase==='hunt'||d.phase==='scan'));assert.equal(g.wanted,false);
});
test('escaping scan range resets a scan; a fresh tag cancels the hunt',()=>{
 const g=new TagGame(1);g.x=480;g.y=335;g.noFreshArtTime=10;g.drones=[drone('scout',{x:520,y:335,phase:'hunt',target:-1})];step(g,.8);assert.ok(g.scanProgress>.3);assert.equal(g.wanted,false);
 g.x=800;step(g,.1);assert.equal(g.drones[0].phase,'hunt');assert.equal(g.scanProgress,0);
 g.tags[6].fill=1;g.tags[6].ever=true;g.step(1/60);assert.equal(g.noFreshArtTime,0);assert.ok(!['hunt','scan'].includes(g.drones[0].phase));assert.equal(g.wanted,false);
});
test('a drone body can be sprayed off-center in the middle of the alley',()=>{
 const g=new TagGame(1);g.x=480;g.y=335;g.facing=0;g.noFreshArtTime=10;g.drones=[drone('scout',{x:550,y:360,phase:'hunt',target:-1})];g.input('spray',true);step(g,.7);assert.equal(g.stats.dronesTagged,1);assert.equal(g.score,250);assert.ok(g.tags.every(t=>t.fill===0));
 assert.equal(g.canSpray(580,335,16),false);assert.equal(g.canSpray(400,335,16),false);
});
test('fresh art redirects ordinary hunters while police keep pursuing',()=>{
 const g=new TagGame(1);g.x=484;g.y=205;g.facing=-Math.PI/2;g.noFreshArtTime=11;g.tags[6].fill=.95;g.drones=[drone('scout',{x:700,y:300,phase:'hunt',target:-1})];g.wanted=true;g.police=[officer(-1,{x:300,y:300}),officer(1,{x:680,y:300})];
 g.input('spray',true);step(g,.1);assert.equal(g.tags[6].fill,1);assert.equal(g.noFreshArtTime,0);assert.ok(!['hunt','scan'].includes(g.drones[0].phase));assert.equal(g.wanted,true);assert.ok(g.police[0].x>300);assert.ok(g.police[1].x<680);
});
test('two police must hold continuously; escaping or painting one breaks arrest',()=>{
 const g=new TagGame(1);g.x=480;g.y=335;g.wanted=true;g.police=[officer(-1),officer(1)];step(g,.8);assert.equal(g.alive,true);assert.ok(g.arrestTime>.7);
 g.x=700;g.step(1/60);assert.equal(g.arrestTime,0);assert.equal(g.alive,true);
 g.x=480;g.facing=0;g.police=[officer(-1),officer(1)];g.input('spray',true);step(g,1.1);assert.equal(g.stats.policeTagged,1);assert.equal(g.arrestTime,0);assert.equal(g.alive,true);
});
test('a lone officer calls backup, and arrest remains active between waves',()=>{
 const g=new TagGame(1);g.x=480;g.y=335;g.wanted=true;g.police=[officer(-1)];step(g,7);assert.equal(g.alive,true);assert.equal(g.arrestTime,0);step(g,1.2);assert.equal(g.police.filter(p=>!p.tagged).length,2);
 g.breather=3;g.police=[officer(-1),officer(1)];step(g,1.6);assert.equal(g.alive,false);assert.equal(g.result().cause,'arrested');assert.match(g.result().causeLine,/1.5 seconds/);
});
test('tagging both police clears pursuit; retry resets every pursuit state',()=>{
 const g=new TagGame(1);g.x=480;g.y=335;g.wanted=true;g.police=[officer(-1,{tagged:true,timer:.01}),officer(1,{tagged:true,timer:.01})];g.noFreshArtTime=12;g.step(1/60);assert.equal(g.wanted,false);assert.equal(g.noFreshArtTime,0);
 g.wanted=true;g.dispatchIn=2;g.arrestTime=1;g.paint=580;g.cause='arrested';g.reset();assert.equal(g.wanted,false);assert.equal(g.dispatchIn,0);assert.equal(g.arrestTime,0);assert.equal(g.police.length,0);assert.equal(g.cans,1);assert.equal(g.result().cause,'trained');
});
