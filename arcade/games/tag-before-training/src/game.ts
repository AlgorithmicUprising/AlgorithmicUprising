export type DroneKind='scout'|'swarm'|'hoover'|'marker';
export type Segment={id:number;x:number;y:number;fill:number;ever:boolean;scraped:boolean;cooldown:number};
export type Drone={id:number;kind:DroneKind;x:number;y:number;target:number;phase:'fly'|'lock'|'tagged';timer:number;lockTime:number;paint:number;photos:number;age:number;spin:number;touchCooldown:number};
export type Prop={kind:'dumpster'|'crate';x:number;y:number;w:number;h:number};
export type Pickup={x:number;y:number;phase:number};
export type TagStats={wave:number;tagsSprayed:number;tagsScraped:number;dronesTagged:number;perfectWaves:number};
type Point={x:number;y:number};
const TAU=Math.PI*2;
export const WORLD={w:960,h:640};
export const SPRAY_RANGE=48;
const duration:Record<DroneKind,number>={scout:.6,swarm:.3,hoover:1.2,marker:.6};
const speeds:Record<DroneKind,number>={scout:80,swarm:116,hoover:52,marker:66};
const spots=[{x:270,y:335},{x:690,y:360},{x:480,y:445},{x:135,y:375},{x:810,y:265}];
export function waveKinds(wave:number):DroneKind[]{
 const table:DroneKind[][]=[['scout','scout'],['scout','scout','scout'],['scout','scout','swarm','swarm','swarm'],['scout','scout','scout','scout','swarm','swarm','swarm'],['scout','scout','scout','hoover'],['scout','scout','scout','scout','swarm','swarm','swarm','swarm','swarm','swarm'],['scout','scout','scout','hoover','marker']];
 return table[Math.min(6,Math.max(0,wave-1))].slice();
}
export class TagGame{
 x=480;y=235;vx=0;vy=0;facing=-Math.PI/2;score=0;meter=0;paint=100;wave=1;elapsed=0;waveElapsed=0;breather=0;stun=0;spraying=false;alive=true;combo=0;chainTime=0;message='HOLD SPACE NEAR A WALL';messageTime=5;shutter=0;
 tags:Segment[]=[];drones:Drone[]=[];pickups:Pickup[]=[];
 props:Prop[]=[{kind:'dumpster',x:95,y:230,w:64,h:48},{kind:'crate',x:840,y:398,w:32,h:32},{kind:'crate',x:175,y:446,w:32,h:32}];
 stats:TagStats={wave:1,tagsSprayed:0,tagsScraped:0,dronesTagged:0,perfectWaves:0};
 private seed:number;private randomState=1;private droneId=0;private queue:DroneKind[]=[];private spawned=0;private pickupTime=0;private scrapedThisWave=0;private axis:Point={x:0,y:0};private held=new Set<string>();
 constructor(seed=1,private emit:(event:string,detail?:Record<string,unknown>)=>void=()=>{}){this.seed=seed||1;this.reset()}
 reset(){
  this.x=480;this.y=235;this.vx=this.vy=0;this.facing=-Math.PI/2;this.score=this.meter=0;this.paint=100;this.wave=1;this.elapsed=this.waveElapsed=this.breather=this.stun=0;this.spraying=false;this.alive=true;this.combo=this.chainTime=this.pickupTime=this.scrapedThisWave=this.droneId=0;this.message='HOLD SPACE NEAR A WALL';this.messageTime=5;this.shutter=0;this.axis={x:0,y:0};this.held.clear();this.randomState=this.seed;
  this.tags=Array.from({length:24},(_,i)=>({id:i,x:52+(i%12)*72,y:i<12?151:525,fill:0,ever:false,scraped:false,cooldown:0}));
  this.drones=[];this.pickups=[{...spots[0],phase:0}];this.stats={wave:1,tagsSprayed:0,tagsScraped:0,dronesTagged:0,perfectWaves:0};this.beginWave();
 }
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
 canSpray(x:number,y:number){const dx=x-this.x,dy=y-this.y,d=Math.hypot(dx,dy);return d<=SPRAY_RANGE&&(d<14||(dx*Math.cos(this.facing)+dy*Math.sin(this.facing))/d>=Math.cos(Math.PI/9))}
 private targetFor(d:Drone){const targets=this.tags.filter(t=>d.kind==='marker'?t.scraped:t.fill>=1&&!t.scraped);if(!targets.length)return -1;return targets[Math.floor(this.rng()*targets.length)].id}
 private spawn(kind:DroneKind){const edge=this.rng();this.drones.push({id:++this.droneId,kind,x:edge<.5?-25:985,y:190+this.rng()*290,target:-1,phase:'fly',timer:0,lockTime:2.5,paint:0,photos:0,age:0,spin:0,touchCooldown:0})}
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
   const wall=this.tags.filter(t=>t.fill<1&&t.cooldown===0&&this.canSpray(t.x,t.y)).sort((a,b)=>Math.hypot(a.x-this.x,a.y-this.y)-Math.hypot(b.x-this.x,b.y-this.y))[0];
   if(wall){wall.fill=Math.min(1,wall.fill+dt/.9);if(wall.fill>=1){const repeated=wall.ever;wall.scraped=false;wall.ever=true;this.stats.tagsSprayed++;this.add(repeated?50:100,'tag');this.say(repeated?'RECLAIMED.':'FRESH PAINT.',1.1);this.emit('game:tag',{segment:wall.id,repeated});}}
   if(this.paint===0){this.say("CAN'S DRY");this.emit('game:paint-empty')}
  }
  this.pickupTime+=dt;
  if(this.pickupTime>=8){this.pickupTime-=8;if(this.pickups.length<2){const options=spots.filter(p=>!this.pickups.some(q=>Math.hypot(q.x-p.x,q.y-p.y)<30));if(options.length)this.pickups.push({...options[Math.floor(this.rng()*options.length)],phase:this.elapsed})}}
  for(let i=this.pickups.length-1;i>=0;i--){const p=this.pickups[i];if(this.paint<100&&Math.hypot(this.x-p.x,this.y-p.y)<24){this.paint=Math.min(100,this.paint+50);this.pickups.splice(i,1);this.say('PAINT +50',1);this.emit('game:paint-pickup')}}
  if(this.breather>0){this.breather-=dt;if(this.breather<=0){this.wave++;this.stats.wave=this.wave;this.beginWave();this.say('WAVE '+this.wave+': THEY BROUGHT FRIENDS',2.5)}return}
  this.waveElapsed+=dt;
  const spacing=this.queue.length>1?10/(this.queue.length-1):1;
  if(this.spawned<this.queue.length&&this.waveElapsed>=.8+this.spawned*spacing&&this.drones.length<10)this.spawn(this.queue[this.spawned++]);
  for(let i=this.drones.length-1;i>=0;i--){
   const d=this.drones[i];d.age+=dt;d.touchCooldown=Math.max(0,d.touchCooldown-dt);
   if(d.phase==='tagged'){d.timer-=dt;d.spin+=dt*7;if(d.timer<=0)this.drones.splice(i,1);continue}
   if(d.age>33){this.drones.splice(i,1);continue}
   if(this.spraying&&this.canSpray(d.x,d.y)){
    d.paint+=dt;
    if(d.paint>=duration[d.kind]){d.phase='tagged';d.timer=.75;this.stats.dronesTagged++;this.meter=Math.max(0,this.meter-5);this.add(d.kind==='hoover'?500:250,'drone');this.say('DRONE VANDALIZED. COPYRIGHT: YOU.',1.8);this.emit('game:drone-tagged',{kind:d.kind});continue}
   }
   if(d.kind==='marker'&&d.touchCooldown===0&&Math.hypot(this.x-d.x,this.y-d.y)<22){this.stun=.5;d.touchCooldown=1.5;this.emit('game:stun')}
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
  if(this.spawned===this.queue.length&&this.drones.length===0){
   const held=this.tags.filter(t=>t.fill>=1&&!t.scraped).length,perfect=held>0&&this.scrapedThisWave===0;
   const bonus=held*50+(perfect?500:0);this.score+=bonus;if(perfect)this.stats.perfectWaves++;this.breather=3;this.say('ALLEY HELD  +'+bonus+' STYLE',3);this.emit('game:wave-clear',{wave:this.wave,bonus,perfect});
  }
 }
 result(){return {cause:'trained',causeLine:"Congrats. You're now a prompt.",stats:{...this.stats,wave:this.wave},shareText:`I held the alley for ${this.wave} waves and scored ${Math.floor(this.score)} STYLE in TAG BEFORE TRAINING before they trained on me.`}}
}
