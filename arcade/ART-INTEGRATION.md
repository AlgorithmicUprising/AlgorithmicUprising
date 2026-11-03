# Incoming artwork — integration handoff

**Status:** zero artwork incorporated. The procedural greyboxes remain usable while production art is created.

Deliver **separately for each game** in `games/<game>/skins/fony/` and `games/<game>/skins/au/`. Each skin has its own `skin.json`. Keep source/vector files with the corresponding skin; don't modify game rules to swap visual assets.

## Asset contract

- Original uncompressed transparent PNG or SVG sprites plus editable source if available. Sprite frame names use `entity_animation_00`, `entity_animation_01`, etc. Prefer consistent fixed-cell grids, 1× native pixels and explicit frame sizes.
- Side-view skater and Terms of Service plates go in **Grind**; overhead skater, alley, 4 drone silhouettes, wall tiles, paint cans, tag art go in **Tag**.
- Sprite frames must include sane anchors, hitboxes, and no baked-in branding for the open Fony pack.
- AU logos, Zero-related graphics, Ø graffiti and branded advertising overlays belong **only** in the `au/` skin, licensed all rights reserved.
- No generated Zero face; no music, lyrics, recordings, remote tracking or private credentials.
- Record imagery source, usage rights, pixel dimensions, artist notes and approved variations in each skin README.

## When files arrive

1. Copy incoming art into the relevant game skin directory, do not overwrite placeholders or game code.
2. Map asset paths in `skin.json` under `sheets` or `files`; name sprite frames and add animation descriptions.
3. Run `npm run validate`, `npm run check`, and `npm test`.
4. Wire the asset loader + animation map. **This remains unimplemented** in the initial M0 scaffold; updating `skin.json` alone does not yet change the visible shapes.
5. Inspect 16:9 and 9:16 demos, colorblind contrast, reduced motion and 60 FPS mobile before marking M2 complete.

## Important scope note

The first commit provides M0 gameplay scaffolding only. The game's final sprite template generation, runtime skin loader, animation pipeline, and full 4-drone mechanics remain scheduled implementation work. Do not represent the art integration as complete until the resulting skin can be selected without code changes.
