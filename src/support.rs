//! Game-side glue for Bibliocraft's storage furniture (slice 2).
//!
//! [`crate::runtime`] holds the rules — how many slots a bookcase and a shelf have, what a
//! bookcase's comparator answers. This module is the only place that reads the game and writes it
//! back: the two block entities, their content menus, the bookcase's book-only filter, the
//! comparator reading, and the contents a broken storage block carries on its dropped item.
//!
//! Upstream's `BookcaseBlockEntity` is a 16-slot `BEMenuBlockEntity` accepting
//! `#bibliocraft:bookcase_books`; `ShelfBlockEntity` is a 4-slot one accepting anything. The
//! `[[module]]`/`[[injection]]` plan that used to carry this glue is gone with the SDK format
//! (notes.md, `## Migration to the SDK format`): a hook is a typed method now, and a moment that
//! belongs to one block or block entity is a **Part** attached to its type.

use std::collections::HashMap;
use std::sync::Mutex;

use mod_api::{
    AnalogOutputEvent, BlockEntityPart, BlockEntityTickEvent, BlockEntityTickReply,
    BlockEntityTicksEvent, BlockPart, BlockState, Flow, Hand, HasAnalogOutputEvent, Host, HostSide,
    InteractionResult, ItemStack, LevelHost, LevelRef, LevelTickPostEvent, ModContainer,
    NeighbourUpdate, Registrar, RightClickBlockEvent, Screen, ScreenEvent, ServerHost,
};

use crate::runtime::{
    BOOKCASE, BOOKCASE_BOOKS, BOOKCASE_SLOTS, REDSTONE_BOOK, SHELF, SHELF_SLOTS, menu, signal,
    slots,
};

/// The bookcase's block-entity type, in this mod's namespace (`BCBlockEntities.BOOKCASE`).
const BOOKCASE_TYPE: &str = "bookcase";
/// The shelf's block-entity type (`BCBlockEntities.SHELF`).
const SHELF_TYPE: &str = "shelf";
/// The bookcase blocks the one type covers (this slice carries oak).
const BOOKCASE_BLOCKS: &[&str] = &["oak_bookcase"];
/// The shelf blocks the one type covers.
const SHELF_BLOCKS: &[&str] = &["oak_shelf"];
/// How many level ticks a comparator reading is kept without its bookcase ticking (10 s).
const SIGNAL_LIFETIME: u64 = 200;
/// The upstream panels: 176 x 166, the player's inventory under the rows at y 84.
const PANEL_WIDTH: f32 = 176.0;
const PANEL_HEIGHT: f32 = 166.0;
const INVENTORY_X: f32 = 8.0;
const INVENTORY_Y: f32 = 84.0;

/// The glue's per-session state: the comparator answers a block entity's tick last read.
///
/// `analog_output` is asked with a level host only, which cannot read a block entity, so the answer
/// is computed in the tick (which is given the slots) and read back here. Functional Storage's
/// drawer does the same at this pin.
#[derive(Default)]
pub struct Core {
    /// The last answer of each bookcase, by `(dimension, pos)`, and the tick it was read at.
    signal: HashMap<(String, [i32; 3]), Signal>,
    /// `(level, pos)` whose answer changed and whose neighbours must read it again.
    output: Vec<(LevelRef, [i32; 3])>,
    /// The last level tick, which ages the readings.
    tick: u64,
}

/// One bookcase's last comparator answer.
#[derive(Clone, Copy)]
struct Signal {
    value: i32,
    seen: u64,
}

static STATE: Mutex<Option<Core>> = Mutex::new(None);

/// The shared state; a poisoned lock is fatal, never silently recovered.
fn core() -> std::sync::MutexGuard<'static, Option<Core>> {
    STATE
        .lock()
        .expect("the bibliocraft storage state lock is never held across a panic")
}

// ---------------------------------------------------------------------------
// Declarations
// ---------------------------------------------------------------------------

/// Declare the two block entities, the Part that answers their moments, and the container each
/// block opens: every face reaches every slot (a hopper may both fill and empty), and the block's
/// use opens the content menu the carried `menu/` files declare.
pub fn declare(r: &mut dyn Registrar) {
    let bookcase = r.block_key(BOOKCASE);
    let kind = r
        .block_entity_type(BOOKCASE_TYPE)
        .blocks(BOOKCASE_BLOCKS)
        .build();
    r.block_entity_part(&kind, BookcasePart)
        .expect("the bookcase Part attaches to the type this mod just declared");
    r.block_container(&bookcase, container_of(BOOKCASE));

    let shelf = r.block_key(SHELF);
    let kind = r.block_entity_type(SHELF_TYPE).blocks(SHELF_BLOCKS).build();
    r.block_entity_part(&kind, ShelfPart)
        .expect("the shelf Part attaches to the type this mod just declared");
    r.block_container(&shelf, container_of(SHELF));
}

/// `block`'s container: the slots and the menu `runtime` declares for it, reachable and both
/// fillable and emptyable from every face.
fn container_of(block: &str) -> ModContainer {
    let slots = slots(block).expect("a storage block declares its slots in runtime.rs");
    let menu = menu(block).expect("a storage block declares its menu in runtime.rs");
    container(slots, menu)
}

/// One container of `slots` slots, every face reaching all of them, with the content menu
/// `menu` the block opens.
fn container(slots: usize, menu: &str) -> ModContainer {
    let all: Vec<usize> = (0..slots).collect();
    // `..Default::default()` keeps a field a later game build adds from breaking this literal.
    #[expect(
        clippy::needless_update,
        reason = "the update is for a field a later game build may add"
    )]
    ModContainer {
        slots,
        faces: std::array::from_fn(|_| all.clone()),
        inputs: all.clone(),
        outputs: all,
        menu: Some(menu.to_owned()),
        ..ModContainer::default()
    }
}

// ---------------------------------------------------------------------------
// The Parts
// ---------------------------------------------------------------------------

/// The bookcase's block half: a comparator reads the redstone book it holds.
pub struct BookcasePart;

/// The shelf's block half: a plain container, so no block moment of its own.
pub struct ShelfPart;

#[mod_api::horizon_part]
impl BlockPart for BookcasePart {
    /// `BlockBehaviour.hasAnalogOutputSignal`: a bookcase answers a comparator.
    fn has_analog_output(&self, level: &dyn LevelHost, event: &mut HasAnalogOutputEvent) {
        if is_block(level, event.state, BOOKCASE) {
            event.output = true;
        }
    }

    /// `BlockBehaviour.getAnalogOutputSignal`: the slot index of the highest slot holding a
    /// redstone book, as the book entity's tick last read it (upstream `BookcaseBlock:57-66`).
    fn analog_output(&self, level: &dyn LevelHost, event: &mut AnalogOutputEvent) {
        if !is_block(level, event.state, BOOKCASE) {
            return;
        }
        let dimension = event.dimension.key().id().to_owned();
        let pos = [event.pos.x, event.pos.y, event.pos.z];
        let guard = core();
        if let Some(reading) = guard
            .as_ref()
            .and_then(|state| state.signal.get(&(dimension, pos)))
        {
            event.output = reading.value;
        }
    }
}

#[mod_api::horizon_part]
impl BlockPart for ShelfPart {}

#[mod_api::horizon_part]
impl BlockEntityPart for BookcasePart {
    /// `EntityBlock.getTicker`: a bookcase ticks, to keep only books and to read its comparator.
    fn block_entity_ticks(&self, _host: &dyn Host, event: &mut BlockEntityTicksEvent<'_>) {
        event.ticks = true;
    }

    /// One server tick: materialise the slots, hand back anything that is not a book, and note the
    /// comparator answer.
    fn block_entity_tick(&self, host: &mut dyn ServerHost, event: &mut BlockEntityTickEvent<'_>) {
        bookcase_tick(host, event);
    }

    /// The bookcase's menu layout: upstream's two rows of eight, the player's inventory beneath.
    fn screen(&self, _host: &dyn Host, event: &mut ScreenEvent<'_>) -> Option<Screen> {
        let slots = slots(event.block)?;
        let positions = (0..slots)
            .map(|index| {
                let column = index % 8;
                let row = index / 8;
                Some([17.0 + column as f32 * 18.0, 17.0 + row as f32 * 25.0])
            })
            .collect();
        Some(panel(positions))
    }
}

#[mod_api::horizon_part]
impl BlockEntityPart for ShelfPart {
    /// `EntityBlock.getTicker`: the shelf ticks only to materialise its slots.
    fn block_entity_ticks(&self, _host: &dyn Host, event: &mut BlockEntityTicksEvent<'_>) {
        event.ticks = true;
    }

    /// One server tick: materialise the four slots; the shelf keeps anything.
    fn block_entity_tick(&self, host: &mut dyn ServerHost, event: &mut BlockEntityTickEvent<'_>) {
        shelf_tick(host, event);
    }

    /// The shelf's menu layout: upstream's 2 x 2 grid (`ShelfMenu.addSlots`).
    fn screen(&self, _host: &dyn Host, event: &mut ScreenEvent<'_>) -> Option<Screen> {
        slots(event.block)?;
        let positions = vec![
            Some([53.0, 15.0]),
            Some([107.0, 15.0]),
            Some([53.0, 53.0]),
            Some([107.0, 53.0]),
        ];
        Some(panel(positions))
    }
}

/// A container panel of the given slot positions, with the player's inventory beneath it.
fn panel(positions: Vec<Option<[f32; 2]>>) -> Screen {
    Screen {
        width: PANEL_WIDTH,
        height: PANEL_HEIGHT,
        slots: positions,
        inventory_x: INVENTORY_X,
        inventory_y: INVENTORY_Y,
        ..Screen::default()
    }
}

// ---------------------------------------------------------------------------
// The ticks
// ---------------------------------------------------------------------------

/// A bookcase's tick: size the slots once, hand back anything that is not a book, and note the
/// comparator answer. Only a real change asks the game to save, so an idle bookcase does not dirty
/// its chunk every tick.
fn bookcase_tick(host: &mut dyn ServerHost, event: &mut BlockEntityTickEvent<'_>) {
    let pos = event.pos;
    let mut changed = false;
    if event.entity.items.len() != BOOKCASE_SLOTS {
        event.entity.items.resize(BOOKCASE_SLOTS, None);
        changed = true;
    }
    let level = level_in_place(&*host);
    let mut redstone = vec![false; BOOKCASE_SLOTS];
    for (index, has_redstone) in redstone.iter_mut().enumerate() {
        let Some(stack) = event.entity.items[index].as_ref() else {
            continue;
        };
        let is_book = item_in_tag(&*host, stack.item(), BOOKCASE_BOOKS);
        *has_redstone = is_book && stack.item().id(&*host) == REDSTONE_BOOK;
        if is_book {
            continue;
        }
        // Upstream's `isValid` refuses a non-book on insert; the pin's container has no slot
        // filter, so the tick hands it back instead (notes.md, deviation).
        let stack = event.entity.items[index].take();
        if let (Some(stack), Some(level)) = (stack, level) {
            eject(host, level, pos, stack);
        }
        changed = true;
    }
    note_signal(host, pos, signal(&redstone));
    if changed {
        *event.reply = BlockEntityTickReply::Changed;
    }
}

/// A shelf's tick: size the four slots once; anything may sit in them (upstream has no filter).
fn shelf_tick(_host: &mut dyn ServerHost, event: &mut BlockEntityTickEvent<'_>) {
    if event.entity.items.len() != SHELF_SLOTS {
        event.entity.items.resize(SHELF_SLOTS, None);
        *event.reply = BlockEntityTickReply::Changed;
    }
}

// ---------------------------------------------------------------------------
// Opening the menu
// ---------------------------------------------------------------------------

/// A click on a bookcase or shelf opens its menu, as a chest's use does.
///
/// The engine's own plain-click path (`game.rs::open_menu` → `open_mod_menu`) does not
/// open a mod block's content menu at this pin — measured on this package: a vanilla
/// barrel beside a bookcase opens 27 slots from the same click and the bookcase opened
/// none. The proven route (`rftoolsstorage`, `functionalstorage`, both green in game) is
/// the mod asking for its own menu: `Player::open_menu` against the block entity
/// (`Player.openMenu(provider)`, what a block's `getMenuProvider` would do). Both sides
/// consume the click, so the held item's use is not predicted behind it; only the server
/// opens anything, and a refused open leaves the click to the game.
pub fn right_click_block(host: HostSide<'_>, event: &mut RightClickBlockEvent<'_>) -> Flow {
    if event.cancelled {
        return Flow::Continue;
    }
    let click = event.click;
    let HostSide::Server(server) = host else {
        // The client consumes it too, so a held item is not used behind the menu.
        *event.cancellation_result = InteractionResult::Success;
        return Flow::Cancel;
    };
    if click.hand != Hand::Main {
        return Flow::Continue;
    }
    let Some(level) = server.level(server.dimension()) else {
        return Flow::Continue;
    };
    let Some(block) = level.block(&*server, click.pos) else {
        return Flow::Continue;
    };
    if slots(&block.id(&*server)).is_none() {
        return Flow::Continue;
    }
    let Some(entity) = server.block_entity(level, click.pos) else {
        return Flow::Continue;
    };
    let Some(player) = server.player(click.player) else {
        return Flow::Continue;
    };
    if !player.open_menu(server, entity).unwrap_or(false) {
        return Flow::Continue;
    }
    *event.cancellation_result = InteractionResult::Success;
    Flow::Cancel
}

// ---------------------------------------------------------------------------
// The comparator reading
// ---------------------------------------------------------------------------

/// Notes a bookcase's comparator answer, and queues one neighbour refresh when it differs from the
/// last one (a load, a menu, a hopper).
fn note_signal(host: &mut dyn ServerHost, pos: [i32; 3], value: i32) {
    let dimension = host.dimension().to_owned();
    let Some(level) = host.level(&dimension) else {
        return;
    };
    let mut guard = core();
    let state = guard.get_or_insert_with(Core::default);
    let tick = state.tick;
    let previous = state
        .signal
        .insert((dimension, pos), Signal { value, seen: tick });
    if previous.map(|reading| reading.value) != Some(value) && !state.output.contains(&(level, pos))
    {
        state.output.push((level, pos));
    }
}

/// After a level's tick pass: tell the neighbours of every bookcase whose answer changed to read it
/// again (`Level.updateNeighbourForOutputSignal`).
pub fn level_tick_post(host: HostSide<'_>, event: &mut LevelTickPostEvent) {
    let HostSide::Server(server) = host else {
        return;
    };
    let level = event.level;
    let positions = {
        let mut guard = core();
        let state = guard.get_or_insert_with(Core::default);
        let mut keep = Vec::new();
        let mut mine = Vec::new();
        for (entry_level, pos) in std::mem::take(&mut state.output) {
            if entry_level == level {
                mine.push(pos);
            } else {
                keep.push((entry_level, pos));
            }
        }
        state.output = keep;
        mine
    };
    for pos in positions {
        let Some(state) = level.block_state(&*server, pos) else {
            continue;
        };
        let _ = level.update_neighbors(server, pos, state, NeighbourUpdate::OutputSignal);
    }
    // Age the comparator readings: the map is keyed by position, so it must not outlive the
    // bookcases that refresh it (a chunk unloaded for a while reads 0 anyway).
    let mut guard = core();
    let state = guard.get_or_insert_with(Core::default);
    state.tick = state.tick.wrapping_add(1);
    let tick = state.tick;
    state
        .signal
        .retain(|_, reading| tick.saturating_sub(reading.seen) < SIGNAL_LIFETIME);
}

// ---------------------------------------------------------------------------
// Small helpers over the world
// ---------------------------------------------------------------------------

/// The level whose block entities the server ticks now: a block-entity tick is not told its level.
fn level_in_place(host: &dyn ServerHost) -> Option<LevelRef> {
    host.levels()
        .list_levels()
        .into_iter()
        .find(|level| level.in_place(host))
}

/// Whether `state` is `block`.
fn is_block(level: &dyn LevelHost, state: BlockState, block: &str) -> bool {
    level.state_block(state) == Some(block)
}

/// Whether `item` is in the server's merged item tag `tag`; an unknown tag answers false.
fn item_in_tag(host: &dyn Host, item: mod_api::ItemKey, tag: &str) -> bool {
    let Ok(tag) = mod_api::Identifier::parse(tag) else {
        return false;
    };
    let Some(key) = host.tags().key(&tag) else {
        return false;
    };
    host.tags().is_in_tag(item, key).unwrap_or(false)
}

/// Drops `stack` at the block's centre, as `Block.popResource` does for a stack that is refused.
fn eject(host: &mut dyn ServerHost, level: LevelRef, pos: [i32; 3], stack: ItemStack) {
    if stack.count() == 0 {
        return;
    }
    let _ = level.spawn_item(
        host,
        f64::from(pos[0]) + 0.5,
        f64::from(pos[1]) + 0.5,
        f64::from(pos[2]) + 0.5,
        stack,
        10,
    );
}

/// The block entity's own type and the menu the content declares — used by the port's tests to
/// keep the two declarations in step with `runtime.rs`.
#[cfg(test)]
mod tests {
    use super::{BOOKCASE, BOOKCASE_SLOTS, SHELF, SHELF_SLOTS, container_of};
    use crate::runtime::{BOOKCASE_MENU, SHELF_MENU};

    #[test]
    fn every_face_reaches_every_slot() {
        let container = container_of(BOOKCASE);
        let all: Vec<usize> = (0..BOOKCASE_SLOTS).collect();
        assert_eq!(container.slots, BOOKCASE_SLOTS);
        for face in container.faces {
            assert_eq!(face, all, "a hopper on every face reaches every slot");
        }
        assert_eq!(container.inputs, all);
        assert_eq!(container.outputs, all);
        assert_eq!(container.menu.as_deref(), Some(BOOKCASE_MENU));
    }

    #[test]
    fn the_shelf_container_is_four_slots_and_its_own_menu() {
        let container = container_of(SHELF);
        assert_eq!(container.slots, SHELF_SLOTS);
        assert_eq!(container.menu.as_deref(), Some(SHELF_MENU));
    }
}
