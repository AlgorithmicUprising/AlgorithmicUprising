import {defineArcade,type GameAPI} from '../../../core/src/engine';

// Placeholder-first M0 runner. Keep game mechanics independent of future sprite art.
type Kind='accept'|'popup'|'gap'|'rail';
type Obstacle={x:number;kind:Kind;w:number;scored:boolean};
defineArcade('grind-the-terms','GRIND THE TERMS',()=>{
  const ground=270, playerX=135, gravity=1020, jumpVelocity=-500;
  let y=ground, vy=0, elapsed=0, speed=180, distance=0, bonus=0;
  let alive=true, held=false, spawnDistance=340, obstacleIndex=0;
  let grinding=false, obstacles:Obstacle[]=[];

  const score=()=>Math.floor(distance/48)+bonus;
  const start=()=>{
    y=ground;vy=0;elapsed=0;speed=180;distance=0;bonus=0;
    alive=true;held=false;spawnDistance=340;obstacleIndex=0;
    grinding=false;obstacles=[];
  };
  const input=(key:string,down:boolean)=>{
    if(key!=='tap'&&key!=='up')return;
    if(down&&!held){
      if(grinding){grinding=false;vy=jumpVelocity*.55;}
      else if(y>=ground-2)vy=jumpVelocity;
    }
    if(!down&&grinding){grinding=false;vy=jumpVelocity*.35;}
    held=down;
  };
  const spawn=()=>{
    // Safe rails establish the controls before consent boxes become lethal.
    // The first dangerous hazard cannot spawn before 18 seconds.
    const tier=elapsed<18?0:elapsed<40?1:elapsed<70?2:3;
    const pool:Kind[]=tier===0?['rail']:tier===1?
      ['rail','accept','rail','popup']:tier===2?
      ['accept','rail','popup','accept','gap']:
      ['popup','accept','gap','rail','popup','accept'];
    const kind=pool[(obstacleIndex+Math.floor(Math.random()*pool.length))%pool.length];
    obstacleIndex++;
    obstacles.push({x:665,kind,w:kind==='rail'?105:kind==='gap'?66:kind==='popup'?48:40,scored:false});
    spawnDistance=Math.max(350,530-elapsed*2.3);
  };
  const update=(dt:number)=>{
    if(!alive)return;
    elapsed+=dt;
    const travelSpeed=Math.min(420,180+Math.max(0,elapsed-8)*2.35);
    const moved=travelSpeed*dt;speed=travelSpeed;distance+=moved;
    spawnDistance-=moved;
    if(spawnDistance<=0)spawn();

    if(!grinding){vy+=gravity*dt;y+=vy*dt;if(y>=ground){y=ground;vy=0}}
    let onRail=false;
    for(const o of obstacles){
      o.x-=moved;
      if(!o.scored&&o.x+o.w<playerX-16){
        o.scored=true;
        bonus+=o.kind==='rail'?6:o.kind==='popup'?5:o.kind==='gap'?8:3;
      }
      if(o.x>=playerX+17||o.x+o.w<=playerX-16)continue;
      if(o.kind==='rail'){
        const descending=vy>=0;
        if(held&&descending&&y>=ground-43&&y<=ground-17){
          y=ground-22;vy=0;grinding=true;onRail=true;bonus+=dt*10;
        }else if(grinding)onRail=true;
        continue;
      }
      if(o.kind==='gap'){
        if(y>ground-24){alive=false;break}
      }else if(y>ground-39){alive=false;break}
    }
    if(grinding&&!onRail){grinding=false;vy=0}
    obstacles=obstacles.filter(o=>o.x+o.w>-30);
  };
  const draw=(ctx:CanvasRenderingContext2D,w:number,h:number)=>{
    ctx.save();ctx.setTransform(w/640,0,0,h/360,0,0);
    ctx.fillStyle='#171121';ctx.fillRect(0,0,640,360);
    // Clause lines and legal margins form the placeholder environment.
    ctx.strokeStyle='#2c263b';ctx.lineWidth=2;
    for(let i=0;i<8;i++){
      const x=(i*94-distance*.25%94+94)%940-94;
      ctx.beginPath();ctx.moveTo(x,55);ctx.lineTo(x,268);ctx.stroke();
    }
    ctx.font='12px monospace';ctx.fillStyle='#70627f';
    for(let i=0;i<9;i++){
      ctx.fillText('§ '+(Math.floor(distance/220)+i+1)+'  TERMS AND CONDITIONS APPLY',12,84+i*23);
    }
    ctx.fillStyle='#ddd2df';ctx.fillRect(0,ground+4,640,6);
    for(const o of obstacles){
      if(o.kind==='rail'){
        ctx.fillStyle='#c6ddec';ctx.fillRect(o.x,ground-22,o.w,7);
        ctx.fillRect(o.x+8,ground-15,4,17);ctx.fillRect(o.x+o.w-12,ground-15,4,17);
      }else if(o.kind==='gap'){
        ctx.fillStyle='#0b0910';ctx.fillRect(o.x,ground-1,o.w,18);
      }else{
        ctx.fillStyle=o.kind==='accept'?'#eacc62':'#eb779c';
        ctx.fillRect(o.x,ground-36,o.w,36);
        ctx.fillStyle='#160c17';ctx.font='9px monospace';
        ctx.fillText(o.kind==='accept'?'ACCEPT':'AGREE?',o.x+2,ground-16);
      }
    }
    ctx.fillStyle='#ff3d7f';ctx.fillRect(playerX-15,y-39,30,33);
    ctx.fillStyle='#f0d2a4';ctx.fillRect(playerX-11,y-50,22,13);
    ctx.fillStyle='#eaeaea';ctx.fillRect(playerX-19,y,38,5);
    ctx.fillStyle='#111';ctx.fillRect(playerX-14,y+3,6,5);ctx.fillRect(playerX+9,y+3,6,5);
    ctx.fillStyle='#f5f1eb';ctx.font='bold 18px monospace';
    ctx.fillText('CLAUSES SKIPPED '+Math.floor(score()),12,25);
    ctx.font='bold 11px monospace';ctx.fillStyle='#f8b3d1';
    if(elapsed<18)ctx.fillText('PRACTICE RUN  •  SPACE / TAP TO OLLIE',12,44);
    else ctx.fillText('FINE PRINT INCOMING  •  '+Math.round(speed)+' px/s',12,44);
    if(grinding){ctx.fillStyle='#b8ff35';ctx.fillText('GRINDING THE FINE PRINT',200,65)}
    ctx.restore();
  };
  start();
  return {start,update,draw,input,score:()=>Math.floor(score()),over:()=>!alive} satisfies GameAPI;
});
