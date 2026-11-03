import {readFileSync} from 'node:fs';
import {gzipSync} from 'node:zlib';
for(const id of ['grind-the-terms','tag-before-training']){const size=gzipSync(readFileSync(`games/${id}/dist/${id}.js`)).length;console.log(id,size,'gzip bytes'); if(size>61440)process.exitCode=1;}
