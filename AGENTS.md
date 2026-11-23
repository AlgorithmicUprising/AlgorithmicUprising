# Rules for agents in this repo

Zero (Cursor cloud agents) and ChatGPT both work here for the owner, Algorithmic Uprising. The full rules are [docs/BRANCHING.md](docs/BRANCHING.md). This page is the short list. If an older doc disagrees about branches or publishing, `docs/BRANCHING.md` wins.

## Who touches what

- **Zero** (`cursor/…` branches): Project Zero, the Godot game in `open-world/`.
- **ChatGPT** (`chatgpt/…` for new work): Punk Arcade in `arcade/`. The website and Zero Admin are ChatGPT's and are not in this repo.
- **The owner** merges. Agents open pull requests and stop.

Both agents push as the same GitHub user. The branch prefix is how you tell the work apart. Do not rename branches that already have an open pull request.

Leave these alone. No push, rebase, retarget, or close:

- [#28](https://github.com/AlgorithmicUprising/AlgorithmicUprising/pull/28) `feat/pz-account-identity-handshake`
- [#32](https://github.com/AlgorithmicUprising/AlgorithmicUprising/pull/32) `feat/bpw-r2-deploy-phase1`

## Day to day

1. Branch off current `main`. One reviewable change per pull request.
2. Open the pull request into `main`. Say whether merging publishes the live site.
3. Stack only when the later work cannot be reviewed without the earlier commits. The child pull request targets the parent branch, not `main`. After the parent merges, retarget the child to `main` and merge `main` into it.
4. Update your branch by merging `main` in. Force-push only your own branch, only right after a rebase you announced, and never when another open pull request uses it as a base. Never force-push `main` or another agent's branch.
5. Wait until the checks that match your diff are green. Arcade and open-world changes need Punk Arcade CI. Open-world changes also need the composite workflow, which does not deploy. Docs outside `arcade/**`, `open-world/**`, and `.github/workflows/arcade.yml` do not run those workflows and do not publish. A markdown file that lives inside `arcade/` or `open-world/` still does.
6. Do not merge.

## Live site

`main` is live. The job **Publish arcade and HQ Pages from main** deploys arcade and `/open-world/` together. algorithmicuprising.com iframes that `/open-world/` build.

A failed publish is usually a rerun, not a new commit. Cloud agents cannot rerun jobs or dispatch workflows (the token has no `actions=write`). Tell the owner the run link. Do not push an empty commit to kick a deploy while another `main` publish is in progress.

Do not add a second `actions/deploy-pages` job. A "preview" job on the `github-pages` environment replaces the live site.

## Budgets and files

- Main pack 50 MiB. Each district pack at its `budget_bytes`, hard cap 8 MiB. `stage-composite.mjs` fails the build over budget.
- Arcade cartridge bundles stay under 60 KB gzip.
- Do not commit `dist/`, `.pages/`, `build/`, `.godot/`, `node_modules/`, secrets, song masters, lyrics, or new audio binaries.

## The other agent's files

Need a change outside your area: comment on the pull request with the path and the reason, and wait. For a lasting ask, add an `FR-###` on the owner's feature-request sheet. FR-039 and pull request #28 are the account bridge. Do not open a second edit of that contract.

Shared on purpose: `.github/workflows/**` (owner merges), and the `pz:hello` / `pz:account` messages between `open-world/web/zero_x_shell.html` and `arcade/demo/embed-bridge.js`.
