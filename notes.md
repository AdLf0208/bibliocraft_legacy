# Bibliocraft Legacy — port notes

Ported from **Bibliocraft Legacy 26.1.2-1.7.1**
(`MinecraftschurliMods/Bibliocraft-Legacy`, branch `main`, commit
`3572b71fed1429556068173c51308be5dff9d33b`, tag `26.1.2-1.7.1`,
`gradle.properties`) for Minecraft 26.3. Originally a `.hnmod` bundle at
Horizon **c9d474d** / **83ad384f**; since **2026-11-18** one flat SDK package
(mod API 0.2) at nightly **`0b14f8acfd97fa2c750e42795249dcc981178ca4`** /
mixins **`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`**, version **0.2.0** — see
[`## Migration to the SDK format`](#migration-to-the-sdk-format-020-2026-11-18).
The 0.1.0 sections below describe the retired container and stay as history.

**Licence: MIT** (`LICENSE`, `gradle.properties:license.name=MIT`). The port is
**local-only until publishing is approved** (ARCHITECTURE.md §8): the upstream
models and lang are MIT, but the campaign does not publish without the
maintainer's explicit approval.

Status: **ported-partial — slice 1 implemented and verified in-game at 0.1.0;
the SDK package is compile-verified, not yet run in game.** Slice 1 is four
plain, decorative furniture blocks: the oak bookcase, oak shelf, black oak seat
and desk bell. They carry their states, shapes, items, drops, recipes, tags and
one creative tab. There is **no block entity, no GUI and no hook**: the
upstream bookcase/shelf inventories, the seat entity, the desk bell's sound and
the redstone/enchant answers are deferred (see Gaps).

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

## Hooks

None. Slice 1 is content-only: the four blocks are declared in
`data/bibliocraft/horizon/block/` (0.1.0: `content/data/…`), and the package's
native half is one `impl Hooks` with no method. The runtime model is a
standalone Rust module; its tests are the only code that runs. No
`[[injection]]` ever existed, in either format.

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

1. **Decorative, not functional.** The bookcase and shelf have no inventory,
   comparator output or enchanting bonus (`BookcaseBlock.java:39-75`,
   `ShelfBlock.java:29-52`); the seat does not spawn a `SeatEntity` and does
   not drop a seat back above (`SeatBlock.java:74-145`); the desk bell does not
   ring on use or on a redstone signal (`DeskBellBlock.java:49-62`). These need
   block entities, an entity, a menu or a sound hook and are later slices.
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

Skills: superpowers/using-superpowers,verification-before-completion; BeautifulRust/rust-best-practices

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

## Upstream source

Repository `https://github.com/MinecraftschurliMods/Bibliocraft-Legacy`,
branch `main`, commit `3572b71fed1429556068173c51308be5dff9d33b` (version
`26.1.2-1.7.1`), **MIT**. Area-level findings with file:line citations are in
[`../_shared/upstream/bibliocraft/FINDINGS.md`](../_shared/upstream/bibliocraft/FINDINGS.md);
the clone was deleted after the findings were recorded.

## Skills and references used

- superpowers: `test-driven-development` (the runtime model's tests were run
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

Everything in *Deviations and gaps* above still stands (decorative-only blocks, the table, the
declared-but-not-simulated `waterlogged`, occlusion, one wood type / one seat colour, the seat's
extra `axis`, the pickaxe-only desk bell, no sounds). Added by the format:

1. **No in-game run of the SDK package.** The launcher is not installed in this environment, so no
   `0b14f8a` game with this package exists here. `tools/e2e.sh` is updated for a launcher-built game
   and keeps its fail-capable `SELFTEST=1`, but **the run is not claimed**; the 0.1.0 in-game results
   above (whose logs are gone) remain the behaviour's only evidence. This is what keeps the port at
   `ported-partial` rather than `ported`.
2. **The native half compiles to nothing.** `src/lib.rs` is one empty `impl Hooks`: the package is a
   content package that happens to be native because the campaign's rule packs `src/runtime.rs` and
   its tests with the port. A launcher build therefore pays a (small) compile for no registered
   behaviour. The alternative — a content-only package — would drop the model and its 11 tests from
   the artifact, which the campaign's rule forbids.
3. **`gen_content.py` was not re-run.** The upstream checkout was deleted after the 0.1.0 findings
   (`_shared/upstream/bibliocraft` holds only `FINDINGS.md`), so the generator's new `--out` default
   is syntax-checked (`py_compile`) but not executed; the carried files are byte-identical to the
   retired ones and are the evidence.

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
