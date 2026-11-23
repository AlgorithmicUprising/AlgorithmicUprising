# Contributing

Branch from `main` and open the pull request back to `main`. Branch names, stacks, and who merges are in [docs/BRANCHING.md](../docs/BRANCHING.md). The owner merges anything that publishes. Keep game changes in `arcade/` except a shared workflow or contract named in that guide. Do not commit `dist/`, secrets, song audio, lyrics, tracking pixels or external trackers. Validate mobile input, keyboard access, reduced-motion and event contracts. Art arrives as a validated skin folder. Release bundles are built by CI and belong only in release-tag commits.

PR checklist: [ ] placeholder works without art [ ] game:start/game:over/game:share [ ] keyboard/touch [ ] 16:9 and 9:16 [ ] pause on blur/offscreen [ ] no tracking/audio files [ ] bundle <60KB gzip [ ] no AU brand assets in open starter skins.
