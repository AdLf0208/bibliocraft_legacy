# Bibliocraft Legacy — a Horizon port

**Bibliocraft Legacy** is a Minecraft mod. Bibliocraft Legacy is a port of the original BiblioCraft Minecraft mod by Nuchaz. It adds various pieces of decorative and functional furniture into the game. This repository is a **port of it to [Horizon](https://github.com/horizon-rust/horizon)**, the Rust engine for Minecraft Java 26.3. It carries the complete source of the port plus the content files it ships, and installs as a single `.hmod` package.

Upstream: [MinecraftschurliMods/Bibliocraft-Legacy](https://github.com/MinecraftschurliMods/Bibliocraft-Legacy) — licence **MIT**.

| | |
|---|---|
| Upstream mod | Bibliocraft Legacy ([source](https://github.com/MinecraftschurliMods/Bibliocraft-Legacy)) |
| Ported to | Horizon 0b14f8a, Minecraft Java 26.3, mod API `0.2` |
| Package | `bibliocraft.hmod` (install it with the Horizon launcher) |
| Licence | **MIT** — the upstream mod's licence; see [Licence and credit](#licence-and-credit) |

## What this port implements

The port's behaviour is recorded in the repository's `notes.md` (the campaign's per-mod record); this slice ships what that file describes.

## Not yet ported

- **Decorative, not functional.** The bookcase and shelf have no inventory,
- **Table deferred.** Its collision depends on `type` *and* `facing`
- **Waterlogged is a declared state, not fluid logic.** The state binds and
- **Occlusion is the template's.** Upstream marks the bookcase, shelf, seat
- **One wood type and one seat colour.** Slice 1 carries only `oak` and
- **The seat carries an extra `axis` state.** The seat uses the `oak_log`
- **Desk bell requires a pickaxe** (`requires_tool: true`, copied from
- **No sounds, particles or animations** are carried. The desk bell's four

## Installing

1. Install the [Horizon launcher](https://github.com/horizon-rust/horizon/releases) (0.2.70 or newer).
2. Add `bibliocraft.hmod` to the instance's mods.
3. The package is pinned to a specific Horizon build; the launcher checks that pin.

## Licence and credit

Bibliocraft Legacy was created by its upstream authors; the code, models and assets in the original mod
remain theirs and are used here under **MIT**. The Rust in this repository is a clean-room
rewrite for Horizon, not a translation of the original source.

- `LICENSE` — the upstream licence text.
- `LICENSE-NOTICE.md` — what this port carries and where it came from.
- The upstream project: https://github.com/MinecraftschurliMods/Bibliocraft-Legacy

## Technical details

```
horizon-mod.toml   package manifest (id, version, api, [native] pin)
Cargo.toml         the crate; depends on `horizon-mod-api` from the fetched SDK
src/               lib.rs (the one `impl Hooks`), runtime.rs (pure logic + tests), glue
assets/ data/      the content the package ships
tools/             content generators and the e2e scenario
```

- Build: `cargo horizon-mod build` (packages; it does not compile against the game).
- Test: `cargo test`, `cargo clippy --all-targets -- -D warnings`.
- In-game: `ports/tools/launcher-game.sh run bibliocraft` in the campaign tree, or install the
  `.hmod` and play; the harness scenario is `tools/e2e.sh`.

This repository is generated from the campaign's port at `ports/bibliocraft/`; the port's own
`notes.md` is the full record (decisions, traps, evidence).
