export type DroneKind='scout'|'swarm'|'hoover'|'marker';
export type Segment={id:number;x:number;y:number;fill:number;ever:boolean;scraped:boolean;cooldown:number};
export type Drone={id:number;kind:DroneKind;x:number;y:number;target:number;phase:'fly'|'lock'|'hunt'|'scan'|'tagged';timer:number;lockTime:number;paint:number;photos:number;age:number;spin:number;touchCooldown:number};
export type PoliceDrone={id:number;x:number;y:number;side:number;paint:number;tagged:boolean;timer:number;spin:number};
export type Prop={kind:'dumpster'|'crate';x:number;y:number;w:number;h:number};
export type Pickup={x:number;y:number;phase:number};
export type TagStats={wave:number;tagsSprayed:number;tagsScraped:number;dronesTagged:number;perfectWaves:number;policeTagged:number;scansTriggered:number};
type Point={x:number;y:number};
export const WORLD={w:960,h:640};
export const SPRAY_RANGE=72;
export const SPRAY_HALF_ANGLE=Math.PI/6;
export const PAINT_PICKUP_RADIUS=42;
export const CAN_CAPACITY=200,MAX_CANS=3;
export const HUNT_AFTER=10,SCAN_RANGE=90,SCAN_SECONDS=2;
export const POLICE_TAG_SECONDS=1,ARREST_RANGE=40,ARREST_SECONDS=1.5;
export const DRONE_TAG_SECONDS:Record<DroneKind,number>={scout:.6,swarm:.3,hoover:1.2,marker:.6};
export const DRONE_RADIUS:Record<DroneKind,number>={scout:16,swarm:12,hoover:26,marker:16};
const speeds:Record<DroneKind,number>={scout:80,swarm:116,hoover:52,marker:66};
const spots=[{x:270,y:335},{x:690,y:360},{x:480,y:445},{x:135,y:375},{x:810,y:265}];
export function waveKinds(wave:number):DroneKind[]{
 const table:DroneKind[][]=[['scout','scout'],['scout','scout','scout'],['scout','scout','swarm','swarm','swarm'],['scout','scout','scout','scout','swarm','swarm','swarm'],['scout','scout','scout','hoover'],['scout','scout','scout','scout','swarm','swarm','swarm','swarm','swarm','swarm'],['scout','scout','scout','hoover','marker']];
 return table[Math.min(6,Math.max(0,wave-1))].slice();
}
export class TagGame{
 x=480;y=235;vx=0;vy=0;facing=-Math.PI/2;score=0;meter=0;paint=CAN_CAPACITY;wave=1;elapsed=0;waveElapsed=0;breather=0;stun=0;spraying=false;alive=true;combo=0;chainTime=0;message='TAG WALLS. KEEP THEM DISTRACTED.';messageTime=5;shutter=0;
 noFreshArtTime=0;wanted=false;dispatchIn=0;backupIn=0;arrestTime=0;cause:'trained'|'arrested'='trained';
 tags:Segment[]=[];drones:Drone[]=[];police:PoliceDrone[]=[];pickups:Pickup[]=[];
 props:Prop[]=[{kind:'dumpster',x:95,y:230,w:64,h:48},{kind:'crate',x:840,y:398,w:32,h:32},{kind:'crate',x:175,y:446,w:32,h:32}];
 stats:TagStats={wave:1,tagsSprayed:0,tagsScraped:0,dronesTagged:0,perfectWaves:0,policeTagged:0,scansTriggered:0};
 private seed:number;private randomState=1;private droneId=0;private queue:DroneKind[]=[];private spawned=0;private pickupTime=0;private scrapedThisWave=0;private axis:Point={x:0,y:0};private held=new Set<string>();
 constructor(seed=1,private emit:(event:string,detail?:Record<string,unknown>)=>void=()=>{}){this.seed=seed||1;this.reset()}
 reset(){
  this.x=480;this.y=235;this.vx=this.vy=0;this.facing=-Math.PI/2;this.score=this.meter=0;this.paint=CAN_CAPACITY;this.wave=1;this.elapsed=this.waveElapsed=this.breather=this.stun=0;this.spraying=false;this.alive=true;this.combo=this.chainTime=this.pickupTime=this.scrapedThisWave=this.droneId=0;this.message='TAG WALLS. KEEP THEM DISTRACTED.';this.messageTime=5;this.shutter=0;this.axis={x:0,y:0};this.held.clear();this.randomState=this.seed;
  this.noFreshArtTime=this.dispatchIn=this.backupIn=this.arrestTime=0;this.wanted=false;this.cause='trained';this.police=[];
  this.tags=Array.from({length:24},(_,i)=>({id:i,x:52+(i%12)*72,y:i<12?151:525,fill:0,ever:false,scraped:false,cooldown:0}));
  this.drones=[];this.pickups=[{...spots[0],phase:0}];this.stats={wave:1,tagsSprayed:0,tagsScraped:0,dronesTagged:0,perfectWaves:0,policeTagged:0,scansTriggered:0};this.beginWave();
 }
 get cans(){return Math.ceil(this.paint/CAN_CAPACITY)}
 get hasFreshArt(){return this.tags.some(t=>t.fill>=1&&!t.scraped)}
 get scanProgress(){return Math.max(0,...this.drones.filter(d=>d.phase==='scan').map(d=>1-d.timer/SCAN_SECONDS))}
 private rng(){let t=this.randomState+=0x6d2b79f5;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return((t^t>>>14)>>>0)/4294967296}
 input(key:string,down:boolean){const action=key==='tap'?'spray':key;if(down)this.held.add(action);else this.held.delete(action)}
 moveAxis(x:number,y:number){this.axis={x:Math.max(-1,Math.min(1,x)),y:Math.max(-1,Math.min(1,y))}}
 release(){this.held.clear();this.axis={x:0,y:0};this.spraying=false}
 private beginWave(){
  this.waveElapsed=0;this.scrapedThisWave=0;this.spawned=0;this.queue=waveKinds(this.wave);
  if(this.wave>=8){const count=Math.min(10,this.wave+1),kinds:DroneKind[]=['scout','scout','scout','swarm','swarm','hoover','marker'];this.queue=Array.from({length:count},()=>kinds[Math.floor(this.rng()*kinds.length)])}
  this.emit('game:wave',{wave:this.wave});
 }
 private say(message:string,time=1.8){this.message=message;this.messageTime=time}
 private add(points:number,label:string){this.combo=this.chainTime>0?Math.min(4,this.combo+1):1;this.chainTime=3;const multiplier=[1,1,1.5,2,3][this.combo];this.score+=Math.round(points*multiplier);this.emit('game:score',{score:this.score,points:Math.round(points*multiplier),label})}
 private blocked(x:number,y:number){if(x<25||x>935||y<181||y>488)return true;return this.props.some(p=>Math.hypot(x-Math.max(p.x-p.w/2,Math.min(p.x+p.w/2,x)),y-Math.max(p.y-p.h/2,Math.min(p.y+p.h/2,y)))<10)}
 canSpray(x:number,y:number,radius=0){
  const dx=x-this.x,dy=y-this.y,d=Math.hypot(dx,dy);
  // The visible drone body counts, including on a pass through open space.
  return d<=SPRAY_RANGE+radius&&(d<14||(dx*Math.cos(this.facing)+dy*Math.sin(this.facing))/d>=Math.cos(SPRAY_HALF_ANGLE+Math.asin(Math.min(1,radius/d))));
 }
 private canSprayWall(t:Segment){
  // Spray the visible 64x32 panel, rather than requiring its center to fall
  // inside the narrow cone. This also makes diagonal approaches work.
  const left=t.x-32,right=t.x+32,top=t.y-16,bottom=t.y+16;
  if(this.canSpray(Math.max(left,Math.min(right,this.x)),Math.max(top,Math.min(bottom,this.y))))return true;
  if(this.canSpray(left,top)||this.canSpray(right,top)||this.canSpray(left,bottom)||this.canSpray(right,bottom))return true;
  const rayHits=(angle:number)=>{
   const dx=Math.cos(angle),dy=Math.sin(angle);let near=0,far=SPRAY_RANGE;
   if(Math.abs(dx)<.000001){if(this.x<left||this.x>right)return false}
   else{const a=(left-this.x)/dx,b=(right-this.x)/dx;near=Math.max(near,Math.min(a,b));far=Math.min(far,Math.max(a,b))}
   if(Math.abs(dy)<.000001){if(this.y<top||this.y>bottom)return false}
   else{const a=(top-this.y)/dy,b=(bottom-this.y)/dy;near=Math.max(near,Math.min(a,b));far=Math.min(far,Math.max(a,b))}
   return near<=far;
  };
  return rayHits(this.facing)||rayHits(this.facing-SPRAY_HALF_ANGLE)||rayHits(this.facing+SPRAY_HALF_ANGLE);
 }
 private targetFor(d:Drone){const targets=this.tags.filter(t=>d.kind==='marker'?t.scraped:t.fill>=1&&!t.scraped);if(!targets.length)return -1;return targets[Math.floor(this.rng()*targets.length)].id}
 private spawn(kind:DroneKind){const edge=this.rng();this.drones.push({id:++this.droneId,kind,x:edge<.5?-25:985,y:190+this.rng()*290,target:-1,phase:'fly',timer:0,lockTime:2.5,paint:0,photos:0,age:0,spin:0,touchCooldown:0})}
 private moveDrone(d:Point,x:number,y:number,speed:number,dt:number){const dist=Math.hypot(x-d.x,y-d.y);if(dist>1){const amount=Math.min(dist,speed*dt);d.x+=(x-d.x)/dist*amount;d.y+=(y-d.y)/dist*amount}}
 private callPolice(){
  if(this.wanted)return;
  this.wanted=true;this.dispatchIn=2;this.stats.scansTriggered++;this.say('IDENTIFIED. POLICE INBOUND.',2);
  this.emit('game:identified',{dispatchSeconds:2});
 }
 private spawnPolice(side:number){this.police.push({id:++this.droneId,x:side<0?-30:990,y:Math.max(190,Math.min(480,this.y+side*65)),side,paint:0,tagged:false,timer:0,spin:0})}
 private updatePolice(dt:number){
  if(this.dispatchIn>0){this.dispatchIn=Math.max(0,this.dispatchIn-dt);if(this.dispatchIn===0){this.spawnPolice(-1);this.spawnPolice(1);this.say('POLICE: TAG THEM DIRECTLY.',2);this.emit('game:police-arrived')}}
  for(let i=this.police.length-1;i>=0;i--){
   const p=this.police[i];
   if(p.tagged){p.timer-=dt;p.spin+=dt*7;if(p.timer<=0)this.police.splice(i,1);continue}
   if(this.spraying&&this.canSpray(p.x,p.y,18)){
    p.paint+=dt;
    if(p.paint>=POLICE_TAG_SECONDS){p.tagged=true;p.timer=.75;this.stats.dronesTagged++;this.stats.policeTagged++;this.meter=Math.max(0,this.meter-5);this.add(500,'police');this.say('BADGE REPAINTED. +500 STYLE',1.5);this.emit('game:drone-tagged',{kind:'police'});continue}
   }
   this.moveDrone(p,this.x+p.side*18,this.y,165,dt);
  }
  const active=this.police.filter(p=>!p.tagged);
  // A single officer cannot arrest, but cannot become a permanent harmless pet.
  if(this.wanted&&this.dispatchIn===0){
   if(active.length===0){this.wanted=false;this.backupIn=0;this.noFreshArtTime=0;this.say('POLICE TAGGED. KEEP ROLLING.',2);this.emit('game:police-cleared')}
   else if(active.length===1){this.backupIn=this.backupIn||8;this.backupIn=Math.max(0,this.backupIn-dt);if(this.backupIn===0){this.spawnPolice(-active[0].side);this.say('POLICE BACKUP INBOUND.',1.5);this.emit('game:police-backup')}}
   else this.backupIn=0;
  }
  const surrounding=active.filter(p=>Math.hypot(p.x-this.x,p.y-this.y)<=ARREST_RANGE).length;
  this.arrestTime=surrounding>=2?Math.min(ARREST_SECONDS,this.arrestTime+dt):0;
  if(this.arrestTime>=ARREST_SECONDS){this.cause='arrested';this.alive=false;this.release();this.emit('game:arrested')}
 }
 private hunt(d:Drone,dt:number){
  if(d.phase!=='hunt'&&d.phase!=='scan'){d.phase='hunt';d.target=-1;d.timer=0}
  this.moveDrone(d,this.x,this.y,speeds[d.kind]*1.2,dt);
  if(this.wanted){d.phase='hunt';return}
  const inRange=Math.hypot(d.x-this.x,d.y-this.y)<=SCAN_RANGE;
  if(!inRange){d.phase='hunt';d.timer=0;return}
  if(d.phase!=='scan'){d.phase='scan';d.timer=SCAN_SECONDS;this.emit('game:player-scan',{duration:SCAN_SECONDS});return}
  d.timer=Math.max(0,d.timer-dt);
  if(d.timer===0){this.callPolice();d.phase='hunt'}
 }
 step(dt:number){
  if(!this.alive)return;
  this.elapsed+=dt;this.messageTime=Math.max(0,this.messageTime-dt);this.chainTime=Math.max(0,this.chainTime-dt);this.stun=Math.max(0,this.stun-dt);this.shutter=Math.max(0,this.shutter-dt);if(!this.chainTime)this.combo=0;
  for(const t of this.tags)t.cooldown=Math.max(0,t.cooldown-dt);
  let mx=this.axis.x+Number(this.held.has('right'))-Number(this.held.has('left')),my=this.axis.y+Number(this.held.has('down'))-Number(this.held.has('up'));
  const magnitude=Math.hypot(mx,my);if(magnitude>1){mx/=magnitude;my/=magnitude}
  if(this.stun>0){mx=my=0;this.vx=this.vy=0}
  this.spraying=this.held.has('spray')&&this.paint>0&&this.stun<=0;
  if(magnitude>.08&&this.stun<=0)this.facing=Math.atan2(my,mx);
  const maxSpeed=this.spraying?132:220,accel=900;
  const approach=(v:number,target:number,rate:number)=>v<target?Math.min(target,v+rate*dt):Math.max(target,v-rate*dt);
  this.vx=approach(this.vx,mx*maxSpeed,mx?accel:600);this.vy=approach(this.vy,my*maxSpeed,my?accel:600);
  const speed=Math.hypot(this.vx,this.vy);if(speed>maxSpeed){this.vx*=maxSpeed/speed;this.vy*=maxSpeed/speed}
  const nx=this.x+this.vx*dt,ny=this.y+this.vy*dt;if(!this.blocked(nx,this.y))this.x=nx;else this.vx=0;if(!this.blocked(this.x,ny))this.y=ny;else this.vy=0;
  if(this.spraying){
   this.paint=Math.max(0,this.paint-25*dt);
   const wall=this.tags.filter(t=>t.fill<1&&t.cooldown===0&&this.canSprayWall(t)).sort((a,b)=>Math.hypot(a.x-this.x,a.y-this.y)-Math.hypot(b.x-this.x,b.y-this.y))[0];
   if(wall){wall.fill=Math.min(1,wall.fill+dt/.9);if(wall.fill>=1){const repeated=wall.ever;wall.scraped=false;wall.ever=true;this.stats.tagsSprayed++;this.add(repeated?50:100,'tag');this.say(repeated?'RECLAIMED.':'FRESH PAINT.',1.1);this.emit('game:tag',{segment:wall.id,repeated});}}
   if(this.paint===0){this.say("CAN'S DRY");this.emit('game:paint-empty')}
  }
  const wasHunting=this.noFreshArtTime>=HUNT_AFTER;
  this.noFreshArtTime=this.hasFreshArt?0:this.noFreshArtTime+dt;
  if(wasHunting&&this.hasFreshArt){this.say('FRESH TAG. SCRAPERS DISTRACTED.',1.6);this.emit('game:distracted')}
  if(!wasHunting&&this.noFreshArtTime>=HUNT_AFTER){this.say('NO ART. NOW THEY WANT YOU.',2);this.emit('game:hunt')}
  this.pickupTime+=dt;
  if(this.pickupTime>=8){this.pickupTime-=8;if(this.pickups.length<2){const options=spots.filter(p=>!this.pickups.some(q=>Math.hypot(q.x-p.x,q.y-p.y)<30));if(options.length)this.pickups.push({...options[Math.floor(this.rng()*options.length)],phase:this.elapsed})}}
  for(let i=this.pickups.length-1;i>=0;i--){const p=this.pickups[i];if(this.cans<MAX_CANS&&Math.hypot(this.x-p.x,this.y-p.y)<=PAINT_PICKUP_RADIUS){this.paint+=CAN_CAPACITY;this.pickups.splice(i,1);this.say('PAINT CAN +1  ('+this.cans+'/'+MAX_CANS+')',1);this.emit('game:paint-pickup',{cans:this.cans})}}
  // Police keep pursuing during the three-second break between art waves.
  if(this.breather>0){this.updatePolice(dt);this.breather-=dt;if(this.alive&&this.breather<=0){this.wave++;this.stats.wave=this.wave;this.beginWave();this.say('WAVE '+this.wave+': THEY BROUGHT FRIENDS',2.5)}return}
  this.waveElapsed+=dt;
  const spacing=this.queue.length>1?10/(this.queue.length-1):1;
  if(this.spawned<this.queue.length&&this.waveElapsed>=.8+this.spawned*spacing&&this.drones.length<10)this.spawn(this.queue[this.spawned++]);
  for(let i=this.drones.length-1;i>=0;i--){
   const d=this.drones[i];d.age+=dt;d.touchCooldown=Math.max(0,d.touchCooldown-dt);
   if(d.phase==='tagged'){d.timer-=dt;d.spin+=dt*7;if(d.timer<=0)this.drones.splice(i,1);continue}
   if(this.spraying&&this.canSpray(d.x,d.y,DRONE_RADIUS[d.kind])){
    d.paint+=dt;
    if(d.paint>=DRONE_TAG_SECONDS[d.kind]){d.phase='tagged';d.timer=.75;this.stats.dronesTagged++;this.meter=Math.max(0,this.meter-5);this.add(d.kind==='hoover'?500:250,'drone');this.say('DRONE VANDALIZED. COPYRIGHT: YOU.',1.8);this.emit('game:drone-tagged',{kind:d.kind});continue}
   }
   if(d.kind==='marker'&&d.touchCooldown===0&&Math.hypot(this.x-d.x,this.y-d.y)<22){this.stun=.5;d.touchCooldown=1.5;this.emit('game:stun')}
   if(this.noFreshArtTime>=HUNT_AFTER){this.hunt(d,dt);continue}
   if(d.phase==='hunt'||d.phase==='scan'){d.phase='fly';d.target=-1;d.timer=0}
   if(d.age>33){this.drones.splice(i,1);continue}
   let t=this.tags[d.target];
   const valid=t&&(d.kind==='marker'?t.scraped:t.fill>=1&&!t.scraped);
   if(!valid){d.target=this.targetFor(d);t=this.tags[d.target];d.phase='fly'}
   if(!t){d.x+=Math.cos(d.age+d.id)*dt*18;d.y+=Math.sin(d.age*.7+d.id)*dt*15;if(d.age>12)this.drones.splice(i,1);continue}
   const tx=t.x,ty=t.y+(t.id<12?26:-26),dist=Math.hypot(tx-d.x,ty-d.y);
   if(d.phase==='fly'){
    if(dist>5){const step=Math.min(dist,speeds[d.kind]*dt);d.x+=(tx-d.x)/dist*step;d.y+=(ty-d.y)/dist*step}
    else if(this.wave>=4||!this.drones.some(other=>other!==d&&other.phase==='lock')){d.phase='lock';d.lockTime=Math.max(1.2,2.5-(this.wave-1)*.1)*(d.kind==='swarm'?.75:1);d.timer=d.lockTime;this.emit('game:photo-lock',{segment:t.id,kind:d.kind})}
   }else{
    d.timer-=dt;
    if(d.timer<=0){
     if(d.kind==='marker'){t.cooldown=8;this.say('WATERMARK LOCK: 8 SECONDS',1.6)}
     else{
      const group=d.kind==='hoover'?this.tags.filter(q=>Math.abs(q.id-t.id)<=1&&Math.floor(q.id/12)===Math.floor(t.id/12)):[t];
      for(const q of group)if(q.fill>=1&&!q.scraped){q.fill=0;q.scraped=true;q.cooldown=3;this.meter=Math.min(100,this.meter+10);this.stats.tagsScraped++;this.scrapedThisWave++;}
      this.shutter=.25;this.say('SCRAPED.',.9);this.emit('game:scraped',{segment:t.id,kind:d.kind});
     }
     d.photos++;d.target=-1;d.phase='fly';if(d.photos>=(d.kind==='swarm'?1:3))this.drones.splice(i,1);
    }
   }
  }
  if(this.meter>=100){this.alive=false;this.release();this.emit('game:trained');return}
  this.updatePolice(dt);if(!this.alive)return;
  if(this.spawned===this.queue.length&&this.drones.length===0){
   const held=this.tags.filter(t=>t.fill>=1&&!t.scraped).length,perfect=held>0&&this.scrapedThisWave===0;
   const bonus=held*50+(perfect?500:0);this.score+=bonus;if(perfect)this.stats.perfectWaves++;this.breather=3;this.say('ALLEY HELD  +'+bonus+' STYLE',3);this.emit('game:wave-clear',{wave:this.wave,bonus,perfect});
  }
 }
 result(){const arrested=this.cause==='arrested';return {cause:this.cause,causeLine:arrested?'Two police drones held you for 1.5 seconds. Busted.':'Training Data reached 100%. Your style is now a prompt.',stats:{...this.stats,wave:this.wave},shareText:`I held the alley for ${this.wave} waves and scored ${Math.floor(this.score)} STYLE in TAG BEFORE TRAINING before ${arrested?'the police caught me':'they trained on me'}.`}}
}
