# Front end: start menu, Act I intro video, saves and accounts

Nov 19 2026, branch `pz-m1-practice-run`, then `pz-act1` (local only, not pushed or deployed). Act I story notes: `ACT1.md`.

## Flow

Boot (Zero X Game Engine fine print) → **start screen** (the puppeteer art, option C, approved Nov 15 2026) → PRESS START → menu:

- **New Game**: asks for a character name (default "Fony", a placeholder). If that name already has a save, it asks "Start over?" with Cancel focused. Then it plays the **Act I intro video** while the park loads behind it, and hands straight on to **P.1 Practice Run**.
- **Load Game**: greyed out (and skipped by the focus) when this account has no saves. Lists the account's characters, newest first, with an autosave and a manual save row for each (where, play time, date).
- **Uprising Arcade**: the "Zero Game Thing Pro" console. See below.
- **Credits**: from `data/credits.json`. The engine block reads the running Godot version and appends the full MIT license from the engine binary. Unknown people show as "[credit TBD]".

The intro video replaces P.0's billboard beat and the old flyer card ("fifty thousand"; the prize is $500,000) at the start of P.1. P.1's first line now opens the mission.

Dev and test ways past the menu (first load only, so Quit to title still lands on the menu): `?play=free`, `?story=p1`, `?story=p1&story_demo=1`, `?district=…`, `?demo=…`, and the same words after `--` on desktop. **P** in free roam still starts P.1.

## Intro video

- Config: `data/intro_video.json`. Sources are tried in order: `media/intro/project-zero-intro-720p.mp4` (a copy written at export from `AU_INTRO_MP4=<file>`; a cheap 404 when absent), then the **hosted cut** (`https://algorithmicuprising.com/media/uploads/1cd5a1cf-…-pz-intro-web-720p.mp4`, which 307-redirects to media-edge with byte ranges, FR-040), then `media/intro/intro-placeholder.mp4`. `?intro=<url>` plays another file. `?intro=skip` goes straight to P.1.
- Fallbacks (Act I, Nov 19 2026), so the game is never stuck: a per-source load timeout (`load_timeout_s` 15) or a media error moves to the next source; if play() is refused even muted, a **TAP TO PLAY / SKIP INTRO ›** card shows; a stall over `stall_s` (8) shows **TRY AGAIN / SKIP**, and after `stall_giveup_s` (20) the intro ends itself; a hard cap (`max_extra_s` past the duration) ends it too. If the overlay cannot be built at all, Godot goes straight on to P.1. `tools/intro-check.mjs` (`npm run intro-check`) checks all of these in Chrome.
- Web: an HTML `<video>` overlay (`#pz-intro`) injected by `scripts/front/intro_player.gd` through JavaScriptBridge. The file is **outside the pack**, next to it in `media/intro/`. The loading shell is untouched, because it must ask nothing of the player.
  - If no source loads, a 4 s "INTRO VIDEO IN PRODUCTION" card shows instead.
  - If the browser blocks sound autoplay, the video plays muted with a "CLICK FOR SOUND" button.
- Skip: press-and-hold for 1 s the first time (a ring fills: any key, click or pad button). Once the intro has been seen through, a single press skips it (`skip.hold_s` / `skip.hold_s_after_seen`). `user://pz_prefs.json` keeps `intro_seen`.
- Native: plays `res://media/intro/project-zero-intro.ogv` or `user://intro/project-zero-intro.ogv` if one exists, otherwise skips. Headless always skips.
- The repo's media guard keeps video out of git, and the real 720p cut (~14.8 MB) is too large to commit. `tools/export-web.mjs` writes the placeholder with ffmpeg (6 s, 1280x720, H.264/AAC faststart, title text, a quiet tone, about 70 KB). CI installs ffmpeg and **fails the export** if that file is missing (a prior warn-and-continue left GitHub Pages and the site without `media/intro/*.mp4`). It also copies the real cut from `AU_INTRO_MP4=<file>` when that is set. Set `AU_INTRO_PLACEHOLDER=0` only for local experiments. The ChatGPT-hosted site must republish `open-world/media/intro/` alongside the pack after a Pages deploy.

## Saves

`contracts/save_record.gd` is now **v3**. It reads v1, v2 and v3, and writes v3. New in v3:

- `meta`: character, account, created / saved time, play time, kind (auto/manual), and `migrated_from`.
- `player`: mode (story/free), district, zone, position, yaw.
- `settings`: look sensitivity, invert Y, painted sprite.
- `story.current`: the mission in progress.

Missions, checkpoints, completions, Zero Scores and bests, and district visits were already in v2 and carry over unchanged.

**Slot design: one save identity per character name.** Each character has one **autosave** and one **manual** save. There are up to 12 characters per account.

```
user://pz_saves/<account>/<character>/auto.json
user://pz_saves/<account>/<character>/manual.json
```

Why this design:

- The user asked for saves "under your chosen character name". The name is the slot, so there is no "Slot 3" to remember.
- The autosave is written at every checkpoint, on mission completion, on New Game, and every 90 s in free roam. It can never overwrite the player's deliberate save, which is only written by the pause menu's Save.
- Load offers both rows. Loading the manual save writes it back over the autosave first, so play continues from there.
- Twelve characters is a cap against runaway folders, not a design limit.

`<account>` is `guest` until the site answers the account handshake (below), and `au-<id>` after. On web, `user://` is IndexedDB. The browser check reloads the page and loads the save back.

The pre-front-end save (`user://au-open-world-save-v1.json`) is imported once as the guest character "Fony", so nobody loses M0/M1 progress.

**Loading** restores the following:

- Story: P.1 resumes at the saved checkpoint objective (the player is teleported to its spawn, with a "Loaded. Back at the checkpoint" line).
- Free roam: the saved position, district, yaw and walk/skate state.
- Play time and settings.
- The combo meter is not saved. It resets at the checkpoint, as T-retry does.

**Pause menu** (when a character is loaded): Save (manual + auto), Load (back to the title's Load list), and Quit to title (autosaves first).

## Protagonist name

`scripts/front/protagonist.gd`: lines in mission JSON may use `{name}` / `{NAME}`, and the speaker tag "FONY" shows as the chosen name (coloured as before).

These can't swap (flag for the writers and the edit):

- The intro video's baked-in text: the "DEPENDENT: SPROCK, F." line and the phone screens.
- Any future voiced line that says "Fony".
- The `fony` blip SFX name is internal only.

## Uprising Arcade / Game Thing Pro

"Game Thing Pro" is the in-game console screen ("UPRISING ARCADE · ZERO GAME THING PRO") that the menu item opens.

- Its top entry overlays the site's real **ZERO GAME THING 2000** console (`https://algorithmicuprising.com/arcade/`). Arcade sign-in, saved scores and leaderboards live there.
- Below that are the arcade cartridges (the same list as the in-world arcade interior), each opened in the existing `arcade_overlay.gd` iframe.
- The overlay's button reads "BACK TO PROJECT ZERO" and returns to the console screen.
- The arcade code is not touched.

## Accounts (how the arcade does it, and what this build does)

**The arcade:**

- The games in `../arcade` have no accounts of their own. They run inside the site's console, and `arcade/demo/embed-bridge.js` posts score events (`game:over`, `game:save-score`) to the parent page, for allowlisted hosts only.
- The site (algorithmicuprising.com) owns the account:
  - An email sign-in link (`/api/player/email-link`: POST sends the link, PUT redeems the token) and a session cookie.
  - The Player Account page (`/account/?from=arcade`: claim your handle, play as a guest, my scores).
  - Scores at `/api/arcade/scores`.
- There is no game-save API.

**Project Zero:** this build is served from GitHub Pages, so it can't read that cookie or call those APIs (cross-origin, no CORS). `scripts/front/account_bridge.gd` uses the arcade's own pattern instead and asks the parent page:

```
game → parent   {source:"project-zero", type:"pz:hello",   v:1, want:["account"]}
parent → game   {source:"au-site",      type:"pz:account", v:1, player:{id, handle} | null, capabilities:["pz-saves"?]}
game → parent   {source:"project-zero", type:"pz:save",    v:1, character, kind, save}     // only with "pz-saves"
```

It uses the same host allowlist as `embed-bridge.js`. With no answer in 1.5 s, the player is a guest.

- **Today the site does not answer, so everyone plays as a guest, and saves stay on this device in `user://` (IndexedDB), keyed `guest/<character>`.**
- The menu shows "PLAYER: GUEST (SAVES ON THIS DEVICE) · SIGN IN ↗". The link opens the site's Player Account page in a new tab, which is the same account the arcade uses.
- When the site starts answering, saves key under `au-<id>` with no game change.

### Proposed site change (for ChatGPT, which owns the site; not made here)

FR: "Project Zero account handshake + optional cloud saves". On `/play/project-zero/` (the page that iframes the game), add a message listener:

```js
window.addEventListener('message', async (e) => {
  if (!/^https:\/\/algorithmicuprising\.github\.io$/.test(e.origin)) return;   // the game's origin
  const d = e.data || {};
  if (d.source !== 'project-zero') return;
  if (d.type === 'pz:hello') {
    const me = await fetch('/api/player/me', { credentials: 'include' }).then(r => r.ok ? r.json() : null).catch(() => null);
    e.source.postMessage({ source: 'au-site', type: 'pz:account', v: 1,
      player: me ? { id: me.id, handle: me.handle } : null,
      capabilities: me ? ['pz-saves'] : [] }, e.origin);
  }
  if (d.type === 'pz:save') {
    // optional phase 2: PUT /api/project-zero/saves/:character  (body = d.save, max ~64 KB, kind auto|manual)
  }
});
```

Needs (site side):

1. A "who am I" endpoint, or reuse whatever the account page already calls.
2. The listener above.
3. Optional phase 2: a small saves table and API, plus `pz:saves` (list) and `pz:load` messages, so saves follow the account across devices.

Until phase 2, a signed-in player's saves are still local to the device, just filed under their account.

## Files

- `scenes/start_screen.tscn`, `scripts/front/start_screen.gd`: the menu and its panels.
- `scripts/front/game_session.gd`: the `GameSession` autoload (character, intent, play time, prefs).
- `scripts/front/save_slots.gd`: the slot store and the legacy import.
- `scripts/front/account_bridge.gd`: the account adapter.
- `scripts/front/intro_player.gd`: the intro video.
- `scripts/front/protagonist.gd`: the name swap.
- `data/start_screen.json`, `data/intro_video.json`, `data/credits.json`.
- `tools/make_start_screen.py`: rebuilds `assets/start_screen/` from the approved layers.
- `assets/fonts/PressStart2P-Regular.ttf` (OFL).

## Checks

- Headless: `AU_TEST_ONLY=front` (71 checks: save v3 and migration, slots, protagonist, account, intro, menu navigation, New Game confirm, park New Game, load resume, pause save, free-roam load). The full suite runs them too.
- Browser: `node tools/export-web.mjs && node tools/stage-composite.mjs && AU_FRONT_OUT=<dir> node tools/frontend-check.mjs` (fresh profile, records `frontend-check.webm`).
- Run the headless suite before export. Like the staged composite, `build/web/media/` now trips the media guard if it is left under the project.
