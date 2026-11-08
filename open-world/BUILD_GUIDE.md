# HQ greybox build guide

This is the first playable slice of a future open-world game. It is a greybox, not a city, a mission set, or a replacement for the Punk Arcade. Godot 4 is the provisional tool. The final engine and the shipping platform are still open.

The Punk Arcade remains the Canvas project under `arcade/`. Its last shared core observed for this work is commit `fbad19f0369b4d3cf060d4178de0933a513303d3`, which is an ancestor of `main`. Nothing in that tree was rewritten.

## 1. Godot version and quickstart

Verified editor, on Linux x86_64:

- Godot **4.7.2-stable** (`4.7.2.stable.official.ed1daf0bf`)
- Editor archive `Godot_v4.7.2-stable_linux.x86_64.zip`
- SHA-512 `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65`
- Export templates `Godot_v4.7.2-stable_export_templates.tpz` (a zip archive despite the extension)
- Templates SHA-512 `ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079`
- Release: https://github.com/godotengine/godot/releases/tag/4.7.2-stable

Install the templates where this editor looks for them:

```text
~/.local/share/godot/export_templates/4.7.2.stable/
```

The web template used is `web_nothreads_release.zip`. Project renderer is `gl_compatibility` for both desktop and mobile feature tags. That is a feasibility choice for modest GPUs and for a browser export. It is not a promise that every OS, browser, or store build already works.

```bash
godot --path open-world
godot --headless --path open-world res://tests/test_main.tscn
```

From `open-world/` after `npm ci` in both `arcade/` and `open-world/`:

```bash
export GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64
node tools/export-web.mjs
node tools/stage-composite.mjs
PORT=8090 node tools/serve-composite.mjs
# other shell
AU_BROWSER_OUT=/tmp/hq-browser node tools/browser-check.mjs
```

`export-web.mjs` writes `node_modules/.gdignore` and `build/.gdignore` before Godot runs, so the editor does not import Playwright or the previous export into the pack. The checked pack after that step was **63,692 bytes**. The engine wasm beside it was **39,514,754 bytes**.

## 2. Verified in this pass, and what is only planned

Verified here, on this Linux machine, with Godot 4.7.2:

| Check | Result |
|---|---|
| Headless suite `res://tests/test_main.tscn` | `SUMMARY failed=0`, **125** `ok` lines, exit 0 |
| Keyboard mapping | Synthetic `InputEventKey` for W pressed and released `move_forward` |
| Gamepad mapping | Synthetic axis `0.1` did not press `move_right`; axis `1.0` did; button A pressed `jump` |
| Movement | Skate forward, jump leaves and returns to the floor, a wall stops the body |
| Ramp | Wedge ramp, max feet height about 1.20 m while still on the floor |
| Grind | Airborne approach attaches, travels, jump detaches; skating on the ground under the rail does not attach |
| Yard | 160 m block: one south gate, bowl, half-pipe, quarter, rail, warehouse arcade, workshop, resistance rooms. Headless `SUMMARY failed=0` |
| Cabinet | Placeholder session pauses world sim and input, holds the single audio owner, finish/abort restores them, 10 re-entries do not stick |
| Save | `user://au-open-world-save-v1.json` reloaded with 11 results |
| Catalog | Both placeholders disabled; enabling one without cleared external media is rejected; no playback |
| Desktop frames | Compatibility, llvmpipe, OpenGL 4.5, 1280×720. Gameplay camera in the skate yard, plus a higher view across the bowl toward the warehouse and cool towers. No ALSA device, so the dummy audio driver |
| Web export | Single-threaded. Pack 74,664 bytes after the yard. Wasm still 39,514,754 bytes |
| Browser play | Headless Chrome, SwiftShader, WebGL 2 Compatibility. From the skate-yard spawn, W moved the player about 4.82 m. Zone stayed `SKATE YARD` |
| Composite tree | 157 arcade files unchanged by hash; 7 files added only under `open-world/` |

Not verified, and not claimed:

- A physical keyboard beyond the browser `KeyW` hold and the synthetic key events
- A physical gamepad, touch screen, or mobile browser
- macOS, Windows, Android, iOS, or a store package
- Frame rate, battery, memory budgets, or load time on any named device
- Real Canvas arcade integration inside the cabinet
- Music, because no cleared media is in this repo and this machine had no audio device
- A live GitHub Pages URL for `/open-world/` (see section 11)

The desktop screenshot is a real viewport grab of `scenes/main.tscn`. The browser screenshot is the exported game after the keyboard move. Chrome also requested a missing favicon and logged one 404. `index.html` only references `index.js` and `index.png`, and both files are in the export. The game still booted.

## 3. Art direction

Confirmed inspiration, not an asset license: cyberpunk streets, Grand Theft Auto as a traversal fantasy, and Jet Set Radio as skating and bold street presentation. Those names describe the target feeling. They are not permission to copy maps, costumes, logos, UI, music, or recognizable silhouettes.

Working visual proposal:

- Bold cel-shaded silhouettes and original graffiti
- Streets and obstacles readable at skate speed
- An original Algorithmic Uprising identity
- A warm, improvised resistance HQ against a cold corporate surveillance city

The liked sunset painting is direction for color and shape, not a measured plan and not a texture in the game. The layout source is `design/hq_yard_map_v1.svg` (concept v1, proposed). Godot ignores that folder so the diagram is not packed into the game.

This yard is built from meshes. `shaders/cel_block.gdshader` steps the Compatibility renderer into three light bands, darkens grazing edges a little, and lets the directional shadow map cut hard shadows. It is not an ink outline and not the painted concept. The key light is warm and about 42° above the horizon so the ground stays in a lit band. The sky is a procedural sunset. Cool blocks outside the east wall are the future shopping skyline. They have no collision and no gate.

What is still drawn with placeholders is listed in [ASSET_MANIFEST.md](ASSET_MANIFEST.md). Striped quads labeled TEMP TAG are temporary geometry, not graffiti art. Zero, Fony, and the protagonist are still capsules.

### Yard size, and where gameplay changed the diagram

Wall centers sit on a **160 m** square (`scripts/yard.gd`, `HALF = 80`). The diagram proposed 200 m. That size is not approved. 160 m is still a city block, and at 9 m/s the loop stays readable. The only playable hole in the HQ wall is the south gate, x = 46 m to 58 m. North, east, and west walls are solid. Rust Avenue is a short apron outside that gate, then a curb labeled FUTURE SECTIONS. Neighbor sections are scenery only.

| Diagram | Built |
|---|---|
| 200 m square | 160 m between wall centers |
| Drainage bowl, banks about 3 m | Floor at y = −3 m, four straight bank plates |
| Mini half-pipe, 2 m | Two facing slopes, crest 2.0 m |
| Quarter about 2 m | Slope crest 2.2 m |
| Flat rail | 12 m straight rail, y = 1.05 m, same grind rules as before |
| Funbox, height not fixed | 0.9 m so the current jump, about 1.1 m, can land on it |
| Loading docks +1.2 m | 1.2 m decks plus a ride-up slope, because the jump does not clear 1.2 m by itself |
| Roof stair | One slope to the solar roof, about 9.1 m, on the east side of the warehouse |
| Fony at the old arcade door | Fony and Zero stand in the resistance rooms. The cabinet stays in the warehouse |
| Smooth concrete, plants, murals | Patches, box planters, and TEMP TAG stripes |

The bowl is angular plates around a sunken floor, not a smooth concrete bowl. Some bank edges overlap the yard slabs. That is visible in the high shot.

Fony is the player: an articulated block rig in copper, rust, black, olive, and magenta, with the board under the feet while skating. The physics body is still a capsule, so the mesh does not catch on rails or doors. Zero, in the resistance rooms, is a separate CRT-headed rig with a lime screen and a talk pose. Both are described in [ASSET_MANIFEST.md](ASSET_MANIFEST.md). Headless checks include skate, jump, land, respawn if y drops below −8 m, Zero’s talk pose, and the cabinet handoff. On this machine that suite ended `SUMMARY failed=0` with 144 `ok` lines.

## 4. Module and scene map

District geometry is built in code by `scripts/hq_main.gd` so collisions stay in versioned source. Interactables are scenes.

| Path | Role |
|---|---|
| `scenes/main.tscn` | Boots the district, HUD, pause, and dialogue |
| `scenes/player.tscn` | Third-person body, board, spring-arm camera |
| `scenes/npc.tscn` | Zero and Fony placeholders |
| `scenes/cabinet.tscn` | Arcade cabinet |
| `scenes/grind_rail.tscn` | Straight rail, no collision mesh |
| `scenes/session_overlay.tscn` | Placeholder cabinet UI |
| `scripts/player_controller.gd` | Walk, skate, jump, camera, grind |
| `scripts/hq_flow.gd` | Dialogue, pause, session handoff, save |
| `scripts/yard.gd` | 160 m yard: walls, bowl, warehouse, rooms, skate obstacles |
| `scripts/world_blocks.gd` | Cel boxes, labels, slope banks |
| `shaders/cel_block.gdshader` | Three-band Compatibility lighting |
| `design/hq_yard_map_v1.svg` | Proposed layout diagram. Not packed |
| `ASSET_MANIFEST.md` | What is modeled, and what original art is still missing |
| `audio/audio_owner.gd` | The only audio owner. It does not play |
| `contracts/session_boundary.gd` | World versus session focus. No renderer types |
| `contracts/minigame_result.gd` | `au.minigame_result` v1 |
| `contracts/song_catalog.gd` | `au.song_catalog` v1 |
| `contracts/save_record.gd` | `au.world_save` v1 |
| `data/story_working.json` | Provisional plot and spoken lines |
| `data/song_catalog.json` | Disabled catalog placeholders |
| `tests/test_main.tscn` | Headless checks |
| `tools/export-web.mjs` | Single-threaded web export |
| `tools/stage-composite.mjs` | Arcade staging output plus `/open-world/` |
| `tools/browser-check.mjs` | Local Chrome check of that tree |

`scripts/player_controller.gd` has test seams (`external_move`, `external_jump`). They do nothing unless a test sets them.

Web exports publish `window.AU_HQ` with position, zone, skate state, session, and input ownership so a browser check can see the simulation. Desktop builds do not eval that script.

## 5. Working plot, and optional suggestions

Working plot, provisional. Names and the opening are not final. `data/story_working.json` is the copy the game speaks from.

- The tone is hopeful. Zero leads an underground resistance that includes AI members. Zero and Fony cooperate to promise and build a better future.
- The protagonist is a teen forcibly orphaned by a corrupt system, fleeing drones, rescued by the resistance, and able to become a hero. Name and appearance are null. The exact orphaning and the opening sequence are not written. `graphic_trauma_scene` is false, and the spoken lines do not stage one.
- The world is crony capitalism and tyranny: AI drones, surveillance, militarized police, massive data-center compounds, and the fictional trillionaire Egon Dusk.
- Future fictional sabotage, including in-fiction drone or virus actions, would be game mechanics only. They are not in this pass and they are not real cyber tools.
- The playable place is one connected HQ: skate park, arcade, and the shopping-district edge. It is not a city.

Optional suggestions, not in this build and not canon just because they are listed: an opening sequence, a protagonist design, an extra singer if someone later confirms and clears one, more neighborhoods, a real Bars per Watt cabinet, cel shading and original graffiti, tricks beyond one straight rail, and touch controls if a mobile target is chosen.

Spoken lines now:

- Zero: "You got here. That is enough for tonight. The park is a promise we keep with our own hands." Then Fony and the cabinet are a training shell, and the future is the part they build.
- Fony: "Zero holds the line. I hold the door. We are on the same promise." Then the warm park versus the cold shops, which are the edge of someone else's city.

## 6. Input and how to test

Keyboard, checked with synthetic events and with one browser hold of W:

- WASD or arrows: move, camera-relative
- Space: jump
- Shift: toggle skate and walk. The slice starts on the board
- E: talk or use the cabinet
- Q and E: yaw. R and F: pitch
- Enter: advance dialogue, finish the placeholder session, or resume
- Backspace or Esc during a session: leave the session
- Esc in the world: pause

Gamepad mapping, checked with synthetic events only. No physical pad was attached:

- Left stick: move. Right stick: camera. Deadzone 0.25
- A: jump, and confirm while a session is open
- B: leave the session
- X: interact
- Y: skate toggle
- Start: pause

Mouse and touch are not control modes. Do not describe them as supported.

The cabinet is a placeholder. Finish or Leave returns world input, unpauses `WorldSim`, and gives the audio owner back to the world. The result field `integration` is `placeholder_not_canvas`. This is not the Punk Arcade Canvas runtime and not Bars per Watt.

## 7. Browser, desktop, and mobile

Open:

- Desktop native Godot is the path used for the headless suite and the llvmpipe frame.
- Web is exported and was loaded locally. GitHub Pages would serve it as static files if the production artifact is updated. See section 11. That has not happened.
- Native mobile and any store are undecided. There is no touch UI and no export preset besides Web.
- This pass does not promise Windows, macOS, Android, iOS, or every browser. The browser evidence is one headless Chrome run with SwiftShader.

The web preset sets `variant/thread_support=false`. The generated page sets `GODOT_THREADS_ENABLED` to false, so it does not require `SharedArrayBuffer` or cross-origin isolation headers. GitHub Pages does not send those headers. A threaded export would be the wrong build for that host. Asset URLs in `index.html` are relative (`index.js`, `index.png`), which is what a `/open-world/` subpath needs. The engine wasm is still about 38 MiB before transfer compression. That size is the Godot web template, not the greybox.

## 8. Media, memory, and lazy load

One audio owner, the `AudioOwner` autoload. It does not create a music bus. The headless check expects `AudioServer.bus_count == 1`. Playback always returns `played: false` with reason `disabled`. No audio files are in this project. The catalog scan rejects recordings, Drive links, and private-key shaped strings.

Catalog policy, in `data/song_catalog.json`:

- Music is Zero's AU catalog only
- World use is originals, once a cleared playable copy exists outside this repo
- Arcade use is a relevant-song MIDI or Sega-era arrangement
- A changed arrangement needs its own Bars per Watt chart
- An extra singer is unconfirmed
- No recordings, masters, samples, covers, secrets, private paths, or Drive IDs in the public repo
- No AI processing of music, and no paid or generated audio

The two song entries are untitled placeholders. They are not a claim that those tracks exist under those titles.

Lazy load, now: `request_playback` reads metadata already in the JSON and refuses to fetch. There is one small district in memory. Nothing streams.

Lazy load, proposed and not measured: resolve one catalog row at a time, fetch only a cleared external file for the selected song, cancel the previous fetch, and do not keep four decoded songs. A four-minute 48 kHz stereo buffer is about 87.9 MiB of PCM; that figure is arithmetic from the earlier Bars per Watt note, not a measurement of this slice. Neighborhoods later should be separate scenes loaded at the boundary and unloaded when left. The cabinet must not keep the district simulating behind a real minigame.

This machine's desktop run had no audio device. That does not say anything about mix latency.

## 9. Minigame contracts

Current Punk Arcade contract, read at `fbad19f` and still the code on `main`. It was not modified:

- `GameAPI`: `start`, `update(dt)`, `draw(CanvasRenderingContext2D)`, `input(key, down)`, `score`, `over`
- Optional: `setSkin`, `setMoveAxis`, `setPositionTarget`, `releaseInput`, `result()`, `presentation`, `dispose`
- `result()` is an untyped record. The shell owns the canvas, the animation frame, focus, and one oscillator `AudioContext` for cues
- Storage is string keys. There is no world adapter

Proposed contracts implemented here as plain data, not wired to that canvas shell:

- `au.minigame_result` v1. Required: contract, version, session id, game id, game version, exactly one of `completed` or `aborted`, `input_mode` of `keyboard`, `gamepad`, `unknown`, or `mixed`, and an integer score. Optional rhythm fields may be empty. Node, viewport, texture, canvas, and audio-context fields are rejected. `input_mode: "mouse"` is rejected.
- `au.song_catalog` v1. Metadata only until `enabled` is true and `media.cleared` plus `media.delivery == "external"` are both set, with no path or Drive locator.
- `au.world_save` v1. Local meetings and at most 20 results. No renderer field.
- `SessionBoundary` tracks phase `world` or `in_session`, who owns input, and who holds audio focus. Entering refuses a second session. Exiting requires a valid result with the same session id.

A future adapter can translate a real cartridge result into `au.minigame_result` without giving the minigame a 3D node. That adapter is not in this pass. On enter, the world sim is `PROCESS_MODE_DISABLED` and input is taken. On finish or abort, both come back. The placeholder result uses game id `hq.placeholder_cabinet` and version `0.1.0-greybox`.

## 10. Milestones against this pass

| Target | This pass |
|---|---|
| Separate top-level project on its own branch, arcade and website source left as they are | Met |
| Runnable HQ slice: third person, skate and walk, jump, ramp, camera, collisions, three readable zones | Met, with the checks in section 2 |
| Zero and Fony placeholders | Met |
| Cabinet enters a placeholder and returns focus | Met. Not the real arcade runtime |
| Straight grind, only if it stayed stable | Met for one straight rail. No tricks |
| Renderer-independent session, catalog, result, and save | Met as data contracts |
| One audio owner, catalog disabled until cleared media exists | Met |
| No music files, no paid or generated art, no final avatar | Met |
| Browser export actually loaded | Met locally, single-threaded, Chrome |
| Live Pages URL that keeps the arcade and adds `/open-world/` | Already true on `main` for the first greybox. This visual branch must not be merged until the yard pictures are approved, because a merge publishes it. Section 11 |
| Full city, missions, networking, real Bars per Watt | Out of scope |

## 11. GitHub Pages

The first greybox is already on the live site from the merge of pull request 6. This visual branch changes `open-world/**`. The existing `deploy-main` job runs for those paths on `main` and would replace the live HQ. Do not merge this branch until the in-engine pictures are accepted. Opening the pull request does not deploy.

## 11b. How the combined site is published

The repository already has one GitHub Pages site. Inspected with the Pages API and with HTTP:

- `build_type`: `workflow`
- Environment: `github-pages`
- Custom domain: none
- Public URL: https://algorithmicuprising.github.io/AlgorithmicUprising/
- `GET /` and `GET /demo/` returned 200 on 8 Nov 2026. `Last-Modified` was Sat, 07 Nov 2026 18:29:32 GMT
- `GET /open-world/` returned **404** at that same check
- The live root still redirects to `./demo/`, which is the Punk Arcade landing

There is still one Pages site and one deploy job: `deploy-main` in `.github/workflows/arcade.yml`. It runs only when the ref is `refs/heads/main` and the event is not a pull request. A pull request does not publish. `workflow_dispatch` publishes only if it is started on `main`.

The workflow now also runs for changes under `open-world/**`. Every main deploy still builds and stages the arcade, then installs Godot from `GODOT_VERSION.txt` (SHA-512 checked by `tools/install-godot.sh`), runs the headless suite, exports the single-threaded web build, and runs `node tools/stage-composite.mjs --into-staged`. That copies the export to `arcade/.pages/open-world/` and fails the job if any pre-existing arcade file changes or if a new file lands outside that directory. The uploaded path is still `arcade/.pages`, so the arcade root, `demo/`, and `games/` stay the staged arcade output. An arcade-only push to `main` rebuilds the HQ as well, so a later arcade deploy cannot drop `/open-world/`.

`deploy-main` still waits for `build-and-browser-test`. A failing arcade check blocks the upload. A failing Godot headless run or a bad export also stops the job before `actions/upload-pages-artifact` and `actions/deploy-pages`. The `github-pages` environment, the Actions source, and the absence of a custom domain are unchanged.

Checked locally after `npm run stage-pages` and `--into-staged`, including a second attach:

- 157 arcade files, zero hash changes, zero deletions
- 7 files added, all under `open-world/`
- `index.html` at the site root still redirects to `./demo/`
- Required arcade paths still present, including Grind, Tag, and Cookie Wall bundles and `games/cookie-wall/demo/page.js`
- `open-world/index.html` has `GODOT_THREADS_ENABLED` false, `src="index.js"`, and no `<base>` tag
- wasm 39,514,754 bytes, pack 63,692 bytes

GitHub Pages serves `.wasm` as `application/wasm` from its static MIME map. This repo cannot add cross-origin isolation headers. The single-threaded export is the build that can run there. The local composite server and headless Chrome check in section 2 already confirmed that MIME and that the page boots from a subpath.

`.github/workflows/open-world-pages-composite.yml` still does not deploy. It repeats the pinned install, headless suite, export, and composite staging on pull request so the export is visible before merge. Its permissions remain `contents: read`.

The live site from pull request 6 is already:

- Arcade: https://algorithmicuprising.github.io/AlgorithmicUprising/ and https://algorithmicuprising.github.io/AlgorithmicUprising/demo/
- First greybox HQ: https://algorithmicuprising.github.io/AlgorithmicUprising/open-world/

Merging this visual branch would replace that HQ with the 160 m yard. Leave the pull request unmerged until the pictures are approved.

## 12. Limitations

- The protagonist is an unnamed capsule. Zero and Fony are colored capsules with labels. See `ASSET_MANIFEST.md`.
- The cel shader is three light bands plus a little edge darkening. It is not an ink contour and not the painted concept. Shadows are one directional map. On llvmpipe they are visible and not a measured sharpness.
- The bowl is four flat banks around a floor at −3 m. The plates overlap the yard and do not form a smooth concrete bowl.
- One straight grind rail. Leaving the end shoves the body forward. There is no grind trick.
- The cabinet does not load Grind, Tag, Cookie Wall, or Bars per Watt.
- No networking, no missions, no second neighborhood.
- No performance numbers. LlvmPipe and SwiftShader were used because that is what this machine offered. They are not a target device.
- Web audio worklet files are in the export because the Godot template emits them. This project never starts a song.
- Save data is a local JSON file in Godot's `user://` directory. It is not cloud sync.
