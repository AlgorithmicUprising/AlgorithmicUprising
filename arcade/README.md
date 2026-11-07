# PUNK ARCADE · CH 05

Three dependency-free Canvas web component games, designed to embed in ZERO TV or stand alone. **Engineering scaffold / early playable greybox**; not a completed v0.1 release.

## Getting started

```bash
cd arcade
npm install
npm run build
npm run check
npm test
```

Open `demo/index.html` through an HTTP server (for example `python3 -m http.server 8080` from `arcade/`), then visit `http://localhost:8080/demo/`. The games have procedural graphics while artwork is pending.

## Embed

```html
<script type="module" src="/games/grind-the-terms/dist/grind-the-terms.js"></script>
<grind-the-terms></grind-the-terms>
<script type="module" src="/games/tag-before-training/dist/tag-before-training.js"></script>
<tag-before-training></tag-before-training>
<script type="module" src="/games/cookie-wall/dist/cookie-wall.js"></script>
<cookie-wall></cookie-wall>
```

All three components emit bubbling `game:ready`, `game:start`, `game:pause`, `game:resume`, `game:over`, `game:share` and `game:error` events. The host owns analytics and share links. Games store only a best score locally. Press space to jump in Grind; use arrows/WASD and space to spray in Tag. Mobile: tap Grind; use the on-screen buttons in Tag. Game art is intentionally replaceable by a per-game `skins/<id>/skin.json`; the first playable greybox uses built-in shapes.

[Cookie Wall](games/cookie-wall/README.md) uses one square court in both layouts. Move with arrows or A/D and launch with Space/U. On a phone, drag below the court and tap Launch.

## License

Code MIT. Starter skin art CC BY 4.0 when delivered. AU branding reserved. No band music or recordings in the repository.

Spec: [Punk Arcade folder](https://drive.google.com/drive/folders/1O6nuxBc8ZqZLy_x--7RLp64dw064C71A).
