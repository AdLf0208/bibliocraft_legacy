# Bibliocraft Legacy — Horizon port (slice 1)

A clean-room Rust/content port of **Bibliocraft Legacy 26.1.2-1.7.1**
(`MinecraftschurliMods/Bibliocraft-Legacy`, MIT) for Minecraft 26.3 on
Horizon's pinned build `0b14f8a`.

Slice 1 is four plain, decorative furniture blocks with no block entity, GUI
or hook:

- `bibliocraft:oak_bookcase` (8 states, six-box facing shape)
- `bibliocraft:oak_shelf` (8 states, one-box wall shape)
- `bibliocraft:black_oak_seat` (12 states, ten-box stool shape)
- `bibliocraft:desk_bell` (2 states, eight-box shape)

They carry items, self-drop loot, the upstream shaped recipes, tags and one
`Bibliocraft` creative tab. The bookcase/shelf inventories, the seat entity,
the desk bell's sound and the table are deferred; see [`notes.md`](notes.md).

## One flat SDK package (mod API 0.2)

```text
bibliocraft.hmod            # the deliverable: code + content in one file
  horizon-mod.toml          # the only manifest: id, version, api, capabilities, [native] pins
  Cargo.toml                # horizon-mod-api from .horizon/sdk/ (fetched, never packed)
  src/lib.rs                # the one `impl mod_api::Hooks` — no method, this slice has no hook
  src/runtime.rs            # the pure furniture model + its 11 tests
  assets/bibliocraft/       # blockstates, item definitions, models, lang
  data/bibliocraft/         # block declarations, loot, recipes, tags, creative tab
  LICENSE, LICENSE-NOTICE.md
```

`assets/` and `data/` are the carried content; `tools/gen_content.py`
regenerates them from an upstream checkout. `tools/craft_check.py` drives the
four shaped recipes in a real crafting table inside the e2e.

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
cargo horizon-mod fits bibliocraft.hmod --build nightly
```

The launcher is the only thing that compiles the native half for play
(`horizon-launcher native-build . --instance <i> --trust-native-code`); the
in-game scenario is `tools/e2e.sh` with `GAME=<launcher-built horizon-client>`.

## Licence

Upstream and this port are MIT. The port is **local-only until publishing is
approved** (ARCHITECTURE.md §8); the carried models and lang are upstream
assets.
