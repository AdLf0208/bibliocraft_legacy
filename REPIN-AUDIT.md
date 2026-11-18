# Bibliocraft Legacy — re-pin audit against Horizon `83ad384f`

Read-only audit, 2026-11-05. **No port source, content, manifest or tool was
changed; no build, test or e2e was run.**

| | Old | New |
|---|---|---|
| Horizon | `c9d474dd9116e84c243f8992d75c11314df56f06` (108 hooks) | **`83ad384f48d0742746d518737511882680aab5b7`** (427 hooks, 159 helpers, `NATIVE_HOOKS_API = 409`) |
| horizon-mixins | `d9c83d7096b7ea5b83678da2efdfd6161f74997e` | **`e8cd0aa38cffef49cb2e088ef716baa107148c02`** |
| plan schema | 6 | 6 (unchanged) |

Sources: `ports/_shared/pins/horizon-83ad384f/native-hooks.json`,
`crates/horizon-client/src/**`, `crates/horizon-world/src/**`,
`docs/native-mods.md`, `docs/mods.md`, `crates/horizon-mods/src/content.rs`;
this port's `notes.md` and `../_shared/upstream/bibliocraft/FINDINGS.md`.

Classification: **usable** = a writable/cancellable hook or a helper exists;
**hook-only** = only a listen hook; **absent** = no hook/helper.

Method: each deferral in `notes.md`/`FINDINGS.md` was mapped to
`native-hooks.json` and the `horizon-client`/`horizon-world` helpers;
content-only items were checked in `horizon-mods`/`docs/mods.md`. The brief
states main `696d0216` has the same hook set; this audit uses the pinned
export.

## Re-pin safety

Slice 1 has **no injections** — the bundle has one test-only module
(`game::bibliocraft::tests`) and the content is in `content/`. Re-pin therefore
has no hook-signature risk. It still needs the campaign tool fix: the embedded
test target is `--lib` now, not `-p horizon-client --bin horizon-client`
(`tools/horizon.py:133-134` in this port runs the old form and would report
“0 tests” vacuously). `horizon-ctl` is now `-p horizon-client-lib --bin
horizon-ctl`. One online `cargo fetch --locked` for `zune-jpeg` is needed.

Content needs a rebuild only because this audit recommends new content fields
(`occludes`, multi-property `shapes`/`collision_shapes`), not because the
schema version changed. `mixin_schema` stays 6; `compatibility.json` needs the
new revisions and `game.rs` SHA-256
`996432b9f7f9461fa69c90ff798daf6b89fe3795f379d7c6f401916633296463`.

## Deferred features

| ID | Deferred feature (notes) | Best new-pin API (symbol, file:line) | Class | Verdict | Next step |
|---|---|---|---|---|---|
| C1 | Bookcase/shelf inventories (`notes.md:127-128`, `FINDINGS.md:64-65`) | `native_block_entity` `native_hooks.rs:2985`; `native_block_entity_container` `:3035`; `native_block_entity_tick` `:3122`; `native_block_entity_update_tag` `:3141`; `native_screen` `:3321`; `native_screen_draw` `:3331`; `native_screen_click` `:3802`; API 15/16/17/19/45 `docs/native-mods.md:189-204,359` | usable | **realizable now** — block entity, slots, hopper/comparator/break integration and a real GUI | Answer `native_block_entity` with the BE id/compound and `native_block_entity_container` with the slots + content menu; declare `data/bibliocraft/horizon/menu/{bookcase,shelf}.json`, then draw with `native_screen`. Start with the shelf’s 2×2 inventory, then the bookcase’s larger one. |
| C2 | Bookcase/shelf comparator output (`notes.md:127-128`) | `native_has_analog_output` `native_hooks.rs:1539`; `native_analog_output` `:1555`; `native_mod_block_entity` `native_host_bridge.rs:27` (read the BE at `pos`); API 64/18 `docs/native-mods.md:821` | usable | **realizable now** | Answer from the block entity’s stored fill (upstream’s comparator formula); read it with `native_mod_block_entity` inside the `&self` comparator hook. E2E: fill slots → comparator 0…15. |
| C3 | Bookcase/shelf enchanting bonus (`notes.md:127-128`) | `native_prepare_item_enchant` `native_hooks.rs:5597` (mutable `costs: &mut [i32; 3]`); `native_enchant_item` `:5586`; API 291 `docs/native-mods.md:1460` | usable | **realizable now** (approximation: costs, not a `getEnchantPowerBonus` value) | When an enchanting table at `pos` is near bookcases, add the upstream bonus to the three costs. Read the upstream formula first; do not guess it. |
| C4 | Seat entity, riding, seat back, occupied (`notes.md:127-132`, `FINDINGS.md:66-68`) | `native_summon` `native_entities.rs:141`; `native_entity_mount` `native_hooks.rs:7296` (cancel/observe); `native_entity_tick_pre/post` `:7336,7350`; `native_move_entity` `native_entities.rs:192`; `native_run_command` `native_server.rs:479` from `server_tick`; custom entity types only copy `minecraft:snowball` (`docs/mods.md:301-317`) | usable approximation; **custom SeatEntity absent** | **partial** — a vanilla mount (armor stand/marker/cushion) + queued `/ride` can sit a player, but there is no `bibliocraft:seat` entity type | Defer the faithful entity. Prototype: right-click summons a marker/armor stand, `server_tick` runs `/ride <player> mount <entity>`, `entity_tick`/`move_entity` keeps it in the seat, dismount removes it and drops the seat item. Probe `/ride` first; record every divergence. |
| C5 | Seat `occupied` redstone/comparator (`notes.md:127-132`) | `native_has_analog_output` `native_hooks.rs:1539`; `native_analog_output` `:1555`; `native_set_block_property` `:8634` (Game) / `:8303` (level ticks); API 64/18 | usable | **realizable now** | Set `occupied=true` when the seat is ridden and `false` on dismount; answer comparator 15. Only the entity part (C4) is approximate. |
| C6 | Seat-back drop on break (`FINDINGS.md:66-68`) | `native_loot_drops` `native_hooks.rs:7458`; or `native_block_entity` + `native_item_spawn` `:5538`; API 75/40 | usable | **realizable now** | Add the seat-back stack to the seat’s loot when a seat block with `occupied`/its BE is broken, or spawn it from the BE’s removal path. E2E: break occupied seat → seat + back. |
| C7 | Desk bell rings on use (`notes.md:129-132`, `FINDINGS.md:69-71`) | `native_use_item_on` `native_hooks.rs:6482` (claim) or `native_right_click_block` `:6790`; `native_play_sound` `:8193`; own sound events API 61 `docs/native-mods.md:813`; API 13/21/25 | usable | **realizable now** | `use_item_on`/`right_click_block` plays `bibliocraft:desk_bell` at the block; no custom BE needed. Carry the four `.ogg` files + `sounds.json` as content. |
| C8 | Desk bell rings on redstone (`notes.md:129-132`) | `native_neighbor_changed` `native_hooks.rs:1314` (listen); `native_neighbor_signal` `:8501`; `native_play_sound` `:8193`; API 25 | usable | **realizable now** | On a neighbour change below the bell, read `native_neighbor_signal`; ring on the rising edge. Keep a per-position last-state map so a held signal rings once. |
| C9 | Table shape/collision depends on `type` × `facing` (`notes.md:133-136`, `FINDINGS.md:61-63`) | content `BlockShapes` with `properties: ["type","facing"]` and `values` tuples — `crates/horizon-mods/src/content.rs:150,237,271`; `docs/mods.md:173-203` | usable (content-only) | **realizable now** — the “one template property” limit is gone; the schema accepts an ordered property tuple **and** an independent `collision_shapes` table | Replace the deferred table approximation in `tools/gen_content.py` with a `shapes` + `collision_shapes` declaration keyed by `type,facing`; rebuild the `.hmod`; e2e every combination. No native code. |
| C10 | Table item + carpet display (`notes.md:133-136`) | `native_block_entity` `native_hooks.rs:2985`; `native_block_entity_submit` `:3190`; `native_draw_item` `native_block_entity_draw.rs:719`; `native_block_entity_update_tag` `:3141`; API 15/45/71 `docs/native-mods.md:850-860` | usable | **realizable now** | Add a one-item BE with `native_draw_item` for the stored item/carpet; sync the visible item with `update_tag`. The table’s placement `type` recompute is pure logic + `set_block_property`. |
| C11 | Waterlogged placement/fluid logic (`notes.md:137-141`, `FINDINGS.md:76-78`) | `native_state_for_placement` `native_hooks.rs:1727` (gets `fluid: FluidState`); `native_state_with_property` `:8372`; `native_fill_bucket` `:6840`; `native_bucket_empty` `:4399`; `native_fluid_level_change` `:1214`; API 76/21 | usable (placement state); **full vanilla fluid-state integration absent** | **partial** — placing in water can set `waterlogged=true`; bucket fill/empty and flow can be approximated with hooks, but content blocks have no `SimpleWaterloggedBlock` fluid state | Implement placement waterlogging first (`state_for_placement` + `state_with_property`); then bucket and flow hooks if needed. Record the fluid-state divergence. |
| C12 | Occlusion is the template’s (`notes.md:142-146`) | content `occludes: false` — `crates/horizon-mods/src/content.rs:95`; `docs/mods.md:116-120` | usable (content-only) | **realizable now** — the field exists and is tested in `content.rs:1596-1606` | Add `"properties": { "occludes": false }` (or the block-level equivalent used by the generator) to the four blocks; rebuild. This closes the “neighbour faces culled” deviation with no code. |
| C13 | One wood type, one seat colour (`notes.md:147-148`) | content-only; no API | usable (content) | **realizable now** | Generate the 11 wood sets / 15 colours with the same templates and the recipe/loot/tag matrix; no native code. Do it after C9/C12 so the generator changes land once. |
| C14 | Seat carries an extra `axis` state (`notes.md:149-152`) | content state declarations + `native_state_for_placement` `native_hooks.rs:1727`; API 76 | usable (content + one placement hook) | **realizable now** | Use a no-state template and declare only the seat’s real `occupied`/`waterlogged` properties (plus `shapes` and `occludes:false`); the seat is not directional, so there is no `facing` to set. This removes the 3 unreachable `axis` states. Lower priority than C1–C3. |
| C15 | No sounds/particles/animations (`notes.md:156-157`) | `native_play_sound` `native_hooks.rs:8193`; `native_play_local_sound` `:8782`; `native_send_particles` `:8233`; API 25/83/11 | usable | **realizable now** | Carry `sounds.json` + the `.ogg` files; use `native_play_sound` for the bell and any block sounds (sound events of the mod’s own namespace are API 61). |

## Summary

- **Deferred features audited: 15** — C1–C15 cover the eight `notes.md` gap
  bullets, with the bookcase/shelf functionality and the seat split into the
  actions that need separate evidence.
- **Realizable now: 13** — C1, C2, C3, C5, C6, C7, C8, C9, C10, C12, C13, C14,
  C15.
- **Newly opened by `83ad384f`:** **C9 (multi-property shapes +
  `collision_shapes`) and C12 (`occludes`) are content-only and fully closed**;
  **C11 (placement waterlogging) is newly partial** via `state_for_placement`;
  **C3 (enchanting costs) is newly opened** by `native_prepare_item_enchant`
  (API 291), which the 108-hook pin did not have. C1/C2/C7/C8/C10/C15 were
  feasible scope at the old pin (APIs 15–64); the new pin’s menu/screen/block-
  entity documentation and helpers make them straightforward. Treat them as
  “practical now,” not “newly invented.”
- **Partial: 2** — C4 (no custom `SeatEntity`; vanilla-mount approximation) and
  C11 (no true fluid state).
- **Still blocked: 0.**
- **Highest-value next step:** **C1+C2+C3, the functional bookcase/shelf** —
  block entity + container + menu/screen + comparator + enchanting bonus. It
  turns the mod’s signature furniture from decoration into its actual feature
  and reuses one BE across three of the remaining gaps.
  Before that, land **C9+C12** as a content-only commit: they need no native
  code, remove two long-standing “schema cannot express it” blockers, and
  rebuild the same `.hmod` the bookcase work will touch.

## Gotchas found while reading

- The content `shapes` table now takes an **ordered tuple** of properties, e.g.
  `"properties": ["type","facing"]`, with comma-separated `values` keys; the
  legacy single-`property` form still works but cannot express the table. The
  schema also has an independent `collision_shapes` table. See
  `crates/horizon-mods/src/content.rs:150-203` and its test at `:1175`.
- `occludes: false` is a real content field (`content.rs:95`), not
  `noOcclusion`; the docs call out that it also changes light behaviour
  (`docs/mods.md:116-120`). Do not set it on a block that should still block
  light like stone.
- Custom entity types at this pin copy only `minecraft:snowball`
  (`docs/mods.md:301-317`), so the seat cannot be a content entity. The
  `native_entity_mount` hook only hears/cancels; forcing a player to ride
  needs the `/ride` command from `server_tick` (`native_run_command` is refused
  inside a player hook, `native_server.rs:476-478`).
- `native_screen` is keyed by the **block**, not the menu type; the screen and
  the menu must agree on the slot count and order. `native_menu_button_v2`
  (`native_hooks.rs:3841`) is the server-side button path, with the carried
  stack mutable.
- The bookcase’s loot copies `custom_name` from its BE upstream; with a BE this
  is now possible — read the name in `loot_drops` and stamp the dropped stack,
  rather than dropping the copy as slice 1 does.
