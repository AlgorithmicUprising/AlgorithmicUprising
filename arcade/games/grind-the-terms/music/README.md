# Grind the Terms music

The soundtrack is an ordered playlist in `tracks.json`. The game currently contains one track: the 8-bar, 94.54 BPM “Terms & Conditions” loop from its MIDI source. Its seamless Ogg Vorbis render is the browser playback file; the original MIDI is kept beside it for future edits. Browsers do not natively synthesize Standard MIDI files.

With one track, the game loops it continuously. When more tracks are added to the catalog, it plays them in order and cycles through the list. Add each new render and MIDI source in this folder and add its entry to `tracks.json`; `stage-pages.mjs` copies this folder into the Pages build.

The MP3 preview is a compatibility fallback for browsers without Ogg Vorbis playback support.
