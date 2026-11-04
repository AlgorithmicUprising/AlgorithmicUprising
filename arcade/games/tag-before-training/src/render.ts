import {TagGame,WORLD,type DroneKind} from './game';
import {TagArt} from './art';
const sizes:Record<DroneKind,number>={scout:46,swarm:32,hoover:76,marker:46};
export class TagRenderer{
 private camX=NaN;private camY=NaN;
 customTag:HTMLImageElement|null=null;customText='';reducedMotion=false;
 constructor(private art:TagArt){}
 reset(){this.camX=this.camY=NaN}
 private sprite(ctx:CanvasRenderingContext2D,name:string,x:number,y:number,w:number,h=w,rotation=0,alpha=1){return this.art.draw(ctx,name,x,y,w,h,rotation,alpha)}
 render(ctx:CanvasRenderingContext2D,w:number,h:number,g:TagGame){
  ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle='#100d16';ctx.fillRect(0,0,w,h);
  const portrait=w/h<1,viewW=portrait?360:640,viewH=portrait?520:360,scale=Math.min(w/viewW,h/viewH),ox=(w-viewW*scale)/2,oy=(h-viewH*scale)/2;
  const desiredX=Math.max(0,Math.min(WORLD.w-viewW,g.x-viewW/2)),desiredY=Math.max(0,Math.min(WORLD.h-viewH,g.y-viewH/2));
  if(!Number.isFinite(this.camX)){this.camX=desiredX;this.camY=desiredY}
  // A small dead zone keeps the skater stable without hiding nearby wall faces.
  if(Math.abs(desiredX-this.camX)>32)this.camX+=Math.sign(desiredX-this.camX)*(Math.abs(desiredX-this.camX)-32)*.16;
  if(Math.abs(desiredY-this.camY)>24)this.camY+=Math.sign(desiredY-this.camY)*(Math.abs(desiredY-this.camY)-24)*.16;
  ctx.translate(ox,oy);ctx.scale(scale,scale);ctx.beginPath();ctx.rect(0,0,viewW,viewH);ctx.clip();ctx.save();ctx.translate(-this.camX,-this.camY);ctx.imageSmoothingEnabled=true;
  if(!this.art.image(ctx,'background',0,0,960,640)){
   ctx.fillStyle='#292033';ctx.fillRect(0,0,960,640);ctx.fillStyle='#74616a';ctx.fillRect(0,65,960,112);ctx.fillRect(0,492,960,110);ctx.strokeStyle='#403447';ctx.lineWidth=1;
   for(let x=0;x<960;x+=32){ctx.beginPath();ctx.moveTo(x,180);ctx.lineTo(x,490);ctx.stroke()}
   for(let y=180;y<490;y+=32){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(960,y);ctx.stroke()}
  }
  // Add the modular approved wall pieces over the plate, so the 24 tag bays
  // line up exactly with the gameplay targets rather than painted decoration.
  for(const t of g.tags){
   if(!this.art.loaded){
    ctx.fillStyle=['#75606c','#a99787','#5d5668'][t.id%3];ctx.fillRect(t.x-33,t.y-20,66,40);ctx.strokeStyle='#1c1521';ctx.strokeRect(t.x-33,t.y-20,66,40);
   }else if(t.fill===0&&!t.scraped&&Math.hypot(g.x-t.x,g.y-t.y)<135){
    ctx.strokeStyle='#f4eddd4d';ctx.lineWidth=1;ctx.setLineDash([3,5]);ctx.strokeRect(t.x-29,t.y-14,58,28);ctx.setLineDash([]);
   }
   if(t.fill>0){
    ctx.save();ctx.beginPath();ctx.rect(t.x-28,t.y-14,56*t.fill,28);ctx.clip();
    if(this.customTag)ctx.drawImage(this.customTag,t.x-28,t.y-14,56,28);
    else if(this.customText){ctx.font='italic 900 19px sans-serif';ctx.textAlign='center';ctx.lineWidth=3;ctx.strokeStyle='#17101a';ctx.fillStyle='#ff2889';ctx.strokeText(this.customText,t.x,t.y+7,55);ctx.fillText(this.customText,t.x,t.y+7,55)}
    else if(!this.sprite(ctx,'tag_au',t.x,t.y,65,35)){ctx.fillStyle='#ff2889';ctx.font='bold 30px sans-serif';ctx.textAlign='center';ctx.fillText('Ø',t.x,t.y+11)}
    ctx.restore();if(t.fill>=1)this.sprite(ctx,'fx_drip_0'+t.id%3,t.x+7,t.y+13,10,14);
   }
   if(t.scraped){
    // A faint ghost of the scraped tag remains visible under its copyright stamp.
    this.sprite(ctx,'tag_au',t.x,t.y,65,35,0,.22);
    if(!this.art.image(ctx,'watermark'+t.id%2,t.x-32,t.y-16,64,32,.95)){ctx.fillStyle='#bdb9bd';ctx.font='bold 11px monospace';ctx.textAlign='center';ctx.fillText('©DATASET',t.x,t.y+4)}
    if(t.cooldown>3){ctx.fillStyle='#efecd9';ctx.font='bold 9px monospace';ctx.textAlign='center';ctx.fillText('LOCK '+Math.ceil(t.cooldown),t.x,t.y+25)}
   }
  }
  for(const p of g.props){
   if(!this.sprite(ctx,'prop_'+p.kind,p.x,p.y,p.w*1.25,p.h*1.5)){ctx.fillStyle=p.kind==='dumpster'?'#7b8133':'#b77d42';ctx.fillRect(p.x-p.w/2,p.y-p.h/2,p.w,p.h)}
  }
  this.sprite(ctx,'prop_exit',18,350,76,106);this.sprite(ctx,'prop_exit',942,350,76,106);
  for(const p of g.pickups){const n=this.reducedMotion?0:Math.floor((g.elapsed-p.phase)*5)%3;this.sprite(ctx,'pickup_paint_0'+n,p.x,p.y,34,38)||this.fallbackCan(ctx,p.x,p.y)}
  for(const d of g.drones)this.sprite(ctx,'drone_shadow',d.x,d.y+19,sizes[d.kind]*.8,18,0,.4);
  this.sprite(ctx,'skater_shadow',g.x,g.y+5,46,17,0,.45);
  for(const d of g.drones){
   const mode=d.phase==='tagged'?'tagged':d.phase==='lock'?(d.kind==='marker'?'stamp':'lock'):'fly',count=mode==='fly'?4:mode==='tagged'?(d.kind==='swarm'?4:6):mode==='stamp'?3:2;
   const tick=this.reducedMotion?0:mode==='tagged'?Math.min(count-1,Math.floor((.75-d.timer)*count/.75)):Math.floor(g.elapsed*(mode==='fly'?9:10))%count;
   const name='drone_'+d.kind+'_'+mode+'_'+String(tick).padStart(2,'0');
   if(!this.sprite(ctx,name,d.x,d.y,sizes[d.kind],sizes[d.kind],d.phase==='tagged'?d.spin*.13:0)){
    ctx.fillStyle=d.phase==='tagged'?'#ff2889':'#ecddba';ctx.beginPath();ctx.arc(d.x,d.y,d.kind==='hoover'?21:13,0,Math.PI*2);ctx.fill();ctx.fillStyle='#251b2b';ctx.fillRect(d.x-5,d.y-5,10,10);
   }
   if(d.phase==='lock'){
    const t=g.tags[d.target];if(!t)continue;const left=Math.max(0,d.timer/d.lockTime);
    ctx.strokeStyle='#eaf1ba';ctx.lineWidth=1.5;ctx.beginPath();ctx.ellipse(t.x,t.y,36*left+4,19*left+3,0,0,Math.PI*2);ctx.stroke();
    ctx.strokeStyle='#d6f029';ctx.setLineDash([3,4]);ctx.strokeRect(t.x-35,t.y-20,70,40);ctx.setLineDash([]);
   }
  }
  const moving=Math.hypot(g.vx,g.vy)>12,mode=g.stun>0?'stun':g.spraying?'spray':moving?'roll':'idle',fps=mode==='idle'?4:mode==='roll'?10:12,count=mode==='idle'?2:4,index=this.reducedMotion?0:Math.floor(g.elapsed*fps)%count;
  if(!this.sprite(ctx,'skater_'+mode+'_'+String(index).padStart(2,'0'),g.x,g.y,63,63,g.facing)){
   ctx.save();ctx.translate(g.x,g.y);ctx.rotate(g.facing);ctx.fillStyle='#14101c';ctx.fillRect(-17,-8,34,16);ctx.fillStyle='#ff2889';ctx.fillRect(-8,-14,16,28);ctx.fillStyle='#e5d6ad';ctx.fillRect(8,-5,10,10);ctx.restore();
  }
  if(g.spraying){
   const phase=this.reducedMotion?1:Math.floor(g.elapsed*12)%4;
   if(!this.sprite(ctx,'fx_spray_0'+phase,g.x+Math.cos(g.facing)*34,g.y+Math.sin(g.facing)*34,31,21,g.facing,.85)){
    ctx.save();ctx.translate(g.x,g.y);ctx.rotate(g.facing);ctx.fillStyle='#ff288999';ctx.beginPath();ctx.moveTo(15,0);ctx.lineTo(48,-10);ctx.lineTo(48,10);ctx.closePath();ctx.fill();ctx.restore();
   }
  }
  if(g.shutter>0){const hit=g.tags.find(t=>t.scraped&&t.cooldown>2.75);if(hit)this.sprite(ctx,'fx_shutter',hit.x,hit.y,23,23)}
  ctx.restore();
  // Locking drones that leave the camera remain visible as a directional marker.
  for(const d of g.drones)if(d.phase==='lock'){
   const sx=d.x-this.camX,sy=d.y-this.camY;if(sx<12||sx>viewW-12||sy<50||sy>viewH-12){const ax=Math.max(14,Math.min(viewW-14,sx)),ay=Math.max(62,Math.min(viewH-14,sy)),angle=Math.atan2(sy-viewH/2,sx-viewW/2);ctx.save();ctx.translate(ax,ay);ctx.rotate(angle);ctx.fillStyle='#f4ead8';ctx.strokeStyle='#1c1322';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(9,0);ctx.lineTo(-6,-7);ctx.lineTo(-6,7);ctx.closePath();ctx.fill();ctx.stroke();ctx.restore()}
  }
  this.hud(ctx,viewW,g,portrait);ctx.restore();
 }
 private fallbackCan(ctx:CanvasRenderingContext2D,x:number,y:number){ctx.fillStyle='#ff2889';ctx.fillRect(x-7,y-10,14,22);ctx.fillStyle='#f4ead8';ctx.fillRect(x-5,y-15,10,5)}
 private hud(ctx:CanvasRenderingContext2D,w:number,g:TagGame,portrait:boolean){
  ctx.fillStyle='#140e1fef';ctx.fillRect(0,0,w,portrait?88:48);ctx.strokeStyle='#ff2889';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(0,portrait?88:48);ctx.lineTo(w,portrait?88:48);ctx.stroke();ctx.textAlign='left';ctx.fillStyle='#f3ead8';ctx.font='italic 900 '+(portrait?13:15)+'px sans-serif';ctx.fillText('STYLE '+Math.floor(g.score).toLocaleString(),12,portrait?46:20);ctx.fillText('WAVE '+g.wave,portrait?190:204,portrait?46:20);if(portrait){ctx.font='italic bold 10px sans-serif';ctx.fillStyle='#d3ed16';ctx.fillText('PUNK ARCADE',12,20);ctx.fillStyle='#f3ead8'}
  ctx.font='bold 10px monospace';ctx.fillText('TRAINING DATA '+Math.floor(g.meter)+'%',12,portrait?68:39);ctx.fillStyle='#4a3c50';ctx.fillRect(portrait?152:160,portrait?61:31,portrait?102:190,8);ctx.fillStyle=g.meter>=80?'#ec9c33':'#d3ed16';ctx.fillRect(portrait?152:160,portrait?61:31,(portrait?102:190)*g.meter/100,8);
  ctx.fillStyle=g.paint<20?'#f9b344':'#f3ead8';ctx.fillText('PAINT '+Math.ceil(g.paint),portrait?275:370,portrait?67:20);ctx.fillStyle='#ff2889';ctx.fillRect(portrait?275:370,portrait?74:30,portrait?69:78,5);ctx.fillStyle='#f3ead8';ctx.fillRect(portrait?275:370,portrait?74:30,(portrait?69:78)*g.paint/100,5);
  if(g.combo>1){ctx.fillStyle='#d6f029';ctx.font='italic bold 12px sans-serif';ctx.fillText('CHAIN x'+[1,1,1.5,2,3][g.combo],portrait?190:465,portrait?83:38)}
  if(g.messageTime>0){ctx.font='italic 900 '+(portrait?11:12)+'px sans-serif';ctx.textAlign='center';const text=g.message;ctx.fillStyle='#17101ce6';const length=Math.min(w-20,ctx.measureText(text).width+24);ctx.fillRect((w-length)/2,portrait?98:58,length,24);ctx.fillStyle='#f4edda';ctx.fillText(text,w/2,portrait?114:74,w-32);ctx.textAlign='left'}
 }
}
