# Pages release 2026-11-08

This file is outside `arcade/**`, `open-world/**`, and `.github/workflows/arcade.yml`, so committing it does not start another Pages publish.

The 21:00 America/Chicago routine should not publish this same tree again. `origin/main` and the live `github-pages` deployment are already the same commit.

## Live

- SHA: `b2711fce27153f983d328c7866a1396b9fef0b40`
- Run: https://github.com/AlgorithmicUprising/AlgorithmicUprising/actions/runs/42538207963
- Deployment: `7643914401`, state `success` at `2026-11-09T00:10:58Z`
- URL: https://algorithmicuprising.github.io/AlgorithmicUprising/

## Merged

- #13 `524a0e8969835ba867d40210ca42f980850620ed` Pages concurrency guard, merge `7d063537af032f0e9010c695e3e9a17d06ad6fa7`
- #9 `6fd21defc4765958179569b82c678ed290537612` mouse invert and camera-forward movement, merge `3c4978975fed0d89b8b458383c5894b41b1e896b`
- #10 `4a33031c5b5e6c8a9f153bd7142bebc9347fd1c5` reusable quarter-pipe, merge `1a196b02ebdfcef3b0f91c51528d22b563731618`
- #11 `b60f77db613dad610b3ebf45627be0487167038c` tricks on that rig, retargeted onto `main` without a force-push, merge `b2711fce27153f983d328c7866a1396b9fef0b40`

## Not merged

- #12 `74e6bf26cf5be16d617b19c2bb62de975e60b872` Fony appearance. It missed the approved art and stays open.

## Checks before the final publish

Headless suite on the combined tricks tree: 205 passed, including default mouse-Y inversion and the right-stick pitch staying independent of that setting. Arcade CI and the non-publishing composite workflow were green on `b60f77db613dad610b3ebf45627be0487167038c` before the merge.

The #10 publish run `42537817489` failed its Godot step on `right stick pitch ignores the mouse invert setting` (`inv=0.0`, `plain=0.05`) and did not upload. The #11 publish, which contains the same controls, passed that step and is the live site.

## Live checks at 2026-11-09T00:11:34Z

Automated HTTP, not a physical device:

- `GET /` 200, last-modified `Mon, 09 Nov 2026 00:10:51 GMT`, body redirects to `./demo/`
- `GET /demo/` 200 and references `grind-the-terms.js`, `tag-before-training.js`, and `cookie-wall.js`
- `GET /games/grind-the-terms/dist/grind-the-terms.js` 200, `content-type` `application/javascript`
- `GET /games/cookie-wall/demo/page.js` 200
- `GET /open-world/` contains `GODOT_THREADS_ENABLED = false` and `index.js`
- `GET /open-world/index.wasm` 200, `content-type` `application/wasm`
- `GET /open-world/index.pck` 200, etag size `0x43ac0` (277,184 bytes), the tricks pack, not the unmerged Fony-look pack

Headless Chrome loaded `/open-world/` and saw `window.AU_HQ` with `session: world`, `invert: true`, `zone: SKATE YARD`, `skating: true`. No page errors. That is not a physical mouse or gamepad test.

## Still true

Fony in this release is the intermediate skinned rig from #11, not finished character art. The quarter-pipe is the reusable teal asset from #10. Mouse Y starts inverted, and W follows the rendered camera's horizontal forward.
