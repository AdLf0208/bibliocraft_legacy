# Bibliocraft Legacy — port notes

Ported from **Bibliocraft Legacy 26.1.2-1.7.1**
(`MinecraftschurliMods/Bibliocraft-Legacy`, branch `main`, commit
`3572b71fed1429556068173c51308be5dff9d33b`, tag `26.1.2-1.7.1`,
`gradle.properties`) for Minecraft 26.3. Originally a `.hnmod` bundle at
Horizon **c9d474d** / **83ad384f**; since **2026-11-18** one flat SDK package
(mod API 0.2), now at SDK nightly
**`0a875da91dbb0fdcb7ba8c42c11341aa229af51a`** / mixins
**`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`**, version **0.2.3** — see
[`## Migration to the SDK format`](#migration-to-the-sdk-format-020-2026-11-18)
for the container change and
[`## Slice 2`](#slice-2--the-bookcase-and-the-shelf-are-storage-023-2026-11-21)
for the storage family.

**Licence: MIT** (`LICENSE`, `gradle.properties:license.name=MIT`). The port is
**local-only until publishing is approved** (ARCHITECTURE.md §8): the upstream
models and lang are MIT, but the campaign does not publish without the
maintainer's explicit approval.

Status: **ported** — slice 1 (four decorative furniture blocks) and slice 2 (the
bookcase and the shelf as storage: block entities, content menus, the
redstone-book comparator, hopper access, the spill on break, and the
`redstone_book` item) are implemented, packaged at 0.2.3 and **run in game** on
a launcher-built `0a875da` game (`tools/e2e.sh`: `PASS` + `EXIT:0`; a vanilla
barrel counterfactual at `EXIT:0`; `SELFTEST=1` at `EXIT:1`). The seat entity,
the desk bell's bell sound and redstone answers, the table, the other wood types
and seat colours, and the bookcase's enchanting-table bonus are still open (see
Gaps).

## Slice 1

| id | template | states | shape |
|---|---|---|---|
| `bibliocraft:oak_bookcase` | `minecraft:white_glazed_terracotta` | `facing` × `waterlogged` = **8** | six boxes per facing |
| `bibliocraft:oak_shelf` | `minecraft:white_glazed_terracotta` | `facing` × `waterlogged` = **8** | one wall box per facing |
| `bibliocraft:black_oak_seat` | `minecraft:oak_log` | `axis` × `occupied` × `waterlogged` = **12** | ten-box stool |
| `bibliocraft:desk_bell` | `minecraft:mangrove_roots` | `waterlogged` = **2** | eight boxes |

### Why these templates

The content schema's `shapes` selector reads **one template state property**
(`horizon-mods/src/content.rs`'s `BlockShapes`; `horizon-client/src/mod_content.rs`
rejects a property the template state lacks). The four blocks were chosen so
that the upstream shape's varying property is already a template property:

- `minecraft:white_glazed_terracotta` is a plain vanilla block with exactly
  `facing` (four horizontal values), the **same placement rule** as upstream
  `BCFacingBlock` (`getHorizontalDirection().getOpposite()`,
  `BCFacingBlock.java:24-26`), no support requirement, no block entity, no GUI
  and no special interaction. `waterlogged` is declared beside it, so the port
  has exactly upstream's 8 bookcase/shelf states. (Carved pumpkin has the same
  state/placement but a golem-pattern check on placement; glazed terracotta
  avoids that side effect.)
- `minecraft:oak_log` has exactly `axis` (x/y/z), no other states, no support
  requirement, no block entity and no GUI. Its name sorts before the declared
  `occupied`, so the declared `occupied`/`waterlogged` properties fan out
  after the template state and the registry's state order stays valid. The
  seat is not directional, so the extra `axis` state is a documented template
  artefact; all upstream `occupied` × `waterlogged` combinations are present
  (3 × 2 × 2 = 12 states).
- `minecraft:mangrove_roots` has exactly `waterlogged`, no other states, no
  support requirement and no block entity; the desk bell has the template's 2
  states. It cannot host the seat's declared `occupied`: `occupied` sorts
  before the template's `waterlogged`, and `mangrove_roots`'s waterlogged
  state order is `true,false`, which the content state-order fan-out rejects
  at load (`registry state order differs from vanilla's state definition`).
- `minecraft:end_rod` was the other candidate for the facing blocks, but it
  has six `facing` values (including up/down), which would add two unreachable
  states. `white_glazed_terracotta` keeps the state space exact.

### Shapes

The boxes are transcribed from upstream and rotated with the same clockwise
quarter-turn (`ShapeUtil.rotate`):

- bookcase north: `0.0625,0,0.5..0.9375,0.0625,0.9375`,
  `0,0,0.9375..1,1,1`, `0.0625,0.9375,0.5..0.9375,1,0.9375`,
  `0.0625,0.4375,0.5..0.9375,0.5625,0.9375`,
  `0.9375,0,0.5..1,1,0.9375`, `0,0,0.5..0.0625,1,0.9375`
  (`BookcaseBlock.java:22-28`);
- shelf north: `0,0,0.5..1,1,1` (`ShelfBlock.java:20`);
- seat: the ten boxes at `SeatBlock.java:30-39`;
- desk bell: the eight boxes at `DeskBellBlock.java:30-38`.

The `shapes` declaration is keyed by `facing` for the bookcase/shelf, by
`axis` for the seat (the same box for x/y/z) and by `waterlogged` for the
desk bell (the same box for both waterlogged values). The runtime model's
tests pin the exact boxes and the rotation.

### Items, drops, recipes, tags, tab

- One block item per block (`item: true`); the bookcase/shelf/seat use the
  upstream generated block model as their item model, the desk bell its
  upstream model.
- Self-drop loot tables with `minecraft:survives_explosion`. The upstream
  bookcase/shelf loot also copied `custom_name` from the block entity; this
  port has no block entity, so the copy is omitted.
- Recipes carried from upstream: bookcase (`PSP/PSP/PSP`), shelf
  (`SSS/P/SSS`), seat (` W / S /RSR`, `#c:rods/wooden`) and desk bell
  (` B / I /IRI`, `#c:ingots/iron`, `#c:dusts/redstone`).
- Tags: `bibliocraft:bookcases`, `bibliocraft:shelves`,
  `bibliocraft:seats` (block and item), wood in
  `minecraft:mineable/axe`, desk bell in `minecraft:mineable/pickaxe`.
- The three convention tags the recipes need (`c:rods/wooden`,
  `c:ingots/iron`, `c:dusts/redstone`) are supplied because 26.3 ships no `c`
  tags.
- One creative tab, `Bibliocraft`, icon `oak_bookcase`, listing the four items
  (upstream `BCCreativeTabs.java:19-95`; Horizon content mods cannot insert
  into vanilla tabs).

## Slice 2 — the bookcase and the shelf are storage (0.2.3, 2026-11-21)

The gap this closes is the port's own (`## Deviations and gaps` 1):

> The bookcase and shelf have no inventory, comparator output or enchanting
> bonus (`BookcaseBlock.java:39-75`, `ShelfBlock.java:29-52`) … These need
> block entities, an entity, a menu or a sound hook and are later slices.

Upstream, read again at the pinned tag (clone at `/tmp/opencode/bc-upstream`,
deleted after the findings were recorded; the commit is the same one
[`## Upstream source`](#upstream-source) names):

| area | file | extracted |
|---|---|---|
| bookcase entity | `content/bookcase/BookcaseBlockEntity.java` | `SLOTS = 16`, `isValid` = `#bibliocraft:bookcase_books`, `defaultName("bookcase")`, one item per slot |
| bookcase block | `content/bookcase/BookcaseBlock.java:49-75` | `hasAnalogOutputSignal` true; `getAnalogOutputSignal` scans **15 → 0** for a `RedstoneBookItem` and answers that **slot index**; `getEnchantPowerBonus` adds `0.125f ×` non-empty slots |
| bookcase menu | `content/bookcase/BookcaseMenu.java` | two rows of eight slots at `(17 + j·18, 17 + i·25)`, the player inventory at `(8, 84)` |
| shelf entity/menu | `content/shelf/ShelfBlockEntity.java`, `ShelfMenu.java` | 4 slots, **no** filter, no comparator; a 2 × 2 grid at `(53/107, 15/53)` |
| redstone book | `content/redstonebook/RedstoneBookItem.java`, `init/BCItems.java:102` | a plain `Item`, `stacksTo(1)`, always foiled; its lang text states the scale: slot 1 (top left) no signal, slot 2 → 1, … slot 16 (bottom right) → 15 |
| book tag | generated `data/bibliocraft/tags/item/bookcase_books.json` | `#minecraft:bookshelf_books` + `#minecraft:lectern_books` + optional foreign guide books |
| recipes | `data/bibliocraft/recipe/redstone_book.json` | shapeless: `minecraft:book` + `minecraft:redstone_torch` |

### What ships (0.2.3)

- `bibliocraft:oak_bookcase` — a **16-slot** block entity (`bibliocraft:bookcase`),
  every face reachable by hoppers, a content menu `bibliocraft:bookcase`
  (`data/bibliocraft/horizon/menu/bookcase.json`), books only
  (`#bibliocraft:bookcase_books`), and a comparator answer = the highest slot
  index holding a `bibliocraft:redstone_book`.
- `bibliocraft:oak_shelf` — a **4-slot** block entity (`bibliocraft:shelf`), no
  filter, no comparator, menu `bibliocraft:shelf`.
- `bibliocraft:redstone_book` — one per stack, glinting (`minecraft:enchantment_glint_override`),
  on vanilla's book item model, crafted shapeless; added to the creative tab and
  to `#bibliocraft:bookcase_books` and `#minecraft:bookshelf_books`.
- Both storage blocks **spill** their contents when broken and drop themselves,
  which is a container's behaviour in vanilla and upstream's (`Block.popResource`
  of each slot); a plain bookcase item placed again is empty.

### The four routes this slice had to find (each measured)

1. **The menu is opened by the mod, not the engine.** `Registrar::block_container`
   declares the container and its content menu, but at `0a875da` the engine's
   plain-click path (`game.rs::open_menu` → `open_mod_menu`) does **not** open a
   mod block's content menu: a vanilla barrel beside a bookcase opened 27 slots
   from the same click, the bookcase opened none (probe run
   `biblio-probe2`). The proven route (`rftoolsstorage`, `functionalstorage`,
   both green in game) is `Hooks::right_click_block` → `Player::open_menu(server,
   entity)`; both of those ports open their own menus that way, which is why
   their legs pass. `support::right_click_block` does the same, cancelling the
   click on both sides so a held item is not used behind the menu.
2. **The comparator answer needs a cache.** `BlockPart::analog_output` is given a
   level host only, which cannot read a block entity, so the tick reads the slots
   and stores the answer in glue (`support::Core::signal`), and
   `level_tick_post` asks the neighbours of a changed bookcase to re-read
   (`Level.updateNeighbourForOutputSignal`) — the pattern `functionalstorage`
   proved at this pin. The cache is aged by that same tick clock and does not
   grow without bound.
3. **A broken container spills by the engine's own path.** `spill.rs:485`
   (`BaseContainerEntity.preRemoveSideEffects` → `Containers.dropContents`)
   already spills a mod container's contents on removal. The port therefore
   writes **no** `minecraft:block_entity_data` payload: the contents are on the
   ground, and carrying them twice is not upstream's behaviour either. (The
   `block_drops` route ARCHITECTURE.md §3 documents is for a storage block whose
   contents would otherwise vanish; here they do not.)
4. **The filter is enforced in the tick.** `ModContainer` has no per-slot filter
   and no per-slot stack limit, so a non-book that reaches a bookcase slot
   through a hopper is handed back by the tick (with the stack spawned at the
   block, as `Block.popResource` would) — upstream's `isValid` refuses it at
   insert time; the visible difference is one tick.

### Red → green

The pure rules were written first and failed to compile: **25 `E0425` errors**
for `slots`, `menu`, `signal`, `enchant_power`, `BOOKCASE`, `SHELF` and
`BOOKCASE_SLOTS` (`../_shared/evidence/bibliocraft/runtime-tests-red.log`:

```
error[E0425]: cannot find function `signal` in this scope
   --> src/runtime.rs:426:20
error[E0425]: cannot find function `enchant_power` in this scope
   --> src/runtime.rs:439:20
error: could not compile `bibliocraft` (lib test) due to 25 previous errors
TEST_EXIT:101
```

The enchanting-power rule was then **dropped from the slice** (see Gaps: the
hook is never dispatched at this pin), so the shipped rules are `slots`,
`menu` and `signal`, plus the two container tests in `support`) — 18 tests now.

In game, four red runs found four facts before green:

| red | what it taught | fix |
|---|---|---|
| `FAIL: the unmodded game placed a Bibliocraft block` (control leg) | the control cell at `40 80 20` is a hillside in a fresh Overworld, not air | probe `40 200 20`, and assert the cell is air first |
| `FAIL: no container menu opened at 8,80,16 (screen=playing)` | the engine does not open a mod content menu from a plain click (route 1 above) | `right_click_block` + `Player::open_menu` |
| `FAIL: the click on 11,79,16 failed` | the chest is in the floor; its reachable face is `up`, not `south` | click the top face |
| `FAIL: the replaced bookcase holds 0 books, expected the 2 it was broken with` | the engine already spilled the books as loose item entities (route 3) | assert the spill, not a carried payload |

### In-game evidence (0.2.3, launcher-built `0a875da`)

`../_shared/evidence/bibliocraft-e2e/` — `e2e.log` (`PASS` + `EXIT:0`),
`e2e-counterfactual.log` (`COUNTERFACTUAL=1`, `EXIT:0`), `e2e-selftest.log`
(`SELFTEST=1`, `EXIT:1`), `check-e2e-logs.py --strict` 3/3. The phases this
slice adds, with the values the run printed:

| assertion | value in the log |
|---|---|
| the bookcase's menu shows its container slots | `bookcase menu slots: 16` |
| a book goes into slot 5 through the menu | `slot 5 (300+5) holds a plain book` |
| a plain book answers no comparator | `wire power with a plain book in slot 5: 0` |
| a redstone book in slot 4 answers 3 | `wire power with a redstone book in slot 3: 3` |
| the same book in slot 1 answers 0 (the book's own scale) | `wire power with the redstone book in slot 1: 0` |
| the bookcase hands a stone back | `slot 309 is empty again: the bookcase refused the stone` |
| a hopper above fills it | `books in the bookcase after the hopper: 3` |
| a hopper below empties it into a chest | `books in the chest: 3` |
| the shelf's menu is 4 slots and it keeps a stone | `shelf menu slots: 4`, `the shelf kept the stone the bookcase refuses` |
| a broken bookcase spills its books and drops itself | `books in the break reply: 2`, `on the ground 2, carried 0` |
| the item placed again is empty | `books in the replaced bookcase: 0` |

The comparator assertions are read from the **wire's own `power` state**, not
from the port's code: a comparator at `x+1` facing west reads the bookcase at
`x` (`diode_input_signal` reads `pos + facing`) and drives a wire at `x+2`.

### Traps this slice cost (for the next agent)

1. **`ctl select 0` is refused** — hotbar slots are 1..9 (`agent.rs:1440`); a
   `clear @s` leaves an empty hand anyway.
2. **`ctl break`'s reply lists the spilled contents** (`"drops":{"bibliocraft:oak_bookcase":1,"minecraft:book":2}`),
   which is the engine's own report — but a spilled stack that lands at the
   player's feet is picked up on the next tick, so count ground **and**
   inventory.
3. **`ctl interact` needs the face a player can reach.** A block inside the floor
   is clicked on `up`.
4. **The control leg's probe cell must be air in a fresh world**; `40 80 20` is
   a hillside. `y = 200` is air in every Overworld.
5. **A content-menu assertion needs `--offscreen`** (trap #21 of HANDOVER §9d);
   these legs launch `--offscreen`, never `--headless`.

## Hooks

Slice 1 answered no game moment (one `impl Hooks` with no method). Slice 2
answers three, and everything else that belongs to one block or one block entity
is a **Part** attached to its type (`support.rs`):

| hook / Part moment | what it does | upstream counterpart |
|---|---|---|
| `Hooks::register` | the two block-entity types, their containers (16 / 4 slots, every face, the menu each opens) and each type's Part | `BCBlockEntities.BOOKCASE`/`SHELF`, `Capabilities.ItemHandler.BLOCK` |
| `Hooks::right_click_block` | a click opens the block's content menu (`Player::open_menu`) | `BookcaseBlock.useWithoutItem` → `getMenuProvider` |
| `Hooks::level_tick_post` | a changed bookcase's neighbours re-read its comparator answer | `Level.updateNeighbourForOutputSignal` |
| `BlockPart::has_analog_output` / `analog_output` | the comparator reads the highest redstone book's slot index | `BookcaseBlock.hasAnalogOutputSignal`/`getAnalogOutputSignal` |
| `BlockEntityPart::block_entity_ticks` / `block_entity_tick` | size the slots once, hand back a non-book, note the comparator answer | `EntityBlock.getTicker`, `isValid` |
| `BlockEntityPart::screen` | the menu's slot layout (2 × 8 / 2 × 2) | `BookcaseMenu.addSlots`, `ShelfMenu.addSlots` |

No `[[injection]]` ever existed, in either format; the `[[module]]` plan is gone
with the SDK format.

## Content (`.hmod`)

The content is the package root since 0.2.0 (`assets/bibliocraft/`,
`data/`); at 0.1.0 it was the `content/` root of the retired split package. The
generator `tools/gen_content.py` copies the upstream MIT models (bookcase,
shelf, seat, desk bell and their `template/*` parents), the four item
definitions, the four recipes and the five lang keys, then writes the 26.3
block declarations, blockstates, loot tables, tags and creative tab. The
bookcase/shelf/seat models reference **vanilla** plank/wool textures and the
desk bell references vanilla iron/stone, so this slice ships **no textures of
its own**.

The only upstream rewrite is the removal of NeoForge's `"type":
"bibliocraft:…"` key from the blockstate variants (26.3 uses plain
`model`/`x`/`y`/`uvlock`).

## Deviations and gaps

1. **Storage ported (slice 2); the rest is not.** The bookcase's 16 slots, its
   book filter, its menu, its comparator answer and the contents a broken one
   spills are in (see `## Slice 2`), and so is the shelf's 4-slot menu. Still
   open: the bookcase's **enchanting-table bonus** (`blocked`, Gaps below), the
   seat does not spawn a `SeatEntity` and does not drop a seat back above
   (`SeatBlock.java:74-145`), and the desk bell does not ring on use or on a
   redstone signal (`DeskBellBlock.java:49-62`). Those need an entity and a
   sound hook and are later slices.
2. **Table deferred.** Its collision depends on `type` *and* `facing`
   (`TableBlock.java:89-107`), and the content `shapes` selector can only read
   one template property, so a faithful table needs a native block shape path.
   It is not approximated.
3. **Waterlogged is a declared state, not fluid logic.** The state binds and
   reads back, but the content block does not implement
   `SimpleWaterloggedBlock`'s placement/fluid behaviour, so placing it in
   water does not set `waterlogged=true` automatically. This is a content
   template-class limit (the template supplies the state, not the interface).
4. **Occlusion is the template's.** Upstream marks the bookcase, shelf, seat
   and desk bell `noOcclusion()`; the content schema has no `no_occlusion`
   field, so they inherit the full-cube occlusion of
   `white_glazed_terracotta`/`oak_log`/`mangrove_roots`. Shapes, light and sounds are
   correct; only neighbour-face culling differs.
5. **One wood type and one seat colour.** Slice 1 carries only `oak` and
   `black`; the other 11 wood types and 15 colours are deferred.
6. **The seat carries an extra `axis` state.** The seat uses the `oak_log`
   template to keep the declared `occupied`/`waterlogged` fan-out valid; the
   upstream seat has no `axis`, so `axis=x/y/z` are three extra states. The
   model and shape ignore the axis; the e2e binds all 12 states.
7. **Desk bell requires a pickaxe** (`requires_tool: true`, copied from
   `Blocks.IRON_BLOCK`); the wood blocks drop by hand and are in
   `minecraft:mineable/axe`.
8. **No sounds, particles or animations** are carried. The desk bell's four
   `.ogg` files and `sounds.json` entry are deferred with the sound hook.
9. **One item per bookcase slot is not expressible.** Upstream gives the
   bookcase `slotCapacity 1`; `ModContainer` has no per-slot limit, so a slot
   takes the item's own stack size. A book stack in one slot still answers the
   comparator by that slot's index, and the menu is unchanged.
10. **The book filter is one tick late.** Upstream's `isValid` refuses a
    non-book at insert time; the tick hands it back instead (one tick later,
    spawned at the block). A hopper therefore cannot permanently fill a
    bookcase with stone, but it moves the stack in and out.
11. **The enchanting-table bonus is not ported (`blocked`).**
    `BookcaseBlock.getEnchantPowerBonus` adds `0.125` per non-empty slot. The
    SDK declares a `enchant_power_bonus` BlockPart hook, but the game at
    `0a875da` **never dispatches it**: `grep -rn "enchant_power_bonus"
    horizon/crates --include=*.rs` finds nothing, and the enchanting table
    counts blocks in `#minecraft:enchantment_power_provider` instead
    (`game/stations.rs:645-676`, `count_bookshelves`). The hook's host is a
    `&dyn Host`, which cannot reach a level or a block entity (`levels()` is a
    server-only service), so the count could not be read either. The bookcase is
    deliberately **not** in that provider tag: the tag is static, so an *empty*
    bookcase would be worth a whole bookshelf. The in-game leg asserts the gap
    (`info.bookcases` stays 0 behind a full bookcase and 1 behind a vanilla
    bookshelf) so it fails the day the pin consults the hook.

Skills: superpowers/using-superpowers, brainstorming, writing-plans, test-driven-development, systematic-debugging, verification-before-completion; BeautifulRust/rust-best-practices, rust-port

## Verification (0.2.3)

The full ladder, its commands and every line of output are in
[`VALIDATION.md`](VALIDATION.md); the evidence files live in
`../_shared/evidence/bibliocraft/` (ladder) and
`../_shared/evidence/bibliocraft-e2e/` (the game legs), and every log prints the
`SIZE`/`SHA256`/`VERSION`/`PIN` it ran against. The headline:

| check | result |
|---|---|
| `cargo test --offline` | **18 passed, 0 failed** (`sdk-test.log`) |
| `cargo clippy --all-targets -- -D warnings` | exit 0, 0 warnings (`sdk-clippy.log`) |
| `cargo fmt --check` | exit 0 (`sdk-fmt.log`) |
| two builds after `rm -f Cargo.lock` | **`cmp`-identical**, 41,697 B, SHA-256 `fe1eba2d…6185` |
| `cargo horizon-mod check` | `bibliocraft 0.2.3 (native-mod, format native-1/0a875da…/e59da90…, for 26.3)`, exit 0 (`sdk-check.log`) |
| `fits --build 0a875da` | `0a875da  made for`, exit 0 (`sdk-fits.log`) |
| `fits --build 0b14f8a` | `0b14f8a  fits`, exit 0 (`sdk-fits-other.log`) |
| `verify-sdk-package.py bibliocraft` | **1/1** (runtime byte-identical, no `Cargo.lock`, 56 entries) |
| `tools/e2e.sh` | `PASS` + `EXIT:0` (`e2e.log`) |
| `COUNTERFACTUAL=1 tools/e2e.sh` | `PASS (counterfactual)` + `EXIT:0` |
| `SELFTEST=1 tools/e2e.sh` | `FAIL: SELFTEST: expected the bookcase menu to show 27 slots, found '16'` + `EXIT:1` |
| `check-e2e-logs.py bibliocraft-e2e --strict` | 3/3 |

The two false paths the ladder had to avoid: the first package builds at this
version reported `fits --build 0b14f8a` failing on a local `Block` type (fixed
by the `Piece` rename), and the `open_mod_menu` route was dead in game (see
[`## Slice 2`](#slice-2--the-bookcase-and-the-shelf-are-storage-023-2026-11-21),
route 1).

## Verification (0.1.0, historical)

> **Historical since 2026-11-18.** Everything in this section was measured for
> the retired `.hnmod` bundle (0.1.0) and its `content/` dev-mod root, at Horizon
> `83ad384f` / mixins `e8cd0aa3`. The format changed (Horizon's mod-API merge
> #16941); the *behaviour* evidence below still stands, the *commands* do not.
> The SDK package's own ladder is in
> [`## Migration to the SDK format`](#migration-to-the-sdk-format-020-2026-11-18).
> **The 0.1.0 e2e logs were scratch files under `/tmp/opencode/` and are gone**
> (checked 2026-11-18); the run results recorded below are what survives, and no
> in-game claim about the SDK package is made anywhere.

### Runtime (standalone crate)

| Check | Command | Result |
|---|---|---|
| fmt | `cargo fmt --all -- --check` | exit 0 |
| tests | `cargo test --locked --offline` | **11 passed**, 0 failed |
| clippy | `cargo clippy --all-targets --locked --offline -- -D warnings` | exit 0, **0 warnings** |

TDD: the first `cargo test` failed with **62** `E0425`/`E0433` errors for
`Facing`, `Block`, `Box3`, `rotate_y`, `bookcase_shape`, `shelf_shape`,
`seat_shape` and `desk_bell_shape` before the model existed
(`/tmp/opencode/bibliocraft-runtime-red.log`).

### Content

| Check | Command | Result |
|---|---|---|
| build | `cargo-horizon-mod horizon-mod build` (in `content/`) | exit 0, built `target/horizon-mod/bibliocraft.hmod`, delivered as `bibliocraft.hmod` |
| check | `cargo-horizon-mod horizon-mod check bibliocraft.hmod` | exit 0, `bibliocraft 26.1.2-1.7.1 (mod, API 0.2, both)`, **14,575 bytes**, SHA-256 `3f4af3ec…dfef5f`, 41 files, unsigned, "no code: content only" |

Delivered `.hmod`: [`bibliocraft.hmod`](bibliocraft.hmod), **14,575 bytes**,
SHA-256 `3f4af3ec5635e48d3458b3c6e450d3bf1d7597c3b7cf00c4d490bd177dafef5f`,
**41 files**.

### In-game e2e (`tools/e2e.sh`, offscreen, The End)

| Run | Result | Log |
|---|---|---|
| default | **PASS** (exit 0): 30/30 states bind; the bookcase faces south/north/east/west from the four sides; all four blocks place and drop themselves; the vanilla `white_glazed_terracotta` control drops only itself; all four recipes craft (stick control empty); tags contain the blocks; the tab lists 4 and all 4 items give; unknown ids refused | `/tmp/opencode/bibliocraft-e2e-port.log` |
| counterfactual (`COUNTERFACTUAL=1`) | **PASS** (exit 0): the vanilla template refuses `waterlogged=true` and drops only itself, never a Bibliocraft item | `/tmp/opencode/bibliocraft-e2e-port-counterfactual.log` |
| negative (`COUNTERFACTUAL=1 NEGATIVE=1`) | **exit 1**, as required: the vanilla template dropped no `bibliocraft:oak_bookcase`, so the deliberately false assertion failed | `/tmp/opencode/bibliocraft-e2e-port-negative.log` |

The final runs above use the port's own fast build
(`target/horizon-cargo/fast/horizon-client`, built from the applied stage at
`c9d474d`). The first default run used the sibling `morered` fast build at the
same pin while this port's fast build was still compiling; the content is
loaded with `--dev-mod ports/bibliocraft/content` and is independent of that
build's native modules. Harness facts found:
`ctl place` uses the **server** player's rotation, so each facing test sets it
with `ctl command "tp @s x y z yaw pitch"`; `ctl break` only rolls loot when
the **client** reports survival (wait 20 ticks after `/gamemode survival`);
the 26.3 loot-table schema uses one `"condition"` object (not 1.21's
`"conditions"` list and `bonus_rolls`); and a full `/tmp` (tmpfs) silently
prevents content mods from loading, which first looked like missing loot.

### Staged pin (`stage → check → test → build`)

`HORIZON_MIXINS=…/horizon-mixins python3 tools/horizon.py <step> --horizon
…/horizon` with `CARGO_INCREMENTAL=0 CARGO_BUILD_JOBS=2`; `check`/`test`/`build`
reused the applied stage (`HORIZON_MIXINS_REUSE=1`) so the generated tree was
not re-applied between steps.

| Step | Result |
|---|---|
| stage (apply) | exit 0, `stage_changed: true`, 1 module, 0 injections, 1,702 s (the machine was heavily loaded; the earlier quiet stage took 214 s) |
| check | `cargo_exit: 0`, **0 warnings** (`/tmp/opencode/bibliocraft-check.log`; build state cleaned) |
| test | `cargo_exit: 0`, **11 passed; 0 failed; 531 filtered out**, **0 warnings** (`/tmp/opencode/bibliocraft-test.log`; filter `game::bibliocraft::tests`; build state cleaned) |
| build | `cargo_exit: 0`, **0 warnings**, `target/horizon-cargo/fast/horizon-client` (81,601,872 bytes; build state cleaned) |
| ctl (for the e2e) | `cargo_exit: 0`, **0 warnings**, `target/horizon-cargo/fast/horizon-ctl` (build state cleaned) |

The module is test-only in the non-test build (`#[cfg(test)] mod model`), so the
staged `horizon-client` has no unused items and the check is warning-free.
After verification the port's `target/` and `content/target/` build state were
removed (sources, `notes.md`, `content/` and the delivered `.hmod` remain), per
the campaign disk-hygiene rule.

## Upstream defects fixed

**None found in this slice**, and two candidates were checked:

- the comparator's answer is the *slot index*, so a redstone book in slot 1
  (index 0) gives no signal. That looks like an off-by-one but is the mod's
  stated design — `item.bibliocraft.redstone_book.text` in the jar's own lang
  spells the scale out ("Slot 1 (top left) yields no signal. Slot 2 yields a
  signal strength of 1 … slot 16 … 15"), so the port keeps it and the e2e
  asserts both ends of it;
- `#bibliocraft:bookcase_books` lists several **optional** foreign guide books
  (`actuallyadditions:booklet`, `ftbquests:book`, …). They are not in the
  registry, so the port declares the two vanilla tags and its own redstone book
  only; the carried tag is incomplete by design, not broken.

## Upstream source

Repository `https://github.com/MinecraftschurliMods/Bibliocraft-Legacy`,
branch `main`, commit `3572b71fed1429556068173c51308be5dff9d33b` (version
`26.1.2-1.7.1`), **MIT**. Re-cloned (shallow, the tag checked out) for slice 2
at `/tmp/opencode/bc-upstream` and deleted after the findings above were
recorded; the files read are named in `## Slice 2`. Area-level findings with file:line citations are in
[`../_shared/upstream/bibliocraft/FINDINGS.md`](../_shared/upstream/bibliocraft/FINDINGS.md);
the clone was deleted after the findings were recorded.

## Skills and references used

- superpowers (slice 2): `using-superpowers`, `brainstorming` (choosing the
  storage family over the seat entity and the desk bell), `writing-plans` (the
  slice plan), `test-driven-development` (the red `E0425` run before the rules
  existed, then the glue), `systematic-debugging` (four in-game red runs turned
  into four facts, `## Slice 2`), `verification-before-completion` (every claim
  in `VALIDATION.md` is a command and its output, on the delivered bytes).
- Beautiful Rust (slice 2): `rust-best-practices` (`Piece` over `Block` for the
  model enum, named constants for every upstream number, `expect` with a reason
  on the two `block_entity_part` attaches, `#[expect(…, reason)]` on the one
  `needless_update`, no `unwrap`, `cargo fmt` + clippy `-D warnings`), `rust-port`
  (the upstream Java read as behaviour only).
- superpowers (slice 1): `test-driven-development` (the runtime model's tests were run
  before the model existed and failed to compile; the in-game content test was
  run red before the content root was built),
  `systematic-debugging` (any in-game failure is diagnosed from the harness
  log before a fix), `verification-before-completion` (every claim below is a
  command + output).
- Beautiful Rust `rust-best-practices`
  (`ports/_shared/skills/BeautifulRust/skills/rust-best-practices/SKILL.md`):
  expressive `Block`/`Facing`/`Box3` types, documented public items, no
  `unwrap`, `cargo fmt` + clippy `-D warnings`.

## Re-pin `83ad384f` — `occludes: false` (2026-11-06)

Migrated to Horizon `83ad384f48d0742746d518737511882680aab5b7` / mixins
`e8cd0aa38cffef49cb2e088ef716baa107148c02` (`mixin_schema` 6, `game.rs`
`996432b9…`). The new content schema has `properties.occludes` (and the
multi-property `shapes` / `collision_shapes` tables), so gap 4 above is closed
for the four slice-1 blocks: each JSON now carries `"occludes": false`, matching
upstream's `noOcclusion()`.

- Content: rebuilt with the pin's `cargo-horizon-mod`; `bibliocraft.hmod`
  14,613 bytes, SHA-256 `262da0d4…5c74b`, 41 files, `no code: content only`.
  The old tool rejects the field (`unknown field occludes`); the new one
  accepts it — that is the schema differential.
- Tests: 11 runtime tests passed; clippy `-D warnings` clean.
- E2E with a new-pin client: default PASS, counterfactual PASS, negative run
  exit 1 as required. Logs: `/tmp/opencode/biblio-e2e-repin.log`,
  `...-cf.log`, `...-neg.log`.
- The multi-property table (`type` × `facing` + `collision_shapes`) is now
  expressible but was not added: the upstream checkout with the table model/
  textures is not present under `_shared/upstream/bibliocraft` (only
  `FINDINGS.md`), so the decorative table would need a re-clone or a
  hand-authored model first. This is an asset gap, not an API gap.

## Migration to the SDK format (0.2.0, 2026-11-18)

Horizon's mod-API merge (#16941, launcher ≥ 0.2.70, PR #17992) retired `.hnmod`: the registry
closed every `.hnmod` submission on 2026-11-18 with one reason, and an `.hnmod` no longer loads.
**This is a first publication** — there was no submission of this port to supersede — so 0.2.0 is
the first version under the SDK, not a republish of a closed PR.

Pins: SDK nightly **`0b14f8acfd97fa2c750e42795249dcc981178ca4`** (2026-11-18, `package_format` 6,
`content_api` "0.2"), mixins **`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`**, `cargo-horizon-mod`
from `horizon-rust/horizon@448cd693`. The SDK is cached in-tree at `../_shared/sdk/0b14f8a/` and
was copied into `.horizon/sdk/` (gitignored) so every build is offline.

### Done in this order

1. The retired layout moved to `../_shared/evidence/bibliocraft/retired-hnmod-0.1.0/` **before**
   the first `cargo horizon-mod build` (the packer documents `unexpected package path` for a
   retired `.rs`/`.toml` at the root — trap 1).
2. `src/runtime.rs` copied with `cp` and proved with `cmp` **and** `sha256sum`
   (`a808cb1e…efab`, identical to the retired file).
3. `cargo test` on the new crate with **only** `pub mod runtime;` in `src/lib.rs` — **11 passed,
   0 failed**, i.e. the pure model is green *before any glue exists* (campaign rule).
4. Only then `src/lib.rs` gained the one `impl Hooks` (no method — this slice has none), the
   manifest was written, and the ladder re-ran green.

### File map

| 0.1.0 path | 0.2.0 | Evidence |
|---|---|---|
| `mixins/bibliocraft/horizon-mixin.toml` (1 `[[module]]`, **0 `[[injection]]`**) | gone; identity and pins are `horizon-mod.toml` | `retired-hnmod-0.1.0/mixins/` |
| `mixins/bibliocraft/runtime.rs` (module **and** crate lib) | `src/runtime.rs`, **byte-identical**, `pub mod runtime;` | `retired-hnmod-0.1.0/mixins/bibliocraft/runtime.rs` |
| `Cargo.toml` (`[lib] path = "mixins/…/runtime.rs"`, `rust-version = "1.95"`, `publish = false`) | `Cargo.toml` (`[lib]` default `src/lib.rs`, one dep: `horizon-mod-api` from `.horizon/sdk/`) | `retired-hnmod-0.1.0/` (moved) |
| `content/horizon-mod.toml` (`version = "26.1.2-1.7.1"`) | the root `horizon-mod.toml`: `version = "0.2.0"`, `api = "0.2"`, `capabilities = ["registries"]` + `[native]` | `retired-hnmod-0.1.0/content/horizon-mod.toml` |
| `content/assets/` + `content/data/` | `assets/` + `data/` at the package root — **40 files, every size + sha256 unchanged** | `retired-hnmod-0.1.0/content/` |
| `content/bibliocraft.hmod` (14,613 B content-only carry) | not needed: one package carries content and code | `retired-hnmod-0.1.0/content/target/horizon-mod/` and `retired-hnmod-0.1.0/bibliocraft-0.1.0-content.hmod` |
| `bibliocraft.hmod` (delivered 0.1.0 content package, 14,613 B) | `bibliocraft.hmod`, 24,181 B — native + content | `retired-hnmod-0.1.0/bibliocraft-0.1.0-content.hmod` |
| `compatibility.json` (`83ad384f` + `game.rs` sha) | `[native] horizon`/`mixins`/`game` in the manifest | `retired-hnmod-0.1.0/compatibility.json` |
| `rust-toolchain.toml` (1.95.0) | gone: the pinned build decides the toolchain | `retired-hnmod-0.1.0/rust-toolchain.toml` |
| `tools/horizon.py` (stage/check/test/build/ctl) | gone: no staging in the SDK format | `retired-hnmod-0.1.0/tools/horizon.py` |
| `Cargo.lock` (170 B) | not kept: it is packed and changes the artifact (imfast's migration trap 5) | not kept |

**Kept and updated:** `tools/e2e.sh` (now launcher-built: `GAME=`, optional `CONTROL_GAME=`,
`SELFTEST=1`, and an `EXIT:<status>` line), `tools/gen_content.py` (writes the package root's
`assets/`+`data/`, no manifest), `tools/craft_check.py`, `notes.md`, `REPIN-AUDIT.md`,
`LICENSE`, and the new `LICENSE-NOTICE.md` (the 0.1.0 port had no provenance file, and the package
must carry it inside itself).

### The plan → package table (every `[[module]]` and `[[injection]]` mapped)

The retired plan had **one module and no injection**, so this table is short and complete:

| 0.1.0 plan entry | 0.2.0 home | Note |
|---|---|---|
| `[[module]] id = "runtime"`, `file = "crates/horizon-client/src/game.rs"`, `name = "bibliocraft"`, `source = "runtime.rs"` | `src/runtime.rs` + `pub mod runtime;` | an ordinary Rust module now; nothing is injected into the game crate, and the model's items are `#[cfg(test)]`, so the non-test build has no unused items |
| *(no `[[injection]]` at any point)* | the one `impl Hooks` with **no method** | slice 1 answers no game moment. `Registrar::…` declarations are not needed either: the blocks, items, loot, recipes, tags and tab are content files the game reads itself |
| `game::bibliocraft::tests` (the staged filter that ran the 11 tests) | `runtime::tests` via plain `cargo test` | no staging, no `horizon.py test` |

No hook lost a home, and no gap was created by the format: the behaviour is unchanged because
there was never any glue beyond the module declaration.

### Manifest field mapping

| 0.1.0 / retired | 0.2.0 `horizon-mod.toml` |
|---|---|
| `horizon-mixin.toml [mod] id` | `id = "bibliocraft"` (also the resource namespace) |
| `[mod] version = "26.1.2-1.7.1"` (upstream's) | `version = "0.2.0"` — the **port's** version (the registry entry, the file and the release must agree) |
| `[mod] priority = 100` | gone; ordering is `#[listener(priority = …)]`, unused here |
| `[compatibility] horizon_revision` | `[native] horizon = "0b14f8a…"` (40 hex) |
| bundle mixins revision | `[native] mixins = "e59da909…"` — **it moved** (`d9c83d7` → `e8cd0aa3` → `e59da909`) |
| — | `[native] game = "26.3"` |
| `content/horizon-mod.toml` `api`/`side`/`capabilities` | the same three at the root: `api = "0.2"`, `side = "both"`, `capabilities = ["registries"]` |
| `authors` | `["Minecraftschurli", "IchHabeHunger54", "AdLf0208"]` (the port author added) |
| `description` | rewritten to state the slice and what is not ported |
| — | `namespaces`/`experimental`/`dependencies`/`inject`: absent (nothing to declare) |

**Measured correction to the migration recipe.** `ports/imfast/notes.md` trap 7 says `license`,
`homepage` and `issues` are **not** manifest fields and that `build` strips them. The tool in use
(`448cd693`) disagrees: `horizon-mod-package`'s `Manifest` has all three as optional fields, and
`pack_directory_with` copies the manifest **verbatim** into the zip (`manifest.rs:1180-1190`), so
nothing is stripped. This port still omits them — the brief's field list is authoritative and the
fields are optional — and carries the licence as `LICENSE` + `LICENSE-NOTICE.md` plus the header
comment, which is what the Mods screen reads from the packaged files anyway.

### The ladder (every step through `build-slot.sh`, `CARGO_INCREMENTAL=0`)

There is no staging step in the SDK format: the crate compiles in place against `.horizon/sdk/`.

| Step | Command | Result |
|---|---|---|
| runtime, glue-free | `cargo test --offline` (only `pub mod runtime;`) | **11 passed, 0 failed** (`evidence/bibliocraft/sdk-runtime-green.log`) |
| tests, with the glue | `cargo test --offline` | **11 passed, 0 failed**, 0 doc tests (`sdk-test.log`) |
| lints | `cargo clippy --all-targets -- -D warnings` | exit 0, **0 warnings** (`sdk-clippy.log`) |
| format | `cargo fmt --check` (**not** `--all`) | exit 0, empty diff (`sdk-fmt.log`) |
| package | `rm -f Cargo.lock && cargo horizon-mod build` | `SDK 0b14f8a … in ./.horizon/sdk`, `Built ./target/horizon-mod/bibliocraft.hmod`, EXIT 0 (`sdk-build.log`) |
| second build | the same, again after `rm -f Cargo.lock` | **byte-identical**: 24,181 B, sha256 `48544f9e8306b7ffa4c2934e0f6c46756aaf40eb29540d9dc2f99e9fae33105e` (`sdk-build-second.log`, `sdk-sha256-second.txt`, `cmp` clean) |
| registry check | `cargo horizon-mod check bibliocraft.hmod` | `bibliocraft 0.2.0 (native-mod, format native-1/0b14f8a…/e59da90…, for 26.3)`, 24,181 B, sha256 `48544f9e…3105e`, unsigned, **EXIT 0** (`sdk-check.log`) |
| machine form | `… --json` | `{"ok":true,…,"kind":"native-mod","size":24181,"version":"0.2.0"}` (`sdk-check-json.log`) |
| fits the pinned build | `cargo horizon-mod fits bibliocraft.hmod --build nightly` | `Bibliocraft Legacy:` / `0b14f8a  made for`, **EXIT 0** (`sdk-fits.log`) |
| entries | `unzip -l bibliocraft.hmod` | **48 files**: `horizon-mod.toml`, `Cargo.toml`, `LICENSE`, `LICENSE-NOTICE.md`, `README.md`, 40 `assets/`+`data/` files, `src/lib.rs`, `src/runtime.rs`, `uses.json`; **no `Cargo.lock`**, no `tools/`, no `target/` (`sdk-entries.log`) |
| the model inside the package | `unzip -p bibliocraft.hmod src/runtime.rs \| sha256sum` | `a808cb1e…efab` = the retired file = `src/runtime.rs` |
| what it uses | `unzip -p bibliocraft.hmod uses.json` | 19 entries (`sdk-uses.json`) |

`uses.json` is the honest summary of a content-only native package: **0 hook entries and 0 method
entries** (there is nothing to call), plus `capability:registries`, `macro:horizon_mod`,
`trait:Hooks`, `part:block`, the two handles (`Block::new`, `Tag::id`) and 13 content-schema types
(`Block`, `BlockProperties`, `BlockShapes`, `BlockStateProperty`, `Compound`, `PushReaction`,
`RandomTicks`, `RenderShape`, `ShapeEntityKind`, `StateLight`, `Tag`, …). They come from the content
behaviour rows (`horizon/block/*.json`), which is the package's real surface — a content-only native
mod is exactly as large as its declarations.

### Traps new to this port (each cost a step here)

1. **The packer walks the whole project root and refuses only stray `.rs`/`.toml`.**
   `horizon-mod-package`'s `walk` takes everything that is a `source_file` and errors on any other
   `.rs`, or any `.toml` that is not the manifest (`manifest.rs:1116-1118`). So the retired
   `mixins/bibliocraft/runtime.rs`, `mixins/bibliocraft/horizon-mixin.toml`,
   `rust-toolchain.toml` and `content/horizon-mod.toml` are all blockers — while `tools/*.py`,
   `tools/*.sh`, `notes.md`, `REPIN-AUDIT.md` and `compatibility.json` are simply ignored. Ignored is
   not packed: `directory_files` selects the content, the source files and the icon only, so `tools/`
   never enters the zip, and `README.md` does, through `source_file`'s root-document rule. Move the
   retired tree first, then build once: a failure here is the packer's, not code's.
2. **`cargo horizon-mod` is installed on this box only.** The first packaging attempt forwarded to
   the second machine and died in one second with `error: no such command: horizon-mod` (exit 101);
   the far box has no such cargo subcommand. Compile steps (`test`/`clippy`) forward fine, so the
   split is: `build`/`check`/`fits` run `BUILD_LOCAL=1`, the compiles stay forwarded.
3. **A forwarded command starts *in the port*, not in the campaign root.** The brief's
   `bash -c 'cd ports/bibliocraft && …'` wrapper answers `cd: ports/bibliocraft: No such file or
   directory` on the far box (cwd is `/home/deepseek/atm10/ports/bibliocraft`). The wrapper that
   works on both is `cd ports/bibliocraft 2>/dev/null || true`.
4. **A native package with an empty `impl Hooks` is valid — and it is the honest shape here.** The
   registry check accepts it (`native-mod`, EXIT 0), `fits` accepts it, and `uses.json` carries no
   hook. Do not invent a hook (or a `Registrar` declaration) just to make the package look busier:
   the content files are what this slice is.
5. **The old deliverable has the same file name as the new one.** `bibliocraft.hmod` at the root was
   the 0.1.0 content-only package (14,613 B); `cargo horizon-mod build` + `cp` overwrite it. It was
   moved to `retired-hnmod-0.1.0/bibliocraft-0.1.0-content.hmod` *before* the build, so the
   comparison stays auditable.
6. **`check --json` is not a content report.** For a native package it prints
   `"capabilities": []` and `"side": null` while the manifest declares `["registries"]` and `"both"`;
   the text form also omits the capability. That is the native facts path, not a rejection — do not
   "fix" the manifest from it.
7. **The 0.1.0 e2e's two crutches are gone, and one assertion had to move.** `--dev-mod content/`
   no longer exists (the package carries its own content), and `NEGATIVE=1` (a false drop assertion
   read from a break reply) became `SELFTEST=1`, a false assertion read from the world
   (`block 28 80 20` is never `bibliocraft:oak_bookcase`). The creative-tab check no longer has a
   known path for free: it now looks in the game dir's `.horizon-cache/mod-content/` and next to the
   `GAME` binary, and fails naming both when neither exists.
8. **`gen_content.py` used to own a manifest.** Its `--out` default was `content/` and it wrote
   `content/horizon-mod.toml` (upstream's version string, no `[native]`). Pointing it at the package
   root without removing that write would have destroyed the pins on the next run; the manifest is
   now hand-maintained and the tool owns `assets/`+`data/` only.

### Gaps

Everything in *Deviations and gaps* above still stands (the table, the
declared-but-not-simulated `waterlogged`, occlusion, one wood type / one seat
colour, the seat's extra `axis`, the pickaxe-only desk bell, no sounds, one item
per bookcase slot, the one-tick filter, the blocked enchanting bonus). The
0.2.0 gaps are closed:

1. ~~**No in-game run of the SDK package.**~~ **Closed in 0.2.3**: the launcher
   builds this package and `tools/e2e.sh` runs on the built game — `PASS` +
   `EXIT:0`, the barrel counterfactual at `EXIT:0`, `SELFTEST=1` at `EXIT:1`
   (`../_shared/evidence/bibliocraft-e2e/`).
2. ~~**The native half compiles to nothing.**~~ **Closed in 0.2.3**: it now
   registers two block-entity types, two containers, two menus and their Parts,
   and answers three hooks.
3. ~~**`gen_content.py` was not re-run.**~~ **Closed in 0.2.3**: re-run against
   a fresh clone of the pinned tag, and the tree it writes is byte-identical to
   the delivered one.

Open for later slices (each named in the jar, none started):

| family | state |
|---|---|
| the seat's `SeatEntity`, riding, the seat back, `occupied` redstone | not ported (`SeatBlock.java:74-155`; needs an entity type and mount hooks) |
| the desk bell's bell sound on use and on a redstone signal | not ported (`DeskBellBlock.java:49-62`; needs a sound hook and the four `.ogg` files) |
| the table (`type` × `facing` collision, its block entity) | not ported (`TableBlock.java:34-166`) |
| the bookcase's enchanting-table bonus | `blocked(enchant_power_bonus never dispatched)` |
| the other 11 wood types and 15 seat colours; the other furniture (lamps, display cases, clocks, labels, potion shelves, typewriters, printing tables, cookie jars, dinner plates, disc racks, sword pedestals, armour stands, big books, shelf backs) | not ported (content + block entities; a later slice each) |

### Changelog (0.2.3)

> **0.2.3 — slice 2: the bookcase and the shelf are storage.** The two wood blocks now have block
> entities: the oak bookcase is a 16-slot, books-only container (`#bibliocraft:bookcase_books`) opened
> by a click, whose `bibliocraft:redstone_book` in slot *n* makes a comparator answer *n* (0–15, its
> own lang text's scale) and whose books spill when it is broken; the oak shelf is a plain 4-slot
> one. Both reach hoppers on every face, both have a content menu (`bibliocraft:bookcase`,
> `bibliocraft:shelf`), and the `redstone_book` item arrives with its shapeless book + redstone-torch
> recipe, one per stack and glinting. What changed since 0.2.0 for `api = "0.2"`: `src/lib.rs` gained
> `register`, `right_click_block` and `level_tick_post`; `src/support.rs` is new (the two Parts, the
> container declarations, the comparator cache, the menu layouts); `src/runtime.rs` gained the slot,
> menu and comparator rules and its `Block` model type was renamed `Piece` (a local `Block` made
> `fits --build 0b14f8a` report a false positive); `data/bibliocraft/horizon/{menu,item}/` and the
> book case tag are new. Built against SDK `0a875da` / mixins `e59da90` for 26.3, run in game
> (`PASS`/`EXIT:0`, counterfactual `EXIT:0`, selftest `EXIT:1`). Still open: the seat entity, the
> desk bell's bell sound, the table, the other wood types and colours, and the bookcase's
> enchanting-table bonus (`blocked(enchant_power_bonus never dispatched)`).

### Changelog (0.2.0)

> **0.2.0 — first publication, as an SDK `.hmod`.** Horizon's mod-API merge (launcher ≥ 0.2.70)
> retired `.hnmod` and closed every submission in that format; this port had not been submitted, so
> 0.2.0 is its first release. One flat `bibliocraft.hmod` now carries the code *and* the content —
> the oak bookcase, oak shelf, black oak seat and desk bell with their states, shapes, items,
> self-drop loot, the upstream shaped recipes, the tags and the `Bibliocraft` creative tab. What
> changed for `api = "0.2"`: the `.hnmod` container, its mixin plan and the separate `content/`
> package are gone (one archive, one manifest with the exact `[native]` pins); `src/lib.rs` is the
> one `impl mod_api::Hooks`, with no method because this slice answers no game moment; the content
> moved from `content/assets`+`content/data` to the package root, byte-identical; the pure furniture
> model is still `src/runtime.rs`, byte-identical, with its 11 tests. The behaviour and the gaps are
> unchanged — the bookcase/shelf inventories, the seat entity, the desk bell's ring and the table
> are still deferred. Built against SDK `0b14f8a` / mixins `e59da90` for 26.3; not yet run in game
> (no launcher here).

Skills: superpowers/using-superpowers, brainstorming, writing-plans, test-driven-development, systematic-debugging, verification-before-completion; BeautifulRust/rust-best-practices, rust-port
