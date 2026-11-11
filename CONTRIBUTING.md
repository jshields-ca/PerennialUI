# Contributing to Perennial UI

Thanks for helping. Anyone can contribute: code, tests, bug reports, design, translations, or reviewing other people's pull requests.

## The one hard rule: clean room

Perennial UI is written from scratch. Its value as free software depends on every line being ours to license.

- **Do not open, read, paste or summarise the files of ObsidianUI, ForeverUI, or any addon whose licence does not allow reuse.** That covers Lua, XML, textures, fonts and saved-settings files.
- Work from **public behaviour**: what a feature does in the game, public feature descriptions, and the client's own API.
- Do not recreate another addon's look, preset names or branding.
- Code from addons under a GPL-3.0-compatible licence (MIT, BSD, GPL-2.0-or-later, GPL-3.0) may be used if you keep the copyright notice, say so in the pull request, and add it to `THIRD_PARTY.md`.
- Code written with an AI assistant is welcome under the same rule: you are responsible for it being original, and the assistant must not have been given a closed addon's files.

A pull request that breaks this rule will be closed, and the code will not be merged even if rewritten by the same person from memory.

## Sign your work (DCO)

Every commit must be signed off. The sign-off certifies the [Developer Certificate of Origin](https://developercertificate.org/): you wrote the change, or otherwise have the right to submit it under the project's licence.

```bash
git commit -s -m "Add target frame cast bar"
```

That adds a `Signed-off-by: Your Name <you@example.com>` line. Forgot? Fix a branch with:

```bash
git rebase --signoff main
```

```bash
git push --force-with-lease
```

CI rejects pull requests with unsigned commits.

## How a pull request gets merged

1. **Open it.** Fork, branch, push, open a pull request and fill in the template. Open it as a draft if it is not ready.
2. **CI runs** four checks: `Lint` (luacheck), `Tests` (busted), `File checks` (licence headers, TOC) and `DCO`.
3. **Anyone can review.** You do not need any role to read a pull request, test it in game, and leave comments or suggestions. Reviews from other contributors are how most problems get caught, and they count: maintainers read them.
4. **A maintainer of the touched files approves**, or asks for changes with comments on what would make it mergeable. Maintainers are listed in [`.github/CODEOWNERS`](.github/CODEOWNERS).
5. **It merges by itself.** Once the checks are green and a code owner has approved, GitHub squash-merges it. Nobody has to press a button, and no approval is needed from the project owner unless the files are theirs.

If a review asks for changes, push more commits to the same branch. The checks rerun and the approval is requested again.

What reviewers look for:

- It follows the clean-room rule and every commit is signed off.
- It does one thing. Small pull requests merge fast; split unrelated changes.
- Core logic has tests. UI code says how it was tested in game.
- It follows the conventions below.
- A module can be switched off and leaves the default UI as it was.

### Becoming a maintainer

Maintainers are contributors who own part of the code. After a few merged pull requests in an area, open a pull request adding yourself to `CODEOWNERS` for that folder (for example `/PerennialUI/Modules/Bags/`). From then on your approval is enough to merge changes there. Core, CI, licence and release files stay with the project owner.

## Setting up

See [Develop in the README](README.md#develop). You can contribute without installing Lua: push your branch and let CI tell you.

## Conventions

- **Lua 5.1**, four spaces, 120 columns. `luacheck .` must be clean.
- Every Lua file starts with `-- SPDX-License-Identifier: GPL-3.0-or-later` and is listed in `PerennialUI/PerennialUI.toc`.
- One global only: `PerennialUI`. Everything else hangs off the addon namespace (`local _, ns = ...`).
- **Features are modules.** Register through `ns.Modules.Register`; never edit the core to add a feature. See [docs/MODULES.md](docs/MODULES.md).
- **Events go through the module** (`self:RegisterEvent`), so handlers run inside the safety net.
- **No hard-coded colours, sizes or fonts.** Use `ns.Theme`.
- **Combat values may be hidden.** Read them through `ns.Compat.Number(value, fallback)` and design the widget to cope with the fallback.
- **Protected frames:** use secure templates for anything clickable in combat, and `self:RunWhenSafe(key, fn)` for moving or reconfiguring frames.
- **Do not call Blizzard's map, quest or auction code on the player's behalf**; it taints. Build our own frames.
- **Client differences live in `Compat/`**, never in a module.
- New API globals go in `.luacheckrc` and `.luarc.json`.

## Fonts, textures and libraries

Only openly licensed assets (for example SIL OFL fonts, CC0 or CC-BY art). Commit the licence file next to the asset and list it in `THIRD_PARTY.md`. Libraries go in `PerennialUI/Libs/` and must be GPL-3.0-compatible.

## Reporting bugs and proposing features

Use the issue templates. For bugs, paste the output of `/pui bug`. For features, describe what the player should be able to do; if you want to build it, say so and someone will help you scope it.

## Conduct

Be kind and assume good faith. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
