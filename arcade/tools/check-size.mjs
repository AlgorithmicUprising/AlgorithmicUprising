import { games } from './games.mjs';
import {readFileSync} from 'node:fs';
import {gzipSync} from 'node:zlib';
for(const id of games){const size=gzipSync(readFileSync(`games/${id}/dist/${id}.js`)).length;console.log(id,size,'gzip bytes'); if(size>61440)process.exitCode=1;}
