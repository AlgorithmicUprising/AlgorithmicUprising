# Contributing

Work on `arcade` or a feature branch, PR into `arcade`, and only merge to `main` with band approval. Keep changes in `arcade/` except `.github/workflows/arcade.yml`. Do not commit `dist/`, secrets, song audio, lyrics, tracking pixels or external trackers. Validate mobile input, keyboard access, reduced-motion and event contracts. Art arrives as a validated skin folder. Release bundles are built by CI and belong only in release-tag commits.

PR checklist: [ ] placeholder works without art [ ] game:start/game:over/game:share [ ] keyboard/touch [ ] 16:9 and 9:16 [ ] pause on blur/offscreen [ ] no tracking/audio files [ ] bundle <60KB gzip [ ] no AU brand assets in open starter skins.
