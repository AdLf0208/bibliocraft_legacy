# Validation — Bibliocraft Legacy 0.2.3

The ladder for slice 2 (the bookcase and the shelf as storage) at SDK nightly
**`0a875da91dbb0fdcb7ba8c42c11341aa229af51a`** / mixins
**`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`**, built with the launcher
(`ports/tools/launcher-game.sh`). Every step went through
`ports/tools/build-slot.sh` as a separate lease; every log prints the
`SIZE`/`SHA256`/`VERSION`/`PIN` line it ran against, and the evidence lives in
`../_shared/evidence/bibliocraft/` (ladder) and
`../_shared/evidence/bibliocraft-e2e/` (game legs).

## Artifact

| field | value |
|---|---|
| file | `ports/bibliocraft/bibliocraft.hmod` |
| version | **0.2.3** (`horizon-mod.toml`, `api = "0.2"`, `side = "both"`, `capabilities = ["registries"]`) |
| pins | `[native] game = "26.3"`, `horizon = 0a875da…`, `mixins = e59da90…` |
| size | **41,697 bytes** |
| SHA-256 | **`fe1eba2d6982952cdba1041874471857f3cbddfccdda2dfae454e61572e88185`** |
| entries | **56 files**, **no packed `Cargo.lock`** (`sdk-entries.log`) |
| `src/runtime.rs` in the package | `ed6fc9f6…` = the tree (`sdk-runtime-in-package.txt`) |
| two builds after `rm -f Cargo.lock` | `cmp`-identical (the same 56-entry zip) |

## Ladder

| step | command (through `build-slot.sh run --job W1-bibliocraft`) | result | log |
|---|---|---|---|
| red | `cargo test --offline` before the rules existed | **25 × `E0425`**, `TEST_EXIT:101` | `runtime-tests-red.log` |
| tests | `cargo test --offline` | **18 passed, 0 failed**, `TEST_EXIT:0` | `sdk-test.log` |
| lints | `cargo clippy --all-targets --offline -- -D warnings` | exit 0, **0 warnings** | `sdk-clippy.log` |
| format | `cargo fmt --check` (**not** `--all`) | exit 0 | `sdk-fmt.log` |
| package ×2 | `rm -f Cargo.lock && cargo horizon-mod build` | `SDK 0a875da … in ./.horizon/sdk`, `Built ./target/horizon-mod/bibliocraft.hmod`, `CMP: two builds byte-identical` | in the run above |
| check | `cargo horizon-mod check bibliocraft.hmod` | `bibliocraft 0.2.3 (native-mod, format native-1/0a875da…/e59da90…, for 26.3)`, 41,697 B, `CHECK_EXIT:0` | `sdk-check.log` |
| fits (pin) | `cargo horizon-mod fits bibliocraft.hmod --build 0a875da` | **`0a875da  made for`**, `FITS_EXIT:0` | `sdk-fits.log` |
| fits (other) | `cargo horizon-mod fits bibliocraft.hmod --build 0b14f8a` | **`0b14f8a  fits`**, `FITS_OTHER_EXIT:0` | `sdk-fits-other.log` |
| gate | `python3 ports/tools/verify-sdk-package.py bibliocraft` | **1/1 package(s) verified** (package, runtime byte-identical, no `Cargo.lock`, tests, clippy, check, fits, skills gate) | run output |
| entries | `unzip -l bibliocraft.hmod`, `unzip -p … uses.json` | 56 files, 0 `Cargo.lock`, `uses.json` = the honest surface (`supported_schema`, `made_for`, 3 entries) | `sdk-entries.log`, `sdk-uses.json` |

The two `fits` runs are both needed: the pin run is a tautology, the `0b14f8a`
run is the one that catches a local type claiming an API name. It did: the
model's `Block` enum made `fits --build 0b14f8a` report `does not fit` until it
was renamed `Piece`.

## In-game legs (launcher-built game, `--offscreen`, The End)

`eval "$(ports/tools/launcher-game.sh env bibliocraft)"` then each run through
`build-slot.sh run --job W1-bibliocraft --port ports/bibliocraft --step e2e --
bash ports/bibliocraft/tools/e2e.sh`; the game build carries
`Compiling bibliocraft (1 of 1)` (trap 15: the manifest was bumped for every
rebuild, so no run stood on a reused binary).

| run | result | log |
|---|---|---|
| default (`CONTROL_GAME` set: the same build without the package) | **`PASS`** + `EXIT:0`; the control leg refuses every Bibliocraft id | `bibliocraft-e2e/e2e.log` |
| `COUNTERFACTUAL=1` (a vanilla barrel instead of the bookcase) | **`PASS (counterfactual)`** + `EXIT:0`: the barrel opens 27 slots and takes the stone the bookcase refuses | `bibliocraft-e2e/e2e-counterfactual.log` |
| `SELFTEST=1` (the storage assertion inverted) | **`FAIL: SELFTEST: expected the bookcase menu to show 27 slots, found '16'`** + `EXIT:1` | `bibliocraft-e2e/e2e-selftest.log` |
| `check-e2e-logs.py bibliocraft-e2e --strict` | `logs=3 ok=3 missing-exit=0 bad-exit=0` | run output |

What the default leg asserts about this slice, as printed by the run (the
values are the ones in `e2e.log`):

```
bookcase menu slots: 16
slot 5 (300+5) holds a plain book
wire power with a plain book in slot 5: 0
wire power with a redstone book in slot 3: 3
wire power with the redstone book in slot 1: 0
slot 309 is empty again: the bookcase refused the stone
books in the bookcase after the hopper: 3
books in the chest: 3
shelf menu slots: 4
the shelf kept the stone the bookcase refuses
books before the break: 2
books in the break reply: 2
books after the break: on the ground 2, carried 0
books in the replaced bookcase: 0
```

The comparator values are read from the **wire's** `power` block state, so they
are the game's answer, not the port's: a comparator at `x+1` facing west reads
the bookcase at `x` and drives a wire at `x+2`.

## Cleanup

`ports/bibliocraft/target/` was left to the slot caches (`CARGO_INCREMENTAL=0`
throughout); the delivered package, sources, `notes.md`, `VALIDATION.md`, the
tools and the evidence remain. The shipped `.hmod` is in the port root, never in
`target/`.
