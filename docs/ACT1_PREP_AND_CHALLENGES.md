# Act I prep missions and challenges

Design only. No code in this pass. Nothing here is new canon. Any line a character would say is marked **PLACEHOLDER** and is not a script line.

Sources that already exist: `data/missions/p2_run.json` (Glass Row chase, one parking camera, spot boost), `data/missions/act1_scenes.json` (1.4 Cold Row patrols, 1.5 six cameras and the swarm), `data/missions/p1_practice_run.json` (trick line and Zero Score), `data/spray_slot.json` (one color, no store), `data/intro_video.json` (Zero Admin upload, then a bundled fallback). The main pack budget is 50 MiB. District packs cap at 8 MiB.

## Owner decisions (recorded)

These three are decided. The season clock, what points unlock, and the Zero Admin publish path are not. Those stay unbuilt.

### 1. Camera painting stays, and it is optional

Lightest reason that is already in the game, not a new story:

- P.2's parking camera is the thing that says "Visual confirmed. Parking level one." and adds the chase speed burst (`camera.boost_s`).
- 1.5 already has the script line that those cameras are old and treat paint as weather.

So paint on that one lens is the same act as 1.5, used on the one camera that already confirms him. It only skips the burst. The welfare drone and both enforcers still come. Skipping the paint leaves the chase as it is. It is never required.

No new faction, plan, or speaker. The toast already in the build is `CAMERA BLINDED`. Any extra spoken line, if one is ever needed, is **PLACEHOLDER** and is not a script line.

Side-quest rewards are not designed. The owner's ideas (skin mods for Fony, Zero, and the board, and maybe other upgrades) wait for a separate talk. The challenge data may carry a hook and nothing else:

```json
"reward": {"type": "placeholder", "id": "tbd"}
```

The game does not grant that hook.

### 2. Spraying a drone in a chase calls the others

The sprayed drone stays down for the existing 8 s. Drones inside `alert_radius` of that spot fly there for `investigate_s`, then scan for `tracking_s`. A scan is a cone of `scan_deg` degrees, out to `scan_range`, checked `scan_hz` times a second. While they are scanning, he has to stay out of the cone. A drone that sees him in the cone goes back to chasing. A drone whose tracking time runs out stops searching and returns to the trail. Numbers live on the chase data. The drone count does not change.

### 3. Painted cameras are cleaned later

A painted camera stays blind until a duration on a clock runs out. The clock is a parameter: `play_time` or `story_time`. **Open call:** which clock. The data default is `play_time`, because after the story the game is open world and story time may not move. Recovery uses the same save in a mission and in free roam. Paint is stored on the save, not only on the node.

Still open, and not built from this note: whether 1.4 paint counts toward 1.5, whether sneak allows paint, the season clock, what points unlock, and Zero Admin publishing.

## Prep missions

A prep mission is optional. Skipping it leaves the later mission exactly as it is now. Painting never removes a drone the script already sends, and it never skips a cinematic.

The player cannot walk Glass Row before P.2 today. P.2 starts at the yard fence (`p2_run.json` start) and the street loads for the chase. A real "before" needs a short optional beat, or the paint has to happen on the way.

### Glass Row, before P.2 Run

Already in the mission: one drone camera on parking level 1 (`camera.rect`, `boost_s` 5, chase `boost` 3.5). Seeing the player there speeds the drones up. Painting that camera before the zone, which the controls pass already does, skips that burst.

Proposed prep, default **paint-on-the-way** until the owner asks for a separate beat:

| Camera | Where it is now | If it is painted before it sees him |
|---|---|---|
| Parking level 1 | The ramp route, the only camera in the data | No spot burst. Welfare drone and both enforcers still come. `delay_s` stays 4. |

If the owner wants a stronger soften, each extra camera (dock mouth, plaza edge) adds 2 s to `delay_s`, capped so the enforcers still arrive. Those extra cameras are not in the script. They are geometry, not characters. No new spoken line. A HUD toast can say **PLACEHOLDER** `CAMERA BLINDED`.

The chase still fails the same way: a net, fade, last checkpoint. `P2_FAIL_RULE` stays `checkpoint`. Zero Score time is unchanged.

### Cold Row, before 1.5 The Breaker

1.5 already is "paint six cameras while two drones patrol, then hold the line." That is the mission, not prep.

Default: no separate prep scene. Optional marks during 1.4, off the three script marks (lawn, substation, intake), can blind a 1.5 camera early. 1.4's WATCH loop does not change. The 1.5 swarm does not get smaller. A pre-blinded camera still plays Zero's phone beat unless the owner picks "already done, skip the beat."

1.2, 1.3, and P.3 are not chases. P.3's window drone is a sweep inside the arcade. No prep mission there.

## Challenge points

One integer on the save, `challenge_points`. It does not buy story, grip tape, or a district. There is no store.

Default unlock: the counter, plus one empty spray slot id `pack_later` in the spray data. The color stays Yard lime until a skin pack replaces the hex. The phone shows **PLACEHOLDER** `PACK LATER`.

Points come from a clear, not from retries. A fail stores nothing. Story Zero Score (P.1 points, P.2 time) is a different number and does not move when a challenge pays out.

## Three run types

Courses are existing routes. No new district.

| Template | Course | What is scored | Clear | Points (default) |
|---|---|---|---|---|
| `timed` | P.2, fence to side door, both routes legal | Finish time against a par. Not the story Zero Score. | Door, not caught | 3 / 2 / 1 under gold / silver / bronze par |
| `sneak` | 1.4's three marks | Never spotted. Time is not the score. | All three marks, WATCH never full | 3 if no drone was sprayed after it saw him, else 1 |
| `combo` | P.1 yard (bowl, quarter, rail) | Peak chain on the boost meter | End the run standing, chain at least 2 | 1 / 2 / 3 at chain 2 / 4 / 6 |

Painting the parking camera before it sees him still counts as unseen on a Glass Row sneak, if we add that course later. Default sneak is 1.4 only, because WATCH already exists.

Caught, spotted, or a bail that drops the chain under the goal pays 0.

## Season

Default: the device's calendar month. No server clock. The catalog names the month (`2026-11`), not a story title.

- Online: the published catalog's `season_window` is the season.
- Offline, or the fetch fails: the bundled file for that month, else the latest bundled season.
- A wrong device clock only changes which bundled month you see. We do not correct it from the network.
- The point bank does not reset when the month changes. The medal for that month does.

All three templates stay in the menu every month. The calendar only changes the timed-run par and a **PLACEHOLDER** label (`NOVEMBER RUN`).

## UI

No new item on the title screen.

- Phone log (View / M) grows a **CHALLENGES** page: Prep, Timed, Sneak, Combo, and the point bank.
- Pause gets one row, Challenges, that opens that page.
- A challenge uses the HUD it already has: the clock, WATCH, or the boost meter. No debug string.
- The result card is one line. Example, not canon: **PLACEHOLDER** `CLEAR · 2 POINTS`.

Prep is listed only when that mission is available (after the heat alert for Glass Row, during 1.4 for the Cold Row marks). Before that the row is locked and says the mission id, not a new explanation.

## Challenge schema

Contract `au.challenge`, version 1. One file per challenge. A catalog lists the ids that are allowed to run.

```json
{
  "contract": "au.challenge",
  "contract_version": 1,
  "id": "p2-timed-2026-11",
  "title": "PLACEHOLDER November run",
  "story": [
    {"speaker": "", "text": "PLACEHOLDER", "image": "card.jpg"}
  ],
  "images": [
    {"id": "card.jpg", "url": "https://algorithmicuprising.com/media/challenges/p2-timed-2026-11/card.jpg", "bytes": 80000, "w": 1280, "h": 720}
  ],
  "district": "glass_row_edge",
  "spawn": {"mission": "p2_run", "checkpoint": "yard"},
  "mechanic": "timed",
  "goals": [{"id": "door", "event": "p2_door"}],
  "scoring": {"par_s": {"gold": 70, "silver": 90, "bronze": 120}},
  "points": {"gold": 3, "silver": 2, "bronze": 1},
  "season_window": {"start": "2026-11-01", "end": "2026-12-01"},
  "unlocks": [],
  "status": "published"
}
```

`mechanic` is only one of: `timed`, `sneak`, `combo`, `camera-prep`, `chase`. Anything else is rejected. The template picks the existing runner. Text and images do not pick code.

| Field | Rule |
|---|---|
| `id` | `[a-z0-9-]{1,64}`, unique in the catalog |
| `title`, `story[].text` | Required. New words stay **PLACEHOLDER** until the owner replaces them |
| `story[].speaker` | Empty, or a name already in Act I. No new speaker |
| `images` | 0 to 3. JPEG or WebP. Each ≤ 200 KiB, ≤ 1280×720 |
| `district` | An id in `data/districts.json` |
| `spawn.mission` | An id the game already runs (`p1_practice_run`, `p2_run`, `a1_cold_row`, `a1_the_breaker`) |
| `spawn.checkpoint` | A checkpoint on that mission, or omitted for the mission start |
| `goals` | 1 to 8. Each `event` is one the template already emits |
| `scoring` / `points` | Must match the template table above. No custom formula |
| `season_window` | Inclusive start, exclusive end, `YYYY-MM-DD`. Omitted means always |
| `unlocks` | Empty, or `{ "type": "spray_slot", "id": "pack_later" }` only |
| `status` | `draft`, `approved`, `published`. The game loads `published` only |

Validation runs twice. Zero Admin rejects Save on a draft that fails. The game rejects a published file that fails and skips that id. One bad challenge does not drop the rest. The bundled Act I set still runs.

Checks: contract and version, enum mechanic, known district and mission, goal events allowed for that mechanic, image bytes and dimensions, `https` URL on the allowlist below, season end after start, points inside the template cap (max 3 per clear).

## How the game loads it

Same idea as the intro clip and the arcade catalog. JSON is first-party. Images may be the media host.

1. Bundled seed: `res://data/challenges/catalog.json` plus the Act I challenge files. Always in the pack. This is the offline game.
2. If the page is on the web and the network answers within 2.5 s, fetch `https://algorithmicuprising.com/open-world/challenges/catalog.json`.
3. That catalog may list extra published ids. Each file and image is fetched from the same site or from `https://media.algorithmicuprising.com` / `media-edge.algorithmicuprising.com` (the intro's FR-040 host). Any other origin is ignored.
4. Fetched files are cached under `user://challenges/` with the catalog's version. Next launch uses the cache if the network fails.
5. If the fetch fails, times out, or the catalog fails validation, the bundled seed is the whole list. Play does not wait on it.

Images are not imported into the pck. A published challenge must not require an export. The bundled seed should ship with no new bitmaps (the district is already loaded). Remote cap: 3 images × 200 KiB, and the catalog itself under 64 KiB. A session stops fetching images after 1 MiB.

Headless and offline never call the network. Tests use the bundled seed only.

## Authoring and publish

ChatGPT owns the Zero Admin code. This is a spec for that app, not a change to it from this repo.

Recommended path: **draft in Zero Admin, owner approves, public catalog updates.** Git keeps the bundled seed. A standalone editor is a second product and we should not build one. PR-only JSON cannot ship a season without an export, so it is the seed and the review copy, not the live path.

### API (proposed)

All writes need the admin session. `approve` and `publish` need the owner session. A draft can be saved by the admin; it cannot set `status` to `published`.

| Call | Who | Effect |
|---|---|---|
| `GET /api/game-challenges` | admin | Drafts, approved, published |
| `POST /api/game-challenges` | admin | Create draft. Body is the schema. Server validates. |
| `PUT /api/game-challenges/:id` | admin | Edit while `draft` or `rejected` |
| `POST /api/game-challenges/:id/images` | admin | Upload one image through the existing media upload. Returns a media-edge URL. Reject over 200 KiB. |
| `POST /api/game-challenges/:id/submit` | admin | `draft` → waiting. Validation must pass. |
| `POST /api/game-challenges/:id/approve` | owner | Waiting → `approved` |
| `POST /api/game-challenges/:id/reject` | owner | Waiting → `rejected`, with a note |
| `POST /api/game-challenges/:id/publish` | owner | `approved` → `published`, rewrite the public catalog |
| `GET /open-world/challenges/catalog.json` | public | Published ids only |

Publish writes the catalog and the JSON files to Pages (or the same R2 bucket the catalog URL fronts). It does not trigger a Godot export. Unpublish sets `status` back to `approved` and removes the id from the public catalog. The bundled seed is untouched, so offline play keeps Act I.

The public catalog:

```json
{
  "contract": "au.challenge_catalog",
  "contract_version": 1,
  "version": "2026-11-23T00:00:00Z",
  "challenges": [
    {"id": "p2-timed-2026-11", "file": "p2-timed-2026-11.json"}
  ]
}
```

## Act I missions as templates

Story missions stay `au.mission` files. A challenge points at one. It does not replace the script.

| Existing mission | Template | What the template is allowed to read |
|---|---|---|
| P.1 Practice Run | `combo` | Peak chain, bail, the yard tricks. Not the story Zero Score. |
| P.2 Run | `timed`, `chase`, `camera-prep` | Door event, caught, checkpoint, the parking camera's painted flag, finish time |
| P.3 Power On | none | Sweep and fuses stay story-only |
| 1.1 Fine Print, 1.2 Water Run, 1.3 Cool Roofs | none | No chase |
| 1.4 Cold Row | `sneak`, `camera-prep` | WATCH full, three marks, optional early cameras |
| 1.5 The Breaker | `camera-prep`, `chase` | The six cameras, patrol spotted, swarm left as story |
| Cinematics P.2, P.3, P.4, 1.4B, 1.5B, 1.5C | none | Not challenges |

`camera-prep` goals are "this camera id is painted before the chase flag." `chase` goals are "reach the door" or "survive the swarm" using the fail rule that mission already has. `timed` is `chase` plus a par. `sneak` fails on `seen_by_drone` filling WATCH. `combo` fails the payout on a bail that zeroes the chain.

## Recommendation

Build the bundled seed and the five templates first, with Glass Row paint-on-the-way, 1.4 sneak, P.1 combo, and P.2 timed. Points are a counter plus the empty `pack_later` spray slot. Seasons are the device month.

Author new seasons in Zero Admin with the API above. Owner approval is the only publish. The game fetches the catalog and falls back to the seed. Do not add a standalone editor. Do not put challenge images in the pck.

The three decisions above are the ones to build. Rewards stay a hook. The clock choice stays open, with `play_time` as the data default. The other open calls stay unbuilt.
