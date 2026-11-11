## What this changes

<!-- One or two sentences. Link the issue it closes, e.g. "Closes #12". -->

## How it was tested

<!-- Tests added or updated, and what you checked in game (client version, class, in/out of combat). -->

## Checklist

- [ ] **Clean room:** I wrote this myself. I did not open, read or copy the files of ObsidianUI, ForeverUI or any other addon that does not allow it.
- [ ] Every commit is signed off (`git commit -s`).
- [ ] `luacheck .` and `busted` pass, and new core logic has tests.
- [ ] New Lua files have the SPDX header and are listed in `PerennialUI.toc`.
- [ ] Colours, spacing and fonts come from `Theme`; nothing is hard-coded.
- [ ] Combat values go through `Compat.Number`, and anything that touches protected frames goes through `RunWhenSafe`.
- [ ] A new module has an off switch that leaves the default UI element as it was.
- [ ] New fonts, textures or libraries are openly licensed, with the licence file included and `THIRD_PARTY.md` updated.
