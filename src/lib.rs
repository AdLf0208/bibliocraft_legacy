//! Bibliocraft Legacy for Horizon — the port's pure furniture model (slice 1).
//!
//! Slice 1 is four plain, decorative furniture blocks: the oak bookcase, the
//! oak shelf, the black oak seat and the desk bell. They are declared as
//! content in this package (`assets/` and `data/`); [`runtime`] is the single
//! place their templates, state counts and shape boxes are spelled out, and
//! its tests are what `cargo test` runs without the game.
//!
//! The model's items are `#[cfg(test)]`, exactly as they were in the retired
//! bundle: this slice has no hook, no Part and no block entity, so there is
//! nothing for the game to call. The four blocks' behaviour (bookcase and
//! shelf inventories, the seat entity, the desk bell's sound) is deferred; see
//! `notes.md`.
use mod_api::{self, Hooks};

pub mod runtime;

#[derive(Default)]
struct Mod;

// Slice 1 is content-only: every block is a carried declaration, and the one
// behaviour the port could add — a block entity with an inventory — is a later
// slice. The trait is implemented with no method on purpose (the `Hooks`
// checklist asks which moments a mod answers; this one answers none), and the
// pure model above stays the tested part.
#[mod_api::horizon_mod]
impl Hooks for Mod {}
