export type ArtFrame={sheet:string;x:number;y:number;w:number;h:number;ax:number;ay:number};
export type ArtSkin={id:string;name?:string;files?:Record<string,string>;frames?:Record<string,ArtFrame>;strings?:Record<string,string>;extends?:string};
export class TagArt{
 images=new Map<string,HTMLImageElement|ImageBitmap>();frames:Record<string,ArtFrame>={};loaded=false;private token=0;skinUrl='';
 constructor(private host:HTMLElement,private emit:(name:string,detail?:Record<string,unknown>)=>void){}
 async load(url:string|null){
  const token=++this.token;this.loaded=false;for(const image of this.images.values())if('close' in image)image.close();this.images.clear();this.frames={};
  if(!url){for(const key of ['title','stick','knob','spray','sprayPressed','soundOn','soundOff','pause','share','settings'])this.host.style.removeProperty('--tag-'+key);this.host.removeAttribute('data-art-ready');this.emit('game:skin-loaded',{usingPlaceholder:true});return}
  try{
   const base=new URL(url,document.baseURI);this.skinUrl=base.href;
   const response=await fetch(base);if(!response.ok)throw Error('Skin HTTP '+response.status);
   const skin:ArtSkin=await response.json();
   if(!skin.files||!skin.frames){if(skin.id==='placeholder'||skin.extends==='placeholder'){this.host.removeAttribute('data-art-ready');this.emit('game:skin-loaded',{skin:skin.id,usingPlaceholder:true});return}throw Error('Art skin has no files/frames')}
   const entries=await Promise.all(Object.entries(skin.files).map(async([key,path])=>{
    const image=new Image();image.decoding='async';const src=new URL(path,base).href;
    await new Promise<void>((resolve,reject)=>{image.onload=()=>resolve();image.onerror=()=>reject(Error('Art could not load: '+key));image.src=src});let source:HTMLImageElement|ImageBitmap=image;try{source=await createImageBitmap(image)}catch{}return [key,source] as const;
   }));
   if(token!==this.token){for(const[,image]of entries)if('close' in image)image.close();return}
   this.images=new Map(entries);this.frames=skin.frames;this.loaded=true;
   for(const key of ['title','stick','knob','spray','sprayPressed','soundOn','soundOff','pause','share','settings']){
    const path=skin.files[key];if(path)this.host.style.setProperty('--tag-'+key,`url("${new URL(path,base).href}")`);
   }
   this.host.setAttribute('data-art-ready','true');this.emit('game:skin-loaded',{skin:skin.id,usingPlaceholder:false,frames:Object.keys(this.frames).length});
  }catch(error){if(token!==this.token)return;this.host.removeAttribute('data-art-ready');this.emit('game:error',{type:'skin',message:String(error),usingPlaceholder:true})}
 }
 draw(ctx:CanvasRenderingContext2D,name:string,x:number,y:number,w:number,h=w,rotation=0,alpha=1){
  const f=this.frames[name];if(!f)return false;const image=this.images.get(f.sheet);if(!image)return false;
  ctx.save();ctx.translate(x,y);ctx.rotate(rotation);ctx.globalAlpha*=alpha;ctx.drawImage(image,f.x,f.y,f.w,f.h,-f.ax/f.w*w,-f.ay/f.h*h,w,h);ctx.restore();return true;
 }
 image(ctx:CanvasRenderingContext2D,name:string,x:number,y:number,w:number,h:number,alpha=1){const image=this.images.get(name);if(!image)return false;ctx.save();ctx.globalAlpha*=alpha;ctx.drawImage(image,x,y,w,h);ctx.restore();return true}
}
