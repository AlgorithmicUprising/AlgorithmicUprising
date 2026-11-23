# Challenge format

A challenge is a JSON object, contract `au.challenge` version 1. `ChallengeRunner` executes it. The same dictionary can be stored in a database later. Nothing is fetched over the network.

Templates: `timed`, `sneak`, `combo`, `camera-prep`, `chase`, `objectives`.

Act I's story scripts are unchanged. They still play the world. Each existing mission also has a data object under `open-world/data/challenges/` that records its mechanic, goals, and the numbers the story already uses (fail rule, drone speeds, sweep time, watch radius).

`example_glass_prep` is not a story mission. Its only line is marked PLACEHOLDER. Painting the parking camera clears it for 1 point.

Prep missions and the three run types stay as in the design note. This file does not add them to the game.
