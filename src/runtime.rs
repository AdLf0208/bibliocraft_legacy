// Bibliocraft Legacy for Horizon — the slice-1 furniture model (pure).
//
// Ported from Bibliocraft Legacy 26.1.2-1.7.1
// (`MinecraftschurliMods/Bibliocraft-Legacy`, MIT) for Minecraft 26.3.
// Upstream source was read for behaviour only; this is a clean-room Rust
// rewrite. Slice 1 is content-only: the four plain furniture blocks are
// declared in `../content`, and this model is the single place their
// templates, state counts and shape boxes are spelled out.
//
// The four blocks are `oak_bookcase`, `oak_shelf`, `black_oak_seat` and
// `desk_bell`. Each is a decorative block: the upstream bookcase/shelf
// inventories, the seat entity, the desk bell's sound and the redstone/enchant
// answers are deferred (see `../notes.md`).

#[cfg(test)]
mod model {
    /// A horizontal facing, in vanilla's order (`north`, `east`, `south`, `west`).
    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    pub enum Facing {
        North,
        East,
        South,
        West,
    }

    impl Facing {
        /// Every horizontal facing, clockwise from north.
        pub const ALL: [Self; 4] = [Self::North, Self::East, Self::South, Self::West];

        /// The facing one clockwise quarter-turn away.
        #[must_use]
        pub const fn clockwise(self) -> Self {
            match self {
                Self::North => Self::East,
                Self::East => Self::South,
                Self::South => Self::West,
                Self::West => Self::North,
            }
        }

        /// Clockwise quarter-turns from north, as `rotate_y` takes them.
        const fn quarter_turns(self) -> u8 {
            match self {
                Self::North => 0,
                Self::East => 1,
                Self::South => 2,
                Self::West => 3,
            }
        }
    }

    /// An axis-aligned box in block space (`0..1` on each axis).
    #[derive(Clone, Copy, Debug, PartialEq)]
    pub struct Box3 {
        /// The minimum corner.
        pub min: [f64; 3],
        /// The maximum corner.
        pub max: [f64; 3],
    }

    impl Box3 {
        /// A box from its two corners.
        #[must_use]
        pub const fn new(min: [f64; 3], max: [f64; 3]) -> Self {
            Self { min, max }
        }

        /// The box as `[min_x, min_y, min_z, max_x, max_y, max_z]`, the content
        /// format's shape row.
        #[must_use]
        pub const fn to_array(self) -> [f64; 6] {
            [
                self.min[0],
                self.min[1],
                self.min[2],
                self.max[0],
                self.max[1],
                self.max[2],
            ]
        }
    }

    /// Rotate a box clockwise around Y, as upstream `ShapeUtil.rotate` does.
    #[must_use]
    pub fn rotate_y(box3: Box3, quarter_turns: u8) -> Box3 {
        let [mut x1, y1, mut z1, mut x2, y2, mut z2] = box3.to_array();
        for _ in 0..(quarter_turns % 4) {
            let (next_x1, next_z1, next_x2, next_z2) = (1.0 - z2, x1, 1.0 - z1, x2);
            x1 = next_x1;
            z1 = next_z1;
            x2 = next_x2;
            z2 = next_z2;
        }
        Box3::new([x1, y1, z1], [x2, y2, z2])
    }

    /// The bookcase's north-facing boxes (`BookcaseBlock.java:22-28`).
    const BOOKCASE_NORTH: [Box3; 6] = [
        Box3::new([0.0625, 0.0, 0.5], [0.9375, 0.0625, 0.9375]),
        Box3::new([0.0, 0.0, 0.9375], [1.0, 1.0, 1.0]),
        Box3::new([0.0625, 0.9375, 0.5], [0.9375, 1.0, 0.9375]),
        Box3::new([0.0625, 0.4375, 0.5], [0.9375, 0.5625, 0.9375]),
        Box3::new([0.9375, 0.0, 0.5], [1.0, 1.0, 0.9375]),
        Box3::new([0.0, 0.0, 0.5], [0.0625, 1.0, 0.9375]),
    ];

    /// The shelf's north-facing box (`ShelfBlock.java:20`).
    const SHELF_NORTH: [Box3; 1] = [Box3::new([0.0, 0.0, 0.5], [1.0, 1.0, 1.0])];

    /// The seat's fixed ten boxes (`SeatBlock.java:30-39`).
    const SEAT: [Box3; 10] = [
        Box3::new([0.0625, 0.625, 0.0625], [0.9375, 0.8125, 0.9375]),
        Box3::new([0.125, 0.8125, 0.125], [0.875, 0.875, 0.875]),
        Box3::new([0.1875, 0.0, 0.1875], [0.3125, 0.625, 0.3125]),
        Box3::new([0.6875, 0.0, 0.1875], [0.8125, 0.625, 0.3125]),
        Box3::new([0.6875, 0.0, 0.6875], [0.8125, 0.625, 0.8125]),
        Box3::new([0.1875, 0.0, 0.6875], [0.3125, 0.625, 0.8125]),
        Box3::new([0.21875, 0.28125, 0.3125], [0.28125, 0.34375, 0.6875]),
        Box3::new([0.71875, 0.28125, 0.3125], [0.78125, 0.34375, 0.6875]),
        Box3::new([0.3125, 0.28125, 0.21875], [0.6875, 0.34375, 0.28125]),
        Box3::new([0.3125, 0.28125, 0.71875], [0.6875, 0.34375, 0.78125]),
    ];

    /// The desk bell's fixed eight boxes (`DeskBellBlock.java:30-38`).
    const DESK_BELL: [Box3; 8] = [
        Box3::new([0.375, 0.0, 0.375], [0.625, 0.125, 0.625]),
        Box3::new([0.40625, 0.125, 0.40625], [0.59375, 0.15625, 0.59375]),
        Box3::new([0.40625, 0.0, 0.34375], [0.59375, 0.09375, 0.375]),
        Box3::new([0.40625, 0.0, 0.625], [0.59375, 0.09375, 0.65625]),
        Box3::new([0.34375, 0.0, 0.40625], [0.375, 0.09375, 0.59375]),
        Box3::new([0.625, 0.0, 0.40625], [0.65625, 0.09375, 0.59375]),
        Box3::new(
            [0.484375, 0.15625, 0.484375],
            [0.515625, 0.171875, 0.515625],
        ),
        Box3::new([0.46875, 0.171875, 0.46875], [0.53125, 0.203125, 0.53125]),
    ];

    /// The four blocks in slice 1.
    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    pub enum Block {
        Bookcase,
        Shelf,
        Seat,
        DeskBell,
    }

    impl Block {
        /// Every block in the slice.
        pub const ALL: [Self; 4] = [Self::Bookcase, Self::Shelf, Self::Seat, Self::DeskBell];

        /// The block's registry id.
        #[must_use]
        pub const fn id(self) -> &'static str {
            match self {
                Self::Bookcase => "bibliocraft:oak_bookcase",
                Self::Shelf => "bibliocraft:oak_shelf",
                Self::Seat => "bibliocraft:black_oak_seat",
                Self::DeskBell => "bibliocraft:desk_bell",
            }
        }

        /// The vanilla template whose class and states the block copies.
        #[must_use]
        pub const fn template(self) -> &'static str {
            match self {
                Self::Bookcase | Self::Shelf => "minecraft:white_glazed_terracotta",
                Self::Seat => "minecraft:oak_log",
                Self::DeskBell => "minecraft:mangrove_roots",
            }
        }

        /// How many states the block declares: the template's times its own.
        #[must_use]
        pub const fn state_count(self) -> usize {
            match self {
                Self::Bookcase | Self::Shelf => 8,
                Self::Seat => 12,
                Self::DeskBell => 2,
            }
        }

        /// The template state property the content `shapes` selector reads.
        #[must_use]
        pub const fn shape_property(self) -> &'static str {
            match self {
                Self::Bookcase | Self::Shelf => "facing",
                Self::Seat => "axis",
                Self::DeskBell => "waterlogged",
            }
        }

        /// The block's outline/collision boxes. `facing` turns the directional
        /// blocks; `waterlogged` does not change any slice-1 shape.
        #[must_use]
        pub fn shape(self, facing: Facing, _waterlogged: bool) -> Vec<Box3> {
            match self {
                Self::Bookcase => bookcase_shape(facing),
                Self::Shelf => shelf_shape(facing),
                Self::Seat => seat_shape(),
                Self::DeskBell => desk_bell_shape(),
            }
        }
    }

    /// The bookcase shape for a facing.
    #[must_use]
    pub fn bookcase_shape(facing: Facing) -> Vec<Box3> {
        rotate_all(&BOOKCASE_NORTH, facing)
    }

    /// The shelf shape for a facing.
    #[must_use]
    pub fn shelf_shape(facing: Facing) -> Vec<Box3> {
        rotate_all(&SHELF_NORTH, facing)
    }

    /// The seat shape (fixed, no facing).
    #[must_use]
    pub fn seat_shape() -> Vec<Box3> {
        SEAT.to_vec()
    }

    /// The desk bell shape (fixed, no facing).
    #[must_use]
    pub fn desk_bell_shape() -> Vec<Box3> {
        DESK_BELL.to_vec()
    }

    fn rotate_all(boxes: &[Box3], facing: Facing) -> Vec<Box3> {
        boxes
            .iter()
            .map(|box3| rotate_y(*box3, facing.quarter_turns()))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::model::*;

    fn boxes(shape: &[Box3]) -> Vec<[f64; 6]> {
        shape.iter().map(|box3| box3.to_array()).collect()
    }

    #[test]
    fn bookcase_north_has_the_six_upstream_boxes() {
        assert_eq!(
            boxes(&bookcase_shape(Facing::North)),
            vec![
                [0.0625, 0.0, 0.5, 0.9375, 0.0625, 0.9375],
                [0.0, 0.0, 0.9375, 1.0, 1.0, 1.0],
                [0.0625, 0.9375, 0.5, 0.9375, 1.0, 0.9375],
                [0.0625, 0.4375, 0.5, 0.9375, 0.5625, 0.9375],
                [0.9375, 0.0, 0.5, 1.0, 1.0, 0.9375],
                [0.0, 0.0, 0.5, 0.0625, 1.0, 0.9375],
            ]
        );
    }

    #[test]
    fn bookcase_east_is_the_north_shape_rotated_clockwise() {
        let north = bookcase_shape(Facing::North);
        let east = bookcase_shape(Facing::East);
        let rotated: Vec<Box3> = north.iter().map(|box3| rotate_y(*box3, 1)).collect();
        assert_eq!(east, rotated);
        assert_eq!(east[5].to_array(), [0.0625, 0.0, 0.0, 0.5, 1.0, 0.0625]);
    }

    #[test]
    fn shelf_is_one_wall_box_and_rotates() {
        assert_eq!(
            boxes(&shelf_shape(Facing::North)),
            vec![[0.0, 0.0, 0.5, 1.0, 1.0, 1.0]]
        );
        assert_eq!(
            boxes(&shelf_shape(Facing::East)),
            vec![[0.0, 0.0, 0.0, 0.5, 1.0, 1.0]]
        );
        assert_eq!(
            boxes(&shelf_shape(Facing::South)),
            vec![[0.0, 0.0, 0.0, 1.0, 1.0, 0.5]]
        );
        assert_eq!(
            boxes(&shelf_shape(Facing::West)),
            vec![[0.5, 0.0, 0.0, 1.0, 1.0, 1.0]]
        );
    }

    #[test]
    fn seat_has_the_ten_upstream_boxes() {
        let seat = boxes(&seat_shape());
        assert_eq!(seat.len(), 10);
        assert_eq!(seat[0], [0.0625, 0.625, 0.0625, 0.9375, 0.8125, 0.9375]);
        assert_eq!(seat[1], [0.125, 0.8125, 0.125, 0.875, 0.875, 0.875]);
        assert_eq!(
            seat[9],
            [0.3125, 0.28125, 0.71875, 0.6875, 0.34375, 0.78125]
        );
    }

    #[test]
    fn desk_bell_has_the_eight_upstream_boxes() {
        let bell = boxes(&desk_bell_shape());
        assert_eq!(bell.len(), 8);
        assert_eq!(bell[0], [0.375, 0.0, 0.375, 0.625, 0.125, 0.625]);
        assert_eq!(
            bell[7],
            [0.46875, 0.171875, 0.46875, 0.53125, 0.203125, 0.53125]
        );
    }

    #[test]
    fn state_counts_are_the_declared_spaces() {
        // The seat's 12 includes the oak_log template's three axis values;
        // the upstream seat has 4 (occupied x waterlogged).
        assert_eq!(Block::Bookcase.state_count(), 8);
        assert_eq!(Block::Shelf.state_count(), 8);
        assert_eq!(Block::Seat.state_count(), 12);
        assert_eq!(Block::DeskBell.state_count(), 2);
    }

    #[test]
    fn all_four_ids_are_namespaced() {
        assert_eq!(Block::ALL.len(), 4);
        for block in Block::ALL {
            assert!(block.id().starts_with("bibliocraft:"), "{}", block.id());
        }
        assert_eq!(Block::Bookcase.id(), "bibliocraft:oak_bookcase");
        assert_eq!(Block::Shelf.id(), "bibliocraft:oak_shelf");
        assert_eq!(Block::Seat.id(), "bibliocraft:black_oak_seat");
        assert_eq!(Block::DeskBell.id(), "bibliocraft:desk_bell");
    }

    #[test]
    fn templates_are_vanilla_and_match_the_placement_model() {
        assert_eq!(
            Block::Bookcase.template(),
            "minecraft:white_glazed_terracotta"
        );
        assert_eq!(Block::Shelf.template(), "minecraft:white_glazed_terracotta");
        assert_eq!(Block::Seat.template(), "minecraft:oak_log");
        assert_eq!(Block::DeskBell.template(), "minecraft:mangrove_roots");
    }

    #[test]
    fn waterlogged_does_not_change_a_shape() {
        for block in [Block::Bookcase, Block::Shelf] {
            for facing in Facing::ALL {
                assert_eq!(
                    block.shape(facing, false),
                    block.shape(facing, true),
                    "{} {facing:?}",
                    block.id()
                );
            }
        }
        assert_eq!(Block::Seat.shape(Facing::North, false), seat_shape());
        assert_eq!(Block::Seat.shape(Facing::North, true), seat_shape());
        assert_eq!(
            Block::DeskBell.shape(Facing::North, false),
            desk_bell_shape()
        );
        assert_eq!(
            Block::DeskBell.shape(Facing::North, true),
            desk_bell_shape()
        );
    }

    #[test]
    fn facing_rotation_is_a_four_cycle() {
        // Exact binary fractions keep the four-turn comparison exact.
        let sample = Box3::new([0.125, 0.25, 0.375], [0.5, 0.625, 0.75]);
        let mut box3 = sample;
        for _ in 0..4 {
            box3 = rotate_y(box3, 1);
        }
        assert_eq!(box3, sample);
        assert_eq!(Facing::North.clockwise(), Facing::East);
        assert_eq!(Facing::East.clockwise(), Facing::South);
        assert_eq!(Facing::South.clockwise(), Facing::West);
        assert_eq!(Facing::West.clockwise(), Facing::North);
    }

    #[test]
    fn shape_property_is_the_template_property_used_by_the_content() {
        assert_eq!(Block::Bookcase.shape_property(), "facing");
        assert_eq!(Block::Shelf.shape_property(), "facing");
        assert_eq!(Block::Seat.shape_property(), "axis");
        assert_eq!(Block::DeskBell.shape_property(), "waterlogged");
    }
}
