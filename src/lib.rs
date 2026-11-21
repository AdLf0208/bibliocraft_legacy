//! Bibliocraft Legacy for Horizon — the SDK package (mod API 0.2).
//!
//! Slice 1 carried four plain furniture blocks as content only: the oak bookcase, the oak shelf,
//! the black oak seat and the desk bell. Slice 2 makes the two storage blocks real: the bookcase
//! is a 16-slot bookcase whose redstone books answer a comparator and whose books feed an
//! enchanting table, the shelf a 4-slot shelf, both with a content menu, hopper access on every
//! face and contents that survive being broken. This file is the one `impl Hooks`; the rules are
//! in [`runtime`] (pure, `cargo test`) and the game glue — the two block entities, their Parts,
//! the comparator cache and the dropped-contents payload — is in [`support`].
use mod_api::{
    self, Flow, Hooks, HostSide, LevelTickPostEvent, Registrar, RegistrationContext,
    RightClickBlockEvent,
};

pub mod runtime;
pub mod support;

/// The mod keeps no state of its own: one instance serves every hook, and anything that must
/// outlive a call lives in [`support`]'s shared state.
#[derive(Default)]
struct Mod;

#[mod_api::horizon_mod]
impl Hooks for Mod {
    /// Declare what the game answers for the bookcase and the shelf: one block-entity type each,
    /// the Part that answers their moments, and the 16-slot and 4-slot containers with the
    /// content menus each block opens.
    fn register(&self, r: &mut dyn Registrar, _cx: &RegistrationContext) {
        support::declare(r);
    }

    /// A click on a bookcase or shelf opens its content menu (`Player.openMenu`), the route a
    /// mod block's menu takes at this pin (`support::right_click_block`).
    fn right_click_block(&self, host: HostSide<'_>, event: &mut RightClickBlockEvent<'_>) -> Flow {
        support::right_click_block(host, event)
    }

    /// After a level's tick pass, tell the neighbours of a bookcase whose comparator answer
    /// changed to read it again (`Level.updateNeighbourForOutputSignal`).
    fn level_tick_post(&self, host: HostSide<'_>, event: &mut LevelTickPostEvent) {
        support::level_tick_post(host, event);
    }
}

#[cfg(test)]
mod tests {
    use crate::Mod;

    /// The engine refuses a package whose Parts it cannot attach, and prints why. This runs this
    /// package's own `register` through the SDK's registration path, so the assertion is the
    /// engine's own verdict rather than ours.
    #[test]
    fn the_engine_accepts_every_part_of_this_package() {
        let category = |_: &str| false;
        let position = |_: &str| None;
        let schema = mod_api::__private::RuleSchema {
            category: &category,
            position: &position,
            rule_count: 0,
        };
        let mods = vec![mod_api::ModEntry::new("bibliocraft", Box::new(Mod))];
        let refused =
            mod_api::__private::install_parts(&mods, &schema, |_: &mod_api::DimensionSettings| {
                false
            });
        assert!(
            refused.is_ok(),
            "the engine refuses this package: {refused:?}"
        );
    }
}
