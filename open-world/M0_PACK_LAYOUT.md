# M0: pack layout, near-lossless Fony, district packs (Nov 18 2026)

Project Zero Act I, milestone M0. Local branch `pz-m0-pack-space`, based on `main` at 3101ed94. Preview only: nothing here is merged, pushed or deployed.

## Decisions this is built to

- The main pack budget went from 16 MiB to **50 MiB** (`MAIN_PACK_MAX` in `tools/stage-composite.mjs`). The user chose this over shrinking Fony.
- Fony's atlases import **near-lossless**: lossy WebP at **q0.97** (live was q0.75). The first M0 commit used full lossless; the user then chose near-lossless to keep the main pack around 25 MiB or less.
- Districts ship as **separate packs** that load on demand while the player keeps skating.
- The whole game is skateable. Loading a district must never stop Fony or change his speed or state.
- Milestones stay on preview builds.

## Sizes

| | Before (live, main 3101ed94) | M0 commit 1 (lossless) | **This branch (q0.97)** |
|---|---|---|---|
| `index.pck` | 15,684,864 bytes (14.96 MiB) | 42,427,096 bytes (40.46 MiB) | **22,633,704 bytes (21.59 MiB)** |
| `index.pck` gzip transfer (GitHub Pages serves `.pck` gzipped) | 14,860,200 bytes (14.17 MiB), measured from the live site | about 41,630,825 bytes (39.70 MiB) | **21,811,342 bytes (20.80 MiB)**, gzip level 6 measured locally (brotli about 21,780,289) |
| Fony atlases inside the pack | 13,402,006 bytes (WebP q0.75) | 40,100,784 bytes (lossless WebP) | 20,307,356 bytes (WebP q0.97) |
| Headroom under the budget | 1.04 MiB under 16 MiB | 9.54 MiB under 50 MiB | 28.41 MiB under 50 MiB |
| `districts/test_district.pck` | n/a | 8,580 bytes | 8,580 bytes (6,682 gzip). Its budget is 1 MiB |
| `index.wasm` | 39,514,754 bytes | unchanged | unchanged |

q0.95 was also exported and measured: 21,195,832 bytes (20.21 MiB), gzip 20,373,788 bytes (19.43 MiB). WebP data barely compresses, so the gzip transfer is close to the raw size. The first visit to the HQ downloads about 1.45x the pack data it did before. GPU memory doesn't change: the atlases were already uncompressed RGBA8 on the GPU (`vram_texture: false`).

`node tools/pack-report.mjs build/web/index.pck` prints the bytes per folder, the largest files and the gzip size. `stage-composite.mjs` prints the same budget block in CI.

## What changed for Fony's art

- All 7 `assets/library/fony2d/*.png.import` files now use `compress/mode=1` (lossy WebP), `compress/lossy_quality=0.97` and `detect_3d/compress_to=0`. That last setting stops the editor from switching them to VRAM compression on its own.
- `project.godot` sets `rendering/textures/webp_compression/compression_method=6` (slowest, best encoder effort; import takes about 80 s) and `lossless_compression_factor=100` (only used if an atlas goes back to lossless).
- The source PNGs and the atlas scale (0.35 of the 510x648 masters) are unchanged. Error against the source PNG, front atlas, pixels with alpha of at least 50%:

  | Setting | PSNR | Max error (8-bit) | Fony atlases in pack |
  |---|---|---|---|
  | live q0.75 | 30.2 dB | 78 | 13.4 MB |
  | q0.95 | 33.41 dB | 61 | 18.9 MB |
  | **q0.97 (chosen)** | **33.57 dB** | **59** | 20.3 MB |
  | lossless (M0 commit 1) | exact | 0 | 40.1 MB |

- **Why q0.97.** At 2x zoom, q0.95 showed slight softening on the face and jacket: a warm halo under the chin and at the hood edge, and blurred jacket creases and patch detail. q0.97 is the best quality within the about 25 MiB target. It's marginally cleaner but looks almost the same. The remaining softening most likely comes from the lossy WebP format's half-resolution colour (4:2:0 chroma subsampling), so raising the quality further would barely help. Only lossless removes it. In the game view at normal distance, none of this is noticeable.
- Comparison image (outside the repo): `/workspace/pz-m0-evidence/fony_q_compare_2x.png`, with live q0.75, lossless and q0.97 side by side at 2x. The q0.75 panel comes from the live build's capture, so Fony sits slightly differently in the frame.
- Higher-resolution frames: `art-src/` has no higher-resolution puppet-v1 frames, only older v2, v3 and raw sets. The 510x648 and 800x850 masters live outside the repo, on the box (`/workspace/hq-map/fony-2d-sprites/puppet-v1`, `/workspace/fony-*/work/masters`). Lossless at a larger scale doesn't fit the budget: 0.5 scale would be about 78 MiB of atlases (estimated from the area ratio). See "Needs a decision" below.
- `tools/rebake_fony_web_atlases.py` writes lossy q0.97 imports by default (`AU_IMPORT_MODE=1`, `AU_WEBP_Q=0.97`). Set `AU_IMPORT_MODE=0` for lossless.
- Evidence is in `tests/capture_m0_fony.gd`. It saves a gameplay shot and a long-lens close-up, and prints the atlas error.

## Pack layout

```
build/web/
  index.html, index.js, index.wasm         engine (unchanged)
  index.pck                                main pack: HQ, Fony, UI, loading cards, district registry (budget 50 MiB)
  districts/<id>.pck                       one pack per district (budget per district in data/districts.json, capped at 8 MiB)
  GODOT_COPYRIGHT.txt, zero_x_zero.webp    Zero X shell and Godot attribution (unchanged)
```

- The main export preset (`Web`) excludes `districts/*`, plus `tests/*`, `design/*`, `build/*` and `node_modules/*` as before. `art-src/` and `design/` carry `.gdignore`, so they were never in the pack.
- Each district has its own preset named `District <id>`. It uses `export_filter="resources"` with the district scene as its only file, so Godot pulls in that scene's dependencies. `tools/export-web.mjs` runs `--export-pack "District <id>" build/web/districts/<id>.pck` for every entry in `data/districts.json`.
- `tools/stage-composite.mjs` fails the build if any of these are true:
  - the main pack is over 50 MiB;
  - a registered district pack is missing or over its budget;
  - an unregistered district pack is present;
  - `districts/`, `art-src/`, `design/` or `tests/` show up in the main pack.
- The publish workflow (`arcade.yml`) already runs `export-web.mjs` and `stage-composite.mjs --into-staged`. District packs are staged next to `index.pck` with no workflow change.

## How a district loads (`scripts/district_loader.gd`)

1. **Arm.** M0 arms a district only with `?district=<id>` on the web, `-- district=<id>` on the desktop, or `"free_roam": true` in the registry. The test district is `false`, so free roam and the HQ behave exactly as before. Arming puts down a plain stand-in floor (the "apron") from the main pack over the district footprint, with low walls on the far sides, and loads the player's exploration stats from the save.
2. **Approach.** Within `prefetch_m` of the district bounds (30 m for the test district), the loading card for visit N = visits + 1 shows, and the fetch starts.
3. **Fetch.** On the web, `HTTPRequest` fetches `<page dir>/districts/<id>.pck`, resolved with `document.baseURI`, so it works under `/open-world/`. The body is written to `user://district_cache/<id>.pck`. On the desktop or in tests, a local `<dir>/<id>.pck` is used: `AU_DISTRICT_DIR`, `res://build/web/districts`, or `<exe dir>/districts`. When run from source with no built pack, the scene loads straight from `res://`.
4. **Mount.** The loader checks the file's `GDPC` header, then calls `ProjectSettings.load_resource_pack(path, false)`. `replace_files=false` means the main pack always wins for shared files.
5. **Instance.** `ResourceLoader.load_threaded_request` loads the scene, which is instanced at the registry `origin` under WorldSim. The apron is then removed.
6. **Enter.** Crossing into the bounds records the visit (`visits`, `first_visit_unix`, `last_visit_unix`) and saves. The HUD zone reads the district's `zone`.
7. **Fail.** On a network error, a missing file, a bad header or a missing scene, the card shows "NO SIGNAL · <TITLE> DID NOT LOAD · KEEP SKATING". The apron stays, so the player can keep skating, and the next approach retries after 8 s.

Nothing in the loader pauses the tree, takes input, or touches the player's velocity or state. In the headless test, Fony pushes east down Rust Avenue at 9.0 m/s, crosses the edge while the pack mounts, and stays at 9.0 m/s, skating, with input on. In headless Chrome with SwiftShader, with the pack held back 2.5 s, his body speed stayed at 9.0 m/s across the edge with no stalled frames. The aborted-fetch case behaved the same way.

The browser and capture demo is `?district=test_district&district_demo=1`. It puts Fony at the west end of Rust Avenue, pushing east.

### The test district (`districts/test_district/`)

This is a small skateable space past the east end of Rust Avenue (world x 70 to 134, z 78 to 102). It has a flat run-in with lane paint, a 0.30 m ledge with a grindable metal edge, a flat bar, a bank with a deck and a back slope, low side walls and an end wall. It's built in code from main-pack pieces (`world_blocks`, `park_pieces`, `grind_rail.tscn`), so the pack is 8.6 KB.

### Adding a district

1. Make a folder `districts/<id>/` with a scene. Its local frame starts at the edge, at x = 0.
2. Add an entry to `data/districts.json` with these fields: `title`, `zone`, `pack`, `scene`, `budget_bytes`, `cards`, `origin`, `bounds`, `apron`, `prefetch_m` and `free_roam`.
3. Copy the `[preset.1]` block in `export_presets.cfg` as `District <id>`, with the scene in `export_files`.
4. Add a card file in `data/loading_cards/<id>.json`, with any card art under `assets/loading_cards/<id>/`. Card art lives in the main pack so it can show before the district arrives.

## Loading cards (`scripts/loading_cards.gd`, `scripts/loading_card_view.gd`)

The loading card sits in the lower left and never takes input. It has art, a title, body text, an optional portrait with a name, a thin progress bar and a status line. Its contents are data-driven, so writers and artists can add cards without touching code.

Card file format (`data/loading_cards/<district>.json`):

```json
{
  "contract": "au.loading_cards", "version": 1, "district": "test_district",
  "min_seconds": 4.0,
  "tiers": [
    {"id": "intro",   "from_visit": 1, "to_visit": 1, "pick": "first",  "cards": [CARD]},
    {"id": "faction", "from_visit": 2, "to_visit": 2, "pick": "first",  "cards": [CARD]},
    {"id": "tips",    "from_visit": 3,                "pick": "rotate", "cards": [CARD, CARD]}
  ]
}
CARD = {"id": "...", "title": "...", "body": "...",
        "art": "res://assets/loading_cards/<id>/x.png",   optional
        "portrait": "res://...png", "portrait_name": "...", optional
        "accent": "#e2ff5c"}                               optional
```

- **Tier matching.** A tier matches visit N when `from_visit <= N <= to_visit`. An omitted `to_visit` means there's no upper end. The first matching tier wins.
- **Pick modes.** `first` always shows the first card. `rotate` shows `cards[(N - from_visit) % count]`. `random` picks one, the same one for a given visit.
- **Fallbacks.** With no file or no matching tier, the card shows the district title only.
- **Timing.** `min_seconds` keeps the card up for at least that long. After that, it closes once the district is ready or has failed.
- **Test district.** It has placeholder cards: visit 1 is the intro art, visit 2 is the faction card with a portrait, and visit 3 onward rotates a ledge tip and a bank shortcut. All of that art is placeholder.

## Save: exploration stats

- **Where it's stored.** The `au.world_save` record (`contracts/save_record.gd`, file `user://au-open-world-save-v1.json`) has a new optional top-level key, `exploration`. The visit count is at `exploration.districts.<district id>.visits`.

  ```json
  "exploration": {
    "version": 1,
    "districts": {
      "test_district": {
        "visits": 2,
        "first_visit_unix": 1795060000,
        "last_visit_unix": 1795060420,
        "discovered": {"shortcuts": ["bank_gap"], "secrets": []}
      }
    }
  }
  ```

- **Old and new saves.** It's optional both ways. Saves written before M0, with no `exploration` key, still load, and older builds ignore the key. `contract_version` stays at 1.
- **Discovered items.** `discovered` holds string-id sets. Today these are `shortcuts` and `secrets`, both empty until something marks them. `save.discover(district, kind, id)` adds a new kind on first use and returns true only the first time.
- **Who reads it.** It's kept for a future achievements and bonuses system, which isn't built. The free-roam flow still writes the save but doesn't read it at start, which is unchanged. The district loader merges only `exploration` from disk (`load_exploration_user`) before it counts a visit.

## Tests and checks

- `tests/test_main.gd` gains `_m0_packs()`. On its own it runs with `AU_TEST_ONLY=m0`. It covers:
  - the q0.97 import settings on all 7 atlases, and the imported air atlas staying at 32 dB PSNR or better against its source (it measures 32.8 dB);
  - card validation and tier picks;
  - exploration save round trips, old saves and broken blocks;
  - the registry and export presets;
  - free roam unchanged;
  - a failed pack, with Fony rolling on;
  - a real pack when `build/web/districts` exists: skating across at full speed, the visit recorded, and visit 2 showing the faction card.
- `tools/district-check.mjs` (`npm run district-check`) is the browser smoke test. It runs the delayed-pack, aborted-pack and plain cases and saves screenshots.
- In CI, `test_main` runs before the export, so it takes the "from res://" path. The pack path is covered by the browser check and by local runs after `export-web`.

## Needs a decision

- **Download size versus sharpness.** Decided: near-lossless q0.97. The first HQ load is about 21 MiB over gzip (lossless would be about 40 MiB; live is 14 MiB). If the slight chroma softening ever matters, the options are lossless (about 40 MiB) or lossless for the front atlas only. A higher atlas scale at q0.97 would be about 2x the atlas bytes for 0.5 scale (estimated).
- **District entry in free roam.** The test district only arms with the flag. When the first real district lands, choose where its edge goes and set `free_roam` to true.
