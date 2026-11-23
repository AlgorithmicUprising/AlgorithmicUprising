## What this is

<!-- One or two sentences. Name the area: open-world, arcade, docs, or shared. -->

## Publish

<!-- Does merging this publish the live site? It does when the diff touches
     arcade/**, open-world/**, or .github/workflows/arcade.yml.
     Publishing waits for the owner's merge. -->

- [ ] This merge does not publish
- [ ] This merge publishes, and the owner has been asked to merge it

## Checks

<!-- Arcade or open-world: Punk Arcade CI build-and-browser-test.
     Open-world also: the composite workflow (it does not deploy).
     Docs outside those paths: no Actions run. Say so. -->

- [ ] The checks that apply to this diff are green, or this is docs-only and no workflow runs

## Size and files

- [ ] Open-world art or packs: main pack under 50 MiB, each district pack under its budget and under 8 MiB
- [ ] Arcade cartridge: bundle under 60 KB gzip
- [ ] No secrets, no `dist/` or `build/`, no new song masters or audio binaries

## Other people's work

- [ ] I did not push to another agent's branch
- [ ] Pull requests #28 and #32 are untouched
- [ ] Any path I need from the other agent is named in a comment, and I am waiting
- [ ] This is not a stack, or it targets the parent branch and says which pull request it stacks on

## Notes

<!-- Pack report, screenshots, FR-### , or "none". -->
