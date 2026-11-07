# Cookie Wall

Bounce a packet of personal data through a wall of fictional consent banners. Three packets per run. The desktop and phone layouts share one 320×320 court, one fixed-step simulation and the same scoring rules.

## Play the branch build

From `arcade/`, install the locked dependencies with `npm ci`, run `npm run build`, then `npm run dev`. Open `/games/cookie-wall/demo/` on the local server. For a download-and-open playtest, open the built `dist/Cookie-Wall.html`. It includes the game and the illustrated Fony skin in one file and works offline. The HTTP preview has a skin switcher and an event log. The full-height iframe entry is `games/cookie-wall/demo/embed.html`.

| Action | Keyboard / pointer | Touch | Gamepad |
| --- | --- | --- | --- |
| Move and aim | Left/Right or A/D; point within the court | Drag below the board | Left stick or D-pad |
| Launch a docked packet | Space, U, Up or Launch | Launch | A |
| Pause / resume | P, Esc or the visible control | Pause / Resume | Start |
| Sound | M or Sound | Sound | Sound in the toolbar |

The opening wall has 24 single-hit bricks. Wall two introduces cracked Interest blocks. Wall three adds Reject All, which shrinks on its first hit. Later walls cycle through seeded permutations of the three layouts. A cleared wall docks the packet for the next launch. Speeds 170, 200, 230 and 260 apply on controlled paddle returns. The authored grid is offset two units to keep a 12-unit side passage even on full rows.

| Banner | Hits | DATA on destruction |
| --- | ---: | ---: |
| Strictly Necessary | 1 | 10 |
| 347 Ad Partners | 1 | 20 |
| Legitimate Interest | 2 | 30 |
| Reject All | 2 | 40 |

Destructions between returns earn ×1 for the first two, ×2 for the next two and ×3 thereafter. Each clear earns 100 flat. Partial hits score zero. Losing a packet resets the chain and requires another launch.

## Embed and reskin

```html
<script type="module" src="./games/cookie-wall/dist/cookie-wall.js"></script>
<cookie-wall skin="./games/cookie-wall/skins/fony/skin.json" seed="17"></cookie-wall>
```

Landscape uses a 640×360 shell; portrait uses 360×640. The component fits its actual container. Set `orientation="portrait"`, `"landscape"` or `"auto"` to override, or use the existing `layout="portrait"` alias. A standalone parent can give the element explicit width and height. The iframe accepts `skin`, `seed`, `orientation`, `muted` and `reduced-motion` query parameters. It chooses AU in the recognized first-party host and neutral otherwise. If the parent origin cannot be established, play stays local. Parent commands use an exact origin, the active parent window and `{source:"punk-arcade",type:"pause"|"resume"|"mute"|"unmute"}`.

Component attributes also include `autostart`, `storage-key`, `controls="auto|touch|keys"` and `label`. Methods are `start()`, `pause(reason?)`, `resume(reason?)`, `reset()` and `setSkin(urlOrNull)`. Properties are `state`, `best`, `version` and `muted`. First load is muted. Best and preferences use per-game local storage. Settings cover volume, reduced motion, contrast and handedness. Tab hide, loss of focus, offscreen visibility and host pause stop the run until explicit resume.

The component emits bubbling, composed `game:ready`, `game:skin-loaded`, `game:start`, `game:wall`, `game:pause`, `game:resume`, `game:over`, `game:share`, `game:sound` and `game:error` events. Results include the leak cause, score, best, active duration and stats for cleared walls, broken bricks, lost packets, returns and maximum chain. Cancel `game:share` in the component's document to handle sharing yourself.

The original placeholder art is code-drawn. Fony now has the first illustrated Cookie Wall skin, with native-size frames under `skins/fony/`. Its banners use four compact symbols—lock, linked nodes, eye and X—instead of in-block lettering; the full type names remain in the Settings legend. The renderer animates banner breaks, blocker hits, packet spins, tracker catches and debris. Copy `skins/placeholder/` to a sibling folder and change its id, attribution, flat strings, colors or synthesized SFX. Put each license in its skin folder. Optional loose PNG/WebP or simple vector frames use named keys in `files`, e.g. `blocker_idle_00`, `packet_spin_00`, `brick_interest_crack_00` and `bg_court_00`. File paths resolve against the manifest. Skin changes preserve the run; a bad manifest falls back to procedural play. Code is MIT, neutral and placeholder skins are CC BY 4.0, and the AU skin and marks are reserved.

Run `npm run check`, `npm test`, `npm run stage-pages` and `npm run e2e` from `arcade/`. This branch provides a review build. Physical-device playtesting, final illustrated skins and the production cartridge shelf are later milestones.
