import { games } from '../tools/games.mjs';
import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
test('games expose distinct Web Components',()=>{for(const id of games)assert.match(readFileSync(`games/${id}/src/index.ts`,'utf8'),new RegExp(`defineArcade\\('${id}'`))});
test('starter skins remain procedural',()=>{for(const id of games)assert.equal(JSON.parse(readFileSync(`games/${id}/skins/placeholder/skin.json`,'utf8')).procedural,true)});
