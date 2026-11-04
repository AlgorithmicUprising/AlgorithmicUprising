import {defineArcade,type GameAPI} from '../../../core/src/engine';
import {TagGame} from './game';
import {TagArt} from './art';
import {TagRenderer} from './render';
type Settings={motion:'auto'|'on'|'off';left:boolean;text:string;image:string};
defineArcade('tag-before-training','TAG BEFORE TRAINING',(emit,host)=>{
 const seed=Number(host.getAttribute('seed'))||1471,world=new TagGame(seed,emit),art=new TagArt(host,emit),renderer=new TagRenderer(art);
 const settings:Settings={motion:'auto',left:false,text:'',image:''};let accumulator=0;let dialog:HTMLDialogElement|null=null;
 try{Object.assign(settings,JSON.parse(localStorage.getItem('au-arcade:v1:tag-before-training:settings')||'{}'))}catch{}
 const save=()=>{try{localStorage.setItem('au-arcade:v1:tag-before-training:settings',JSON.stringify(settings))}catch{}};
 const apply=()=>{
  renderer.reducedMotion=settings.motion==='on'||settings.motion==='auto'&&matchMedia('(prefers-reduced-motion: reduce)').matches;
  renderer.customText=settings.text;host.toggleAttribute('data-left-handed',settings.left);
  if(settings.image){const im=new Image();im.onload=()=>{renderer.customTag=im};im.src=settings.image}else renderer.customTag=null;
 };
 apply();
 const root=host.shadowRoot!;
 const gear=document.createElement('button');gear.part.add('settings');gear.type='button';gear.textContent='⚙';gear.setAttribute('aria-label','Tag settings and My Tag');root.querySelector('.top')?.append(gear);
 gear.addEventListener('click',()=>{
  if(dialog?.open)return;
  const api=host as HTMLElement&{state:string;pause(reason:string):void;resume():void},resume=api.state==='playing';api.pause('settings');
  dialog=document.createElement('dialog');dialog.className='tag-settings';dialog.innerHTML='<form method="dialog"><h2>MY TAG + SETTINGS</h2><label>Your tag <input name="tag" maxlength="8" placeholder="Default Ø" autocomplete="off"></label><label>Import a tag image <input name="image" type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml"></label><p class="tag-local">Saved on this device. Images never leave your browser.</p><label>Reduced motion <select name="motion"><option value="auto">Auto</option><option value="on">On</option><option value="off">Off</option></select></label><label><input name="left" type="checkbox"> Left-handed controls</label><p class="tag-error" aria-live="polite"></p><div><button type="button" name="clear">CLEAR TAG</button><button value="save">SAVE / RESUME</button></div></form>';
  root.append(dialog);const form=dialog.querySelector('form')!,text=form.elements.namedItem('tag') as HTMLInputElement,motion=form.elements.namedItem('motion') as HTMLSelectElement,left=form.elements.namedItem('left') as HTMLInputElement;
  text.value=settings.text;motion.value=settings.motion;left.checked=settings.left;
  form.querySelector('[name=clear]')!.addEventListener('click',()=>{text.value='';settings.text='';settings.image='';renderer.customTag=null;save();apply()});
  form.querySelector('[name=image]')!.addEventListener('change',async event=>{
   const input=event.target as HTMLInputElement,file=input.files?.[0],error=form.querySelector('.tag-error')!;if(!file)return;
   try{
    if(file.size>8*1024*1024)throw Error('Choose an image under 8 MB.');
    let blob:Blob=file;
    if(file.type==='image/svg+xml'){
     const svg=await file.text();if(/<script|<foreignObject|\bon\w+\s*=|(?:href\s*=\s*["']\s*(?:https?:|\/\/))|url\s*\(/i.test(svg))throw Error('Use a self-contained SVG without scripts or external resources.');blob=new Blob([svg],{type:'image/svg+xml'});
    }
    const data=await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=()=>reject(Error('Image could not be read.'));reader.readAsDataURL(blob)});
    const image=new Image();await new Promise<void>((resolve,reject)=>{image.onload=()=>resolve();image.onerror=()=>reject(Error('Image could not be opened.'));image.src=data});
    const c=document.createElement('canvas');c.width=128;c.height=64;const ctx=c.getContext('2d')!,scale=Math.min(128/image.width,64/image.height),w=image.width*scale,h=image.height*scale;ctx.drawImage(image,(128-w)/2,(64-h)/2,w,h);settings.image=c.toDataURL('image/png');settings.text='';text.value='';error.textContent='Image ready.';apply();save();
   }catch(e){error.textContent=e instanceof Error?e.message:'Image could not be imported.'}
  });
  dialog.addEventListener('close',()=>{settings.motion=motion.value as Settings['motion'];settings.left=left.checked;if(text.value.trim()){settings.text=text.value.trim().slice(0,8);settings.image=''}save();apply();dialog?.remove();dialog=null;if(resume)api.resume()},{once:true});dialog.showModal();
 });
 const api={
  world,
  start(){world.reset();renderer.reset();accumulator=0;apply()},
  update(dt:number){accumulator=Math.min(accumulator+dt,5/60);while(accumulator>=1/60){world.step(1/60);accumulator-=1/60}},
  draw(ctx:CanvasRenderingContext2D,w:number,h:number){renderer.render(ctx,w,h,world)},
  input(key:string,down:boolean){world.input(key,down)},
  setMoveAxis(x:number,y:number){world.moveAxis(x,y)},
  releaseInput(){world.release()},
  setSkin(url:string|null){void art.load(url)},
  score:()=>Math.floor(world.score),over:()=>!world.alive,result:()=>world.result()
 } satisfies GameAPI&{world:TagGame};
 return api;
});
