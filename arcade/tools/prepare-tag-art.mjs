// Deterministic slicing/export of the approved Game 02 artwork sheets.
// Usage: node tools/prepare-tag-art.mjs <approval-sheets-folder> [skin-folder]
import {createRequire} from 'node:module';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {join} from 'node:path';
const require=createRequire(import.meta.url),sharp=require('sharp');
const source=process.argv[2];
if(!source)throw Error('Supply the approval sheets folder.');
const output=process.argv[3]||'games/tag-before-training/skins/au';
await mkdir(output,{recursive:true});
const frames={},files={};
async function rgba(path,rect){let im=sharp(path);if(rect)im=im.extract(rect);return im.ensureAlpha().raw().toBuffer({resolveWithObject:true})}
function clean(data){for(let i=3;i<data.length;i+=4){if(data[i]<64)data[i]=0;else if(data[i]>240)data[i]=255}return data}
function bounds(data,w,h){let l=w,t=h,r=-1,b=-1;for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(data[(y*w+x)*4+3]>85){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y)}return r<0?null:{left:l,top:t,width:r-l+1,height:b-t+1}}
async function save(name,png,w,h){
 const file=name+'.png';await writeFile(join(output,file),png);files[name]=file;
}
async function encoded(im){return im.png({palette:true,colours:256,effort:8,dither:0.35}).toBuffer()}
async function sheet(file,key,names,cols,rows,cell=128,feet=false){
 const path=join(source,file+'.png'),meta=await sharp(path).metadata(),parts=[];
 for(let i=0;i<names.length;i++){
  if(!names[i])continue;
  const col=i%cols,row=Math.floor(i/cols),l=Math.round(col*meta.width/cols),t=Math.round(row*meta.height/rows),r=Math.round((col+1)*meta.width/cols),b=Math.round((row+1)*meta.height/rows);
  const {data,info}=await rgba(path,{left:l,top:t,width:r-l,height:b-t});clean(data);
  const box=bounds(data,info.width,info.height);if(!box)throw Error('Empty approved frame '+names[i]);
  parts.push({name:names[i],index:i,data,info,box});
 }
 const extent=Math.max(...parts.map(p=>Math.max(p.box.width,p.box.height))),scale=cell*.83/extent;
 const composites=[];
 for(const p of parts){
  const w=Math.max(1,Math.round(p.box.width*scale)),h=Math.max(1,Math.round(p.box.height*scale));
  const png=await sharp(p.data,{raw:{width:p.info.width,height:p.info.height,channels:4}}).extract(p.box).resize(w,h).png().toBuffer();
  let x=Math.round((cell-w)/2),y=Math.round((cell-h)/2),ax=cell/2,ay=cell/2;
  if(feet){
   // Register the board independently of head/arm/push-leg motion.
   let minX=Infinity,maxX=-1,maxY=-1;
   for(let yy=Math.round(p.box.top+p.box.height*.78);yy<p.box.top+p.box.height;yy++)for(let xx=p.box.left;xx<p.box.left+p.box.width;xx++){
    const k=(yy*p.info.width+xx)*4;
    if(p.data[k+3]>120&&p.data[k]>155&&p.data[k+2]>75&&p.data[k+1]<130){minX=Math.min(minX,xx);maxX=Math.max(maxX,xx);maxY=Math.max(maxY,yy)}
   }
   const boardX=maxX>=0?(minX+maxX)/2:p.box.left+p.box.width/2;
   const boardY=maxY>=0?maxY-p.box.height*.035:p.box.top+p.box.height*.9;
   ay=cell*.76;x=Math.round(ax-(boardX-p.box.left)*scale);y=Math.round(ay-(boardY-p.box.top)*scale);
   x=Math.max(0,Math.min(cell-w,x));y=Math.max(0,Math.min(cell-h,y));
  }
  const cx=(p.index%cols)*cell,cy=Math.floor(p.index/cols)*cell;
  composites.push({input:png,left:cx+x,top:cy+y});frames[p.name]={sheet:key,x:cx,y:cy,w:cell,h:cell,ax,ay};
 }
 const png=await encoded(sharp({create:{width:cols*cell,height:rows*cell,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(composites));
 await save(key,png,cols*cell,rows*cell);
}
const seq=(prefix,n)=>Array.from({length:n},(_,i)=>prefix+'_'+String(i).padStart(2,'0'));
await sheet('02b-fony-overhead','skater',[...seq('skater_idle',2),null,null,...seq('skater_roll',4),...seq('skater_spray',4),...seq('skater_stun',4)],4,4,128,true);
await sheet('03-scout','scout',[...seq('drone_scout_fly',4),...seq('drone_scout_lock',2),...seq('drone_scout_tagged',6)],4,3);
await sheet('04-swarmlet','swarm',[...seq('drone_swarm_fly',4),...seq('drone_swarm_lock',2),...seq('drone_swarm_tagged',4)],4,3);
await sheet('05-hoover','hoover',[...seq('drone_hoover_fly',4),...seq('drone_hoover_lock',2),...seq('drone_hoover_tagged',6)],4,3);
await sheet('06-watermarker','marker',[...seq('drone_marker_fly',4),...seq('drone_marker_stamp',3),...seq('drone_marker_tagged',6)],4,4);
await sheet('08-props','props',['wall_brick','wall_concrete','wall_shutter','prop_dumpster','prop_crate','prop_fence','prop_exit',...seq('pickup_paint',3)],4,3);
await sheet('09-effects','effects',[...seq('fx_spray',4),'fx_lock_ring','fx_shutter','skater_shadow','drone_shadow',...seq('fx_drip',3),'tag_fony','tag_au','patch_neutral','patch_au','fx_edge_arrow'],4,4);
const background=await encoded(sharp(join(source,'01-alley.png')).resize(960,640));await save('background',background,960,640);
const tiles=await encoded(sharp(join(source,'07-tiles.png')).resize(1024,512));await save('tiles',tiles,1024,512);
const crops={title:[45,8,1395,184],stick:[157,337,328,326],knob:[493,427,165,186],spray:[697,338,329,329],sprayPressed:[1054,337,329,329],soundOn:[185,676,231,160],soundOff:[425,676,200,160],pause:[672,677,160,157],share:[878,674,228,162],settings:[1128,672,217,170]};
for(const [name,rect]of Object.entries(crops)){
 const {data,info}=await rgba(join(source,'10-interface.png'),{left:rect[0],top:rect[1],width:rect[2],height:rect[3]});clean(data);
 const box=bounds(data,info.width,info.height);if(!box)throw Error('Empty UI '+name);
 let im=sharp(data,{raw:{width:info.width,height:info.height,channels:4}}).extract(box);
 const w=name==='title'?640:name==='knob'?96:192,h=name==='title'?96:name==='knob'?96:192;
 const png=await encoded(im.resize(w,h,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}));await save(name,png,w,h);
}
// Extract the dark ink of the two approved copyright stamps from their review paper.
for(let i=0;i<2;i++){
 const {data,info}=await rgba(join(source,'12-watermarks.png'),{left:65,top:i?456:43,width:1073,height:389});
 for(let k=0;k<data.length;k+=4){const l=data[k]*.299+data[k+1]*.587+data[k+2]*.114;data[k]=data[k+1]=data[k+2]=160;data[k+3]=l<165?Math.round((1-l/230)*220):0}
 const png=await encoded(sharp(data,{raw:{width:info.width,height:info.height,channels:4}}).resize(256,128,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}));await save('watermark'+i,png,256,128);
}
await writeFile(join(output,'frames.json'),JSON.stringify({frames},null,2)+'\n');
await writeFile(join(output,'art-files.json'),JSON.stringify(files,null,2)+'\n');
console.log('Exported',Object.keys(files).length,'art files and',Object.keys(frames).length,'registered frames.');
