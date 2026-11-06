import {TagGame,WORLD,SPRAY_RANGE,SPRAY_HALF_ANGLE,CAN_CAPACITY,MAX_CANS,HUNT_AFTER,SCAN_SECONDS,ARREST_SECONDS,ARREST_RANGE,DRONE_TAG_SECONDS,POLICE_TAG_SECONDS,type DroneKind} from './game';
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
  const portrait=w/h<1,viewH=portrait?520:360,viewW=portrait?viewH*w/h:640,scale=portrait?h/viewH:Math.min(w/viewW,h/viewH),ox=portrait?0:(w-viewW*scale)/2,oy=portrait?0:(h-viewH*scale)/2;
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
    this.watermark(ctx,t.x,t.y);
    if(t.cooldown>3){ctx.fillStyle='#efecd9';ctx.font='bold 9px monospace';ctx.textAlign='center';ctx.fillText('LOCK '+Math.ceil(t.cooldown),t.x,t.y+25)}
   }
  }
  for(const p of g.props){
   if(!this.sprite(ctx,'prop_'+p.kind,p.x,p.y,p.w*1.25,p.h*1.5)){ctx.fillStyle=p.kind==='dumpster'?'#7b8133':'#b77d42';ctx.fillRect(p.x-p.w/2,p.y-p.h/2,p.w,p.h)}
  }
  this.sprite(ctx,'prop_exit',18,350,76,106);this.sprite(ctx,'prop_exit',942,350,76,106);
  for(const p of g.pickups){const n=this.reducedMotion?0:Math.floor((g.elapsed-p.phase)*5)%3;this.sprite(ctx,'pickup_paint_0'+n,p.x,p.y,34,38)||this.fallbackCan(ctx,p.x,p.y)}
  for(const d of g.drones)this.sprite(ctx,'drone_shadow',d.x,d.y+19,sizes[d.kind]*.8,18,0,.4);
  for(const p of g.police)this.sprite(ctx,'drone_shadow',p.x,p.y+20,45,18,0,.4);
  this.sprite(ctx,'skater_shadow',g.x,g.y+5,46,17,0,.45);
  for(const d of g.drones){
   const mode=d.phase==='tagged'?'tagged':d.phase==='lock'||d.phase==='scan'?(d.kind==='marker'?'stamp':'lock'):'fly',count=mode==='fly'?4:mode==='tagged'?(d.kind==='swarm'?4:6):mode==='stamp'?3:2;
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
   if(d.phase==='scan'){
    ctx.strokeStyle='#ffb04e';ctx.lineWidth=2;ctx.setLineDash([4,4]);ctx.beginPath();ctx.moveTo(d.x,d.y);ctx.lineTo(g.x,g.y);ctx.stroke();ctx.setLineDash([]);
    ctx.beginPath();ctx.arc(g.x,g.y,34,-Math.PI/2,-Math.PI/2+Math.PI*2*(1-d.timer/SCAN_SECONDS));ctx.stroke();
   }
   if(d.paint>0&&d.phase!=='tagged')this.paintProgress(ctx,d.x,d.y+sizes[d.kind]/2,Math.min(48,sizes[d.kind]),d.paint/DRONE_TAG_SECONDS[d.kind]);
  }
  for(const p of g.police){
   const tick=this.reducedMotion?0:Math.floor(g.elapsed*9)%4;
   ctx.save();ctx.translate(p.x,p.y);if(p.tagged)ctx.rotate(p.spin*.13);
   this.sprite(ctx,'drone_scout_fly_'+String(tick).padStart(2,'0'),0,0,57,57);
   ctx.fillStyle=p.tagged?'#ff2889':'#233e61';ctx.strokeStyle='#f3ead8';ctx.lineWidth=1.5;
   ctx.beginPath();ctx.moveTo(-16,-13);ctx.lineTo(16,-13);ctx.lineTo(18,7);ctx.lineTo(0,20);ctx.lineTo(-18,7);ctx.closePath();ctx.fill();ctx.stroke();
   // Solid lights and a labelled shield distinguish enforcement without flashes.
   ctx.fillStyle='#f66d72';ctx.fillRect(-19,-19,13,5);ctx.fillStyle='#72cfff';ctx.fillRect(6,-19,13,5);
   ctx.fillStyle='#f3ead8';ctx.font='900 13px monospace';ctx.textAlign='center';ctx.fillText('PD',0,5);
   ctx.fillStyle='#101c30';ctx.fillRect(-25,21,50,13);ctx.fillStyle='#f3ead8';ctx.font='900 9px monospace';ctx.fillText('POLICE',0,31);ctx.restore();
   if(!p.tagged&&p.paint>0)this.paintProgress(ctx,p.x,p.y+37,48,p.paint/POLICE_TAG_SECONDS);
  }
  if(g.arrestTime>0){ctx.strokeStyle='#ff8a5c';ctx.lineWidth=4;ctx.beginPath();ctx.arc(g.x,g.y,ARREST_RANGE,-Math.PI/2,-Math.PI/2+Math.PI*2*g.arrestTime/ARREST_SECONDS);ctx.stroke()}
  const moving=Math.hypot(g.vx,g.vy)>12,mode=g.stun>0?'stun':g.spraying?'spray':moving?'roll':'idle',fps=mode==='idle'?4:mode==='roll'?10:12,count=mode==='idle'?2:4,index=this.reducedMotion?0:Math.floor(g.elapsed*fps)%count;
  if(!this.sprite(ctx,'skater_'+mode+'_'+String(index).padStart(2,'0'),g.x,g.y,63,63,g.facing)){
   ctx.save();ctx.translate(g.x,g.y);ctx.rotate(g.facing);ctx.fillStyle='#14101c';ctx.fillRect(-17,-8,34,16);ctx.fillStyle='#ff2889';ctx.fillRect(-8,-14,16,28);ctx.fillStyle='#e5d6ad';ctx.fillRect(8,-5,10,10);ctx.restore();
  }
  if(g.spraying){
   const phase=this.reducedMotion?1:Math.floor(g.elapsed*12)%4;
   ctx.save();ctx.translate(g.x,g.y);ctx.rotate(g.facing);const mist=ctx.createLinearGradient(14,0,SPRAY_RANGE,0);mist.addColorStop(0,'#ff288960');mist.addColorStop(1,'#ff288910');ctx.fillStyle=mist;ctx.beginPath();ctx.moveTo(14,0);ctx.arc(0,0,SPRAY_RANGE,-SPRAY_HALF_ANGLE,SPRAY_HALF_ANGLE);ctx.closePath();ctx.fill();ctx.restore();
   this.sprite(ctx,'fx_spray_0'+phase,g.x+Math.cos(g.facing)*48,g.y+Math.sin(g.facing)*48,54,32,g.facing,.85);
  }
  if(g.shutter>0){const hit=g.tags.find(t=>t.scraped&&t.cooldown>2.75);if(hit)this.sprite(ctx,'fx_shutter',hit.x,hit.y+(hit.id<12?28:-28),20,20)}
  ctx.restore();
  // Locking drones that leave the camera remain visible as a directional marker.
  for(const d of g.drones)if(d.phase==='lock'||d.phase==='hunt'||d.phase==='scan')this.edgeArrow(ctx,d.x,d.y,viewW,viewH,portrait,false);
  for(const p of g.police)if(!p.tagged)this.edgeArrow(ctx,p.x,p.y,viewW,viewH,portrait,true);
  this.hud(ctx,viewW,g,portrait);ctx.restore();
 }
 private edgeArrow(ctx:CanvasRenderingContext2D,x:number,y:number,w:number,h:number,portrait:boolean,police:boolean){
  const sx=x-this.camX,sy=y-this.camY,top=portrait?121:81;
  if(sx>=12&&sx<=w-12&&sy>=top&&sy<=h-12)return;
  const ax=Math.max(14,Math.min(w-14,sx)),ay=Math.max(top,Math.min(h-14,sy)),angle=Math.atan2(sy-h/2,sx-w/2);
  ctx.save();ctx.translate(ax,ay);ctx.rotate(angle);ctx.fillStyle=police?'#ff9973':'#f4ead8';ctx.strokeStyle='#1c1322';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(9,0);ctx.lineTo(-6,-7);ctx.lineTo(-6,7);ctx.closePath();ctx.fill();ctx.stroke();ctx.restore();
  if(police){ctx.fillStyle='#101c30';ctx.fillRect(ax-10,ay+9,20,12);ctx.fillStyle='#f3ead8';ctx.textAlign='center';ctx.font='900 9px monospace';ctx.fillText('PD',ax,ay+18)}
 }
 private paintProgress(ctx:CanvasRenderingContext2D,x:number,y:number,w:number,fraction:number){ctx.fillStyle='#160e1d';ctx.fillRect(x-w/2-1,y,w+2,5);ctx.fillStyle='#ff58a2';ctx.fillRect(x-w/2,y+1,w*Math.min(1,fraction),3)}
 private watermark(ctx:CanvasRenderingContext2D,x:number,y:number){
  ctx.save();ctx.translate(x,y);
  ctx.fillStyle='#f4eddc';ctx.fillRect(-34,-14,68,28);
  ctx.strokeStyle='#211627';ctx.lineWidth=1.5;ctx.strokeRect(-34,-14,68,28);
  ctx.save();ctx.beginPath();ctx.rect(-33,-13,66,26);ctx.clip();ctx.lineWidth=3;
  for(let edge=-38;edge<38;edge+=9){ctx.beginPath();ctx.moveTo(edge,-14);ctx.lineTo(edge+5,-10);ctx.moveTo(edge,10);ctx.lineTo(edge+5,14);ctx.stroke()}
  ctx.restore();
  // Keep the lettering as crisp runtime text; the distressed raster stamp
  // becomes unreadable when reduced onto a phone-sized wall panel.
  ctx.fillStyle='#160e1d';ctx.font='900 12px monospace';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('©DATASET',0,1,62);
  ctx.restore();
 }
 private fallbackCan(ctx:CanvasRenderingContext2D,x:number,y:number){ctx.fillStyle='#ff2889';ctx.fillRect(x-7,y-10,14,22);ctx.fillStyle='#f4ead8';ctx.fillRect(x-5,y-15,10,5)}
 private hud(ctx:CanvasRenderingContext2D,w:number,g:TagGame,portrait:boolean){
  ctx.fillStyle='#140e1fef';ctx.fillRect(0,0,w,portrait?88:48);ctx.strokeStyle='#ff2889';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(0,portrait?88:48);ctx.lineTo(w,portrait?88:48);ctx.stroke();ctx.textAlign='left';ctx.fillStyle='#f3ead8';ctx.font='italic 900 '+(portrait?13:15)+'px sans-serif';ctx.fillText('STYLE '+Math.floor(g.score).toLocaleString(),12,portrait?46:20);ctx.fillText('WAVE '+g.wave,portrait?190:204,portrait?46:20);if(portrait){ctx.font='italic bold 10px sans-serif';ctx.fillStyle='#d3ed16';ctx.fillText('PUNK ARCADE',12,20);ctx.fillStyle='#f3ead8'}
  ctx.font='bold 10px monospace';ctx.fillText('TRAINING DATA '+Math.floor(g.meter)+'%',12,portrait?68:39);ctx.fillStyle='#4a3c50';ctx.fillRect(portrait?152:160,portrait?61:31,portrait?102:190,8);ctx.fillStyle=g.meter>=80?'#ec9c33':'#d3ed16';ctx.fillRect(portrait?152:160,portrait?61:31,(portrait?102:190)*g.meter/100,8);
  ctx.fillStyle=g.paint<25?'#f9b344':'#f3ead8';ctx.fillText('CANS '+g.cans+'/'+MAX_CANS,portrait?275:370,portrait?67:20);
  const canX=portrait?275:370,canY=portrait?74:30,canW=portrait?20:23;
  for(let i=0;i<MAX_CANS;i++){ctx.fillStyle='#4a3c50';ctx.fillRect(canX+i*(canW+4),canY,canW,6);ctx.fillStyle='#ff58a2';ctx.fillRect(canX+i*(canW+4),canY,canW*Math.max(0,Math.min(1,(g.paint-i*CAN_CAPACITY)/CAN_CAPACITY)),6)}
  if(g.combo>1){ctx.fillStyle='#d6f029';ctx.font='italic bold 12px sans-serif';ctx.fillText('CHAIN x'+[1,1,1.5,2,3][g.combo],portrait?190:465,portrait?83:38)}
  const officers=g.police.filter(p=>!p.tagged).length;
  const threat=g.arrestTime>0?'ARREST '+Math.round(g.arrestTime/ARREST_SECONDS*100)+'% — MOVE / SPRAY':g.dispatchIn>0?'POLICE INBOUND: '+Math.ceil(g.dispatchIn)+'s':g.wanted?'POLICE '+officers+' — TAG DIRECTLY'+(g.backupIn>0?' • BACKUP '+Math.ceil(g.backupIn)+'s':''):g.scanProgress>0?'FONY SCAN '+Math.round(g.scanProgress*100)+'% — MOVE / SPRAY':g.noFreshArtTime>=HUNT_AFTER?'HUNTED — TAG A WALL OR DRONE':g.hasFreshArt?'FRESH ART DISTRACTS SCRAPERS':'NO FRESH ART: HUNT IN '+Math.ceil(HUNT_AFTER-g.noFreshArtTime)+'s';
  ctx.fillStyle='#17101cf2';ctx.fillRect(6,portrait?94:54,w-12,22);ctx.fillStyle=g.wanted?'#ffac89':g.noFreshArtTime>=HUNT_AFTER?'#ffd47f':'#d3ed68';ctx.font='900 10px monospace';ctx.textAlign='center';ctx.fillText(threat,w/2,portrait?109:69,w-24);
  if(g.messageTime>0){ctx.font='italic 900 '+(portrait?11:12)+'px sans-serif';const text=g.message;ctx.fillStyle='#17101ce6';const length=Math.min(w-20,ctx.measureText(text).width+24);ctx.fillRect((w-length)/2,portrait?122:82,length,24);ctx.fillStyle='#f4edda';ctx.fillText(text,w/2,portrait?138:98,w-32)}ctx.textAlign='left';
 }
}
