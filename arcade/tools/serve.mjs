import {createServer} from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
const root=resolve(import.meta.dirname,'..',process.argv.includes('--staged') ? '.pages' : '.');
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.png':'image/png'};
const server=createServer(async(req,res)=>{
 try{
  const url=new URL(req.url||'/', 'http://localhost');
  let path=resolve(root,'.'+decodeURIComponent(url.pathname));
  if(path!==root&&!path.startsWith(root+sep)){res.writeHead(403).end('Forbidden');return;}
  const info=await stat(path).catch(()=>null);
  if(info?.isDirectory())path=resolve(path,'index.html');
  const data=await readFile(path);
  res.writeHead(200,{'Content-Type':types[extname(path)]||'application/octet-stream','Cache-Control':'no-store'}).end(data);
 }catch{res.writeHead(404).end('Not found')}
});
const port=Number(process.env.PORT||8080);server.listen(port,'127.0.0.1',()=>console.log('Punk Arcade demo: http://127.0.0.1:'+port+'/demo/'));
