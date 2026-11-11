# Roadmap and build plan

Six phases. Each ends at a **gate**: something a player can test, not a date. Work inside a phase can happen in any order and in parallel, one module per contributor.

Parity target: the 45 capabilities below, drawn from public feature descriptions and restated in our own words. How each is built is our own design (see the clean-room rule in [CONTRIBUTING.md](../CONTRIBUTING.md)).

| Phase | Theme | Gate |
| --- | --- | --- |
| 0 | Foundation | The addon loads clean on Forever, settings window opens, frames can be dragged and positions survive a reload, a deliberately broken test module is paused without affecting anything else |
| 1 | Daily driver | A player can level and run a dungeon with the default UI fully replaced. **First public alpha.** |
| 2 | Combat | A healer and a tank can raid with it: warnings, meter, threat and healer indicators work under combat restrictions |
| 3 | Questing | A fresh character can level 1 to 60 using only Perennial's quest and travel tools |
| 4 | Group, gear, economy | Group finding, raid tools, upgrade scoring and auction tools are usable. **Beta.** |
| 5 | Extras and Classic Era | Class and hardcore helpers, controller layout, Classic Era flavor. **1.0.** |

## Phase 0: Foundation

Status: in progress.

| Work item | State | Notes |
| --- | --- | --- |
| Repo, licence, CI, release pipeline, contributor docs | Done | Release pipeline is untested until the first tag |
| Namespace, event bus, safety net | Done, tested | |
| Module registry: register, enable, disable, pause, per-module settings | Done, tested | |
| Saved variables: schema migrations, defaults, profiles, share strings | Done, tested | |
| Theme tokens and seasonal palettes | Done, tested | Palettes are a first pass; font not chosen |
| Combat lockdown queue | Done, tested | |
| Compat layer and hidden-value guard | Done, tested against a stub | **Needs verifying in the live client** |
| Slash commands: config, help, move, test, safe, bug, undo, modules, enable, disable | Done, tested | |
| First in-game load on client 1.60.1 | **To do** | Nothing has been run in the game yet |
| API reference generated from the live client (`/apiexport`) into `tools/api/` | To do | Needed before any frame work |
| Widget kit: panel, button, checkbox, slider, picker, scroll area, text input, all themed | Written, **not yet run in game** | The picker cycles through choices; a real dropdown list and rounded corners are still to do |
| Settings window: resizable, searchable, simple/advanced, pinned pages | Written, **not yet run in game** | Logic tested against the stub. Pages come from each module's `settings` declaration |
| Settings undo and change history | Done, tested | Session only; `/pui undo` and the History page |
| Profile management in the window: create, copy, delete, import, export | To do | The window can only switch profile today |
| Layout mode: drag handles, grid snap, saved positions, combat queue | Written, **not yet run in game** | Logic tested against the stub. Keyboard nudging is still to do |
| Mover registry so any module can make its frame draggable | Done, tested | `self:RegisterMover` |
| Sandbox module: movable panel, settings page, self-break button | Written, **not yet run in game** | The deliberately broken test module for the phase gate. `/pui enable sandbox` |
| Test mode plumbing (sample units and data) | To do | |
| Bug report window (copyable text) and debug/capability view | To do | `/pui bug` prints to chat today |
| First-login setup wizard: season, frame and nameplate style, placement | To do | Last, once there is something to place |
| Profile auto-switch by spec | To do | Check what "spec" means on Forever first |
| Share-string compression | To do | Vendor LibDeflate (zlib licence) if strings get long |
| Proof module: player and target frames from theme tokens | To do | Closes the phase |

## Phase 1: Daily driver

| Area | Capability |
| --- | --- |
| Frames | Unit frames: player, target, target-of-target, pet, focus, party, boss; class resources, auras, role and ready icons, range fade |
| Frames | Raid frames with incoming heals, shields and heal absorbs |
| Frames | Nameplates: designable, interrupt-coloured cast bar, threat, elite/boss/rare tags, targeting-you marker, own debuffs |
| Frames | Cast bars with latency zone, channel ticks and cast outcome |
| Bars and bags | Eight action bars, flexible layouts, mouseover and combat visibility, hover-to-bind |
| Bars and bags | Keybind backup and restore after a disconnect |
| Bars and bags | Single bag window: search, sort, item level, groups; offline bank view; alt counts in tooltips |
| Interface | Restyled minimap, info bar, XP bar, chat, tooltips (item level, target, IDs), quest tracker, buffs, menus |
| Foundation | Layout presets that also rearrange frames (our own names: Mender, Vanguard, Wayfarer, and so on; controller layout is Forever only) |

Decide before starting frames: build unit frames on oUF (MIT) or our own. Test oUF under Forever's hidden combat values first.

## Phase 2: Combat

| Area | Capability |
| --- | --- |
| Foundation | Frame designer: rearrange the parts inside a frame (name, bars, icons, text) |
| Frames | Healer indicators: HoTs, missing tank buffs, a low-health edge that works in combat |
| Combat | Dangerous-cast warnings, targeting-you alert, party and nearby cast lists (Forever only) |
| Combat | Combat HUD, swing timer, combat text, threat window |
| Combat | Damage meter: damage, healing, taken, interrupts, dispels, deaths; second window. Reads the game's own numbers on Forever, not the combat log |
| Combat | Safety alerts: low-health glow and sound, dangerous mobs, enemy count, death recap |
| Combat | Cursor rings: global cooldown, swing, cast |

## Phase 3: Questing

| Area | Capability |
| --- | --- |
| Questing | Quest automation: accept and turn in, stop at reward choices, modifier key to bypass |
| Questing | Leveling kit: quest-item bar, XP per quest, projected XP from turn-ins |
| Questing | Quest log helpers: full-log warning, count, grey-quest cleanup |
| Questing | Waypoints and arrow, map and minimap pins, flight timer, gathering memory, trainer helper |
| Questing | Custom quest tracker, quest cards, quest arrow, numbered minimap pins, zone route planner (Forever only) |
| Questing | Party quest sync between Perennial users |
| Gear and economy | Vendor helpers: sell junk, repair, restock, durability warning |

Quest and map UI are our own frames. We do not drive Blizzard's map or quest code, which taints.

## Phase 4: Group content, gear, economy

| Area | Capability |
| --- | --- |
| Interface | Restyled Blizzard windows (character, spellbook, merchant, mail, auction house, professions, guild and others), each optional (Forever only) |
| Group content | Group-finder board built from chat and Group Finder; post your own |
| Group content | Lockouts across characters, dungeon entrances on the map, boss and loot browser |
| Group content | Run log (time, bosses, wipes, loot, group) and best-kill pace (Forever only) |
| Group content | Raid prep checklist; raid tools: markers, ready and role check, pull timer, buff check |
| Group content | Group cooldowns and interrupts, dispel helper, boss notes, chosen spell alerts (Forever only) |
| Group content | Battleground helpers, honor and rank (Forever only) |
| Gear and economy | Upgrade scores by class and spec, arrows in bags, rewards and rolls, best quest reward marked |
| Gear and economy | Gear sets with equip-upgrades, outfit bar, uncollected-appearance markers (Forever only) |
| Gear and economy | Auction prices, full scan, deals, sell list with undercuts, price history |
| Gear and economy | Professions across characters, cooldowns, priced shopping list, skill-up advisor |
| Account | Alt overview, item and recipe finder across characters, farming gold per hour, mail rules (Forever only) |

Heavy data areas (economy, group content) are candidates for load-on-demand sub-addons. Decide when the first one is built.

## Phase 5: Extras and Classic Era

| Area | Capability |
| --- | --- |
| Forever extras | Hunter pet and stable helpers, clickable buff, ammo and reagent reminders, quest timers |
| Forever extras | Legacy challenge tracker, weapon skill caps, reputation pace |
| Forever extras | Hardcore rules and log, danger-zone warnings, controller layout |
| Classic Era | Quest levels, death recap, PvP flag guard, hardcore death feed, emergency bar |

Classic Era, Hardcore and Season of Discovery use a different API. The shims go in `Compat/`; nothing starts until Forever is solid.

## Releases

- `v0.x.y-alpha.n` from the Phase 1 gate, `-beta.n` from the Phase 4 gate, `v1.0.0` at the Phase 5 gate.
- Pushing a tag builds the zip and publishes to GitHub Releases. CurseForge and Wago uploads start once their project pages exist: add `X-Curse-Project-ID` and `X-Wago-ID` to the TOC and `CF_API_KEY` and `WAGO_API_TOKEN` to the repo secrets.

## Decisions

| Date | Decision |
| --- | --- |
| 2026-11-11 | Licence is GPL-3.0-or-later (was AGPL-3.0), to share code freely with the rest of the GPL addon ecosystem |
| 2026-11-11 | Own small core instead of Ace3. Single-purpose libraries may be vendored when needed |
| 2026-11-11 | Pull requests merge automatically once CI passes and a code owner approves. Contributors become code owners of the modules they maintain |
| 2026-11-11 | Seasons (spring, summer, autumn, winter) are the built-in theme system |
| 2026-11-11 | Logo is the growth-rings mark (a cut stump with a new shoot); sources in `branding/` |
| 2026-11-11 | One addon with internal modules for now; the repo layout allows sub-addons later |

## Open questions

- **Unit frames:** oUF or our own? Needs a test under hidden combat values.
- **Hidden values:** confirm the client's predicate for hidden values and exactly which fields are hidden, from the live `/api` export. `Compat.IsHidden` currently assumes `issecretvalue`.
- **`/pui`:** check that no popular addon already uses this slash command.
- **Shape language:** soft or crisp as the default? It is a token either way.
- **Font:** pick an openly licensed face that is distinct from other Forever UIs, and check its licence.
- **Outreach:** whether to tell the authors of the existing closed UIs that this project exists and is independent.
- **Spec switching:** what profile auto-switch should key on in a Classic-content client.
