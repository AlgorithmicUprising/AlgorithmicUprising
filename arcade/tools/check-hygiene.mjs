import{readdirSync,readFileSync}from'node:fs';import{join}from'node:path';
const banned=/\.(mp3|wav|ogg|m4a|aac|flac|opus|mid|webm)$/i;
function walk(dir){for(const e of readdirSync(dir,{withFileTypes:true})){if(e.name==='node_modules'||e.name==='dist')continue;const p=join(dir,e.name);if(e.isDirectory())walk(p);else{if(banned.test(p))throw Error('Forbidden audio: '+p);if(/\.(ts|js|mjs|json|html|md)$/.test(p)){const c=readFileSync(p,'utf8');if(/(?:BEGIN (?:RSA |OPENSSH )?PRIVATE KEY|sk-[a-zA-Z0-9]{30})/.test(c))throw Error('Possible secret in '+p);}}}}
walk('core');walk('games');console.log('Hygiene checks passed');
