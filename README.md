# Bibliocraft Legacy — Horizon port (slices 1–2)

A clean-room Rust/content port of **Bibliocraft Legacy 26.1.2-1.7.1**
(`MinecraftschurliMods/Bibliocraft-Legacy`, MIT) for Minecraft 26.3 on
Horizon's pinned SDK build `0a875da`.

Slice 1 is four furniture blocks with their states, shapes, items, self-drop
loot, the upstream shaped recipes, tags and one `Bibliocraft` creative tab:

- `bibliocraft:oak_bookcase` (8 states, six-box facing shape)
- `bibliocraft:oak_shelf` (8 states, one-box wall shape)
- `bibliocraft:black_oak_seat` (12 states, ten-box stool shape)
- `bibliocraft:desk_bell` (2 states, eight-box shape)

Slice 2 makes the two wood blocks real storage:

- the bookcase is a **16-slot, books-only** block entity with a content menu
  (`bibliocraft:bookcase`); a `bibliocraft:redstone_book` in slot *n* makes a
  comparator answer *n* (0–15), a plain book answers 0, and a broken bookcase
  spills its books as any container does;
- the shelf is a **4-slot** one (`bibliocraft:shelf`) that keeps anything;
- `bibliocraft:redstone_book` is the comparator's trigger item (one per stack,
  glinting, shapeless book + redstone torch).

Still deferred: the seat entity, the desk bell's ring and redstone answers, the
table, the other wood types and seat colours, and the bookcase's
enchanting-table bonus (its hook is not dispatched at this pin). See
[`notes.md`](notes.md) and [`VALIDATION.md`](VALIDATION.md).

## One flat SDK package (mod API 0.2)

```text
bibliocraft.hmod            # the deliverable: code + content in one file
  horizon-mod.toml          # the only manifest: id, version, api, capabilities, [native] pins
  Cargo.toml                # horizon-mod-api from .horizon/sdk/ (fetched, never packed)
  src/lib.rs                # the one `impl mod_api::Hooks` (register, right_click_block, level_tick_post)
  src/runtime.rs            # the pure rules — shapes, slots, the comparator signal — and their tests
  src/support.rs            # the glue: the two block entities, their Parts, the menu, the comparator cache
  assets/bibliocraft/       # blockstates, item definitions, models, lang
  data/bibliocraft/         # block declarations, menus, items, loot, recipes, tags, creative tab
  LICENSE, LICENSE-NOTICE.md
```

`assets/` and `data/` are the carried content; `tools/gen_content.py`
regenerates them from an upstream checkout. `tools/craft_check.py` drives the
five recipes in a real crafting table inside the e2e.

## Build and check

```sh
# the compile gate (host target, the SDK is a path dependency)
CARGO_INCREMENTAL=0 cargo test
CARGO_INCREMENTAL=0 cargo clippy --all-targets -- -D warnings
cargo fmt --check                      # not --all: that formats the fetched SDK

# the package (a lock changes the artifact, so remove it first)
rm -f Cargo.lock && cargo horizon-mod build
cp target/horizon-mod/bibliocraft.hmod ./bibliocraft.hmod
cargo horizon-mod check bibliocraft.hmod
cargo horizon-mod fits bibliocraft.hmod --build 0a875da
cargo horizon-mod fits bibliocraft.hmod --build 0b14f8a     # a different build
```

The launcher is the only thing that compiles the native half for play
(`ports/tools/launcher-game.sh build bibliocraft`); the in-game scenario is
`tools/e2e.sh` with the `GAME`/`CTL`/`RES` that `launcher-game.sh env
bibliocraft` prints.

## Licence

Upstream and this port are MIT. The port is **local-only until publishing is
approved** (ARCHITECTURE.md §8); the carried models and lang are upstream
assets.
