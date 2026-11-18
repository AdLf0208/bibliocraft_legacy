#!/usr/bin/env python3
"""Generate the Bibliocraft Legacy slice-1 content tree from upstream.

Slice 1 is four plain furniture blocks, all decorative and block-entity-free:

- `bibliocraft:oak_bookcase` and `bibliocraft:oak_shelf` (facing + waterlogged,
  8 states each) on the `minecraft:white_glazed_terracotta` template, whose placement
  (`getHorizontalDirection().getOpposite()`) is upstream `BCFacingBlock`'s;
- `bibliocraft:black_oak_seat` (occupied + waterlogged, 4 states) and
  `bibliocraft:desk_bell` (waterlogged, 2 states) on the
  `minecraft:mangrove_roots` template, which supplies waterlogging only.

The upstream bookcase/shelf inventories, the seat entity, the desk bell's
sound and the redstone/enchant answers are deferred. Models are the upstream
MIT assets, adapted to 26.3: the bookcase/shelf/seat models reference vanilla
plank/wool textures, so this slice ships no textures of its own.

Usage:
    python3 tools/gen_content.py --upstream ../_shared/upstream/bibliocraft

Since 0.2.0 (the SDK package) the tool writes the package root's `assets/` and
`data/`; the upstream checkout was deleted after the findings were recorded, so
re-running it needs a fresh `git clone --depth 1` of the repository first.
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

BOOKCASE_NORTH = [
    [0.0625, 0.0, 0.5, 0.9375, 0.0625, 0.9375],
    [0.0, 0.0, 0.9375, 1.0, 1.0, 1.0],
    [0.0625, 0.9375, 0.5, 0.9375, 1.0, 0.9375],
    [0.0625, 0.4375, 0.5, 0.9375, 0.5625, 0.9375],
    [0.9375, 0.0, 0.5, 1.0, 1.0, 0.9375],
    [0.0, 0.0, 0.5, 0.0625, 1.0, 0.9375],
]
SHELF_NORTH = [[0.0, 0.0, 0.5, 1.0, 1.0, 1.0]]
SEAT_BOXES = [
    [0.0625, 0.625, 0.0625, 0.9375, 0.8125, 0.9375],
    [0.125, 0.8125, 0.125, 0.875, 0.875, 0.875],
    [0.1875, 0.0, 0.1875, 0.3125, 0.625, 0.3125],
    [0.6875, 0.0, 0.1875, 0.8125, 0.625, 0.3125],
    [0.6875, 0.0, 0.6875, 0.8125, 0.625, 0.8125],
    [0.1875, 0.0, 0.6875, 0.3125, 0.625, 0.8125],
    [0.21875, 0.28125, 0.3125, 0.28125, 0.34375, 0.6875],
    [0.71875, 0.28125, 0.3125, 0.78125, 0.34375, 0.6875],
    [0.3125, 0.28125, 0.21875, 0.6875, 0.34375, 0.28125],
    [0.3125, 0.28125, 0.71875, 0.6875, 0.34375, 0.78125],
]
DESK_BELL_BOXES = [
    [0.375, 0.0, 0.375, 0.625, 0.125, 0.625],
    [0.40625, 0.125, 0.40625, 0.59375, 0.15625, 0.59375],
    [0.40625, 0.0, 0.34375, 0.59375, 0.09375, 0.375],
    [0.40625, 0.0, 0.625, 0.59375, 0.09375, 0.65625],
    [0.34375, 0.0, 0.40625, 0.375, 0.09375, 0.59375],
    [0.625, 0.0, 0.40625, 0.65625, 0.09375, 0.59375],
    [0.484375, 0.15625, 0.484375, 0.515625, 0.171875, 0.515625],
    [0.46875, 0.171875, 0.46875, 0.53125, 0.203125, 0.53125],
]

FACINGS = ["north", "east", "south", "west"]
ROTATION = {"north": 0, "east": 90, "south": 180, "west": 270}


def rotate_y(box: list[float], quarter_turns: int) -> list[float]:
    """Rotate a block-space box clockwise around Y, as `ShapeUtil.rotate`."""
    x1, y1, z1, x2, y2, z2 = box
    for _ in range(quarter_turns % 4):
        x1, z1, x2, z2 = 1.0 - z2, x1, 1.0 - z1, x2
    return [x1, y1, z1, x2, y2, z2]


def facing_boxes(north: list[list[float]]) -> dict[str, list[list[float]]]:
    return {
        facing: [rotate_y(box, ROTATION[facing] // 90) for box in north]
        for facing in FACINGS
    }


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, str):
        path.write_text(value)
    else:
        path.write_text(json.dumps(value, indent=2) + "\n")


def copy_file(source: Path, target: Path) -> None:
    if not source.is_file():
        raise SystemExit(f"missing upstream file: {source}")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--upstream",
        type=Path,
        default=Path(__file__).resolve().parents[2]
        / "_shared/upstream/bibliocraft",
    )
    parser.add_argument(
        # The package root: since the SDK migration (0.2.0) the carried content
        # lives at the root of the flat `.hmod` (`assets/` + `data/`), beside
        # `src/` and the one root `horizon-mod.toml`. There is no `content/` any
        # more — the retired tree is evidence under `_shared/evidence/bibliocraft/`.
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    args = parser.parse_args()
    upstream = args.upstream.resolve()
    out = args.out.resolve()
    if not (upstream / "gradle.properties").exists():
        raise SystemExit(f"no upstream checkout at {upstream}")

    assets = out / "assets/bibliocraft"
    data = out / "data"
    generated = upstream / "src/main/generated"
    resources = upstream / "src/main/resources"

    for directory in (assets, data):
        if directory.exists():
            shutil.rmtree(directory)

    # ------------------------------------------------------------- models
    copy_file(
        resources / "assets/bibliocraft/models/block/template/bookcase/bookcase.json",
        assets / "models/block/template/bookcase/bookcase.json",
    )
    copy_file(
        resources / "assets/bibliocraft/models/block/template/shelf.json",
        assets / "models/block/template/shelf.json",
    )
    copy_file(
        resources / "assets/bibliocraft/models/block/template/seat/seat.json",
        assets / "models/block/template/seat/seat.json",
    )
    copy_file(
        resources / "assets/bibliocraft/models/block/desk_bell.json",
        assets / "models/block/desk_bell.json",
    )
    copy_file(
        generated / "assets/bibliocraft/models/block/wood/oak/bookcase.json",
        assets / "models/block/wood/oak/bookcase.json",
    )
    copy_file(
        generated / "assets/bibliocraft/models/block/wood/oak/shelf.json",
        assets / "models/block/wood/oak/shelf.json",
    )
    copy_file(
        generated / "assets/bibliocraft/models/block/color/black/wood/oak/seat.json",
        assets / "models/block/color/black/wood/oak/seat.json",
    )

    # --------------------------------------------------------- blockstates
    for name, model in (
        ("oak_bookcase", "bibliocraft:block/wood/oak/bookcase"),
        ("oak_shelf", "bibliocraft:block/wood/oak/shelf"),
    ):
        variants = {}
        for facing in FACINGS:
            entry = {"model": model, "uvlock": True}
            if ROTATION[facing]:
                entry["y"] = ROTATION[facing]
            variants[f"facing={facing}"] = entry
        write(assets / f"blockstates/{name}.json", {"variants": variants})
    write(
        assets / "blockstates/black_oak_seat.json",
        {"variants": {"": {"model": "bibliocraft:block/color/black/wood/oak/seat"}}},
    )
    write(
        assets / "blockstates/desk_bell.json",
        {"variants": {"": {"model": "bibliocraft:block/desk_bell"}}},
    )

    # ------------------------------------------------------- item definitions
    for name in ("oak_bookcase", "oak_shelf", "black_oak_seat", "desk_bell"):
        copy_file(
            generated / f"assets/bibliocraft/items/{name}.json",
            assets / f"items/{name}.json",
        )

    # ---------------------------------------------------------------- lang
    upstream_lang = json.loads(
        (generated / "assets/bibliocraft/lang/en_us.json").read_text()
    )
    keys = [
        "block.bibliocraft.oak_bookcase",
        "block.bibliocraft.oak_shelf",
        "block.bibliocraft.black_oak_seat",
        "block.bibliocraft.desk_bell",
        "itemGroup.bibliocraft",
    ]
    write(
        assets / "lang/en_us.json",
        {key: upstream_lang[key] for key in keys if key in upstream_lang},
    )

    # -------------------------------------------------------- block declarations
    wood = {
        "hardness": 2.0,
        "explosion_resistance": 3.0,
        "requires_tool": False,
        "sounds": "minecraft:oak_planks",
        "map_color": 13,
    }
    bookcase = {
        "template": "minecraft:white_glazed_terracotta",
        "properties": wood,
        "state_properties": {"waterlogged": {"type": "boolean"}},
        "default_state": {"facing": "north", "waterlogged": "false"},
        "shapes": {"property": "facing", "values": facing_boxes(BOOKCASE_NORTH)},
        "item": True,
    }
    shelf = {
        "template": "minecraft:white_glazed_terracotta",
        "properties": wood,
        "state_properties": {"waterlogged": {"type": "boolean"}},
        "default_state": {"facing": "north", "waterlogged": "false"},
        "shapes": {"property": "facing", "values": facing_boxes(SHELF_NORTH)},
        "item": True,
    }
    seat = {
        # `oak_log` has exactly `axis`; its name sorts before `occupied`, so
        # the declared properties fan out after the template state and the
        # registry's state order stays valid. The seat is not directional, so
        # the extra axis state is a documented template artefact.
        "template": "minecraft:oak_log",
        "properties": wood,
        "state_properties": {
            "occupied": {"type": "boolean"},
            "waterlogged": {"type": "boolean"},
        },
        "default_state": {"axis": "y", "occupied": "false", "waterlogged": "false"},
        "shapes": {
            "property": "axis",
            "values": {"x": SEAT_BOXES, "y": SEAT_BOXES, "z": SEAT_BOXES},
        },
        "item": True,
    }
    desk_bell = {
        "template": "minecraft:mangrove_roots",
        "properties": {
            "hardness": 5.0,
            "explosion_resistance": 6.0,
            "requires_tool": True,
            "sounds": "minecraft:iron_block",
            "map_color": 33,
        },
        "default_state": {"waterlogged": "false"},
        "shapes": {
            "property": "waterlogged",
            "values": {"false": DESK_BELL_BOXES, "true": DESK_BELL_BOXES},
        },
        "item": True,
    }
    for name, declaration in (
        ("oak_bookcase", bookcase),
        ("oak_shelf", shelf),
        ("black_oak_seat", seat),
        ("desk_bell", desk_bell),
    ):
        write(data / f"bibliocraft/horizon/block/{name}.json", declaration)

    # ---------------------------------------------------------------- recipes
    recipe_sources = {
        "oak_bookcase": "wood/oak/bookcase.json",
        "oak_shelf": "wood/oak/shelf.json",
        "black_oak_seat": "color/black/wood/oak/seat.json",
        "desk_bell": "desk_bell.json",
    }
    for name, relative in recipe_sources.items():
        recipe = json.loads(
            (generated / f"data/bibliocraft/recipe/{relative}").read_text()
        )
        write(data / f"bibliocraft/recipe/{name}.json", recipe)

    # ------------------------------------------------------------------ loot
    for name in ("oak_bookcase", "oak_shelf", "black_oak_seat", "desk_bell"):
        write(
            data / f"bibliocraft/loot_table/blocks/{name}.json",
            {
                "type": "minecraft:block",
                "pools": [
                    {
                        # 26.3 uses one `condition` object, not 1.21's
                        # `conditions` list plus `bonus_rolls`.
                        "condition": {"type": "minecraft:survives_explosion"},
                        "entries": [
                            {
                                "type": "minecraft:item",
                                "name": f"bibliocraft:{name}",
                            }
                        ],
                        "rolls": 1,
                    }
                ],
                "random_sequence": f"bibliocraft:blocks/{name}",
            },
        )

    # ------------------------------------------------------------------ tags
    for tag, values in (
        ("bookcases", ["bibliocraft:oak_bookcase"]),
        ("shelves", ["bibliocraft:oak_shelf"]),
        ("seats", ["bibliocraft:black_oak_seat"]),
    ):
        write(data / f"bibliocraft/tags/block/{tag}.json", {"values": values})
        write(data / f"bibliocraft/tags/item/{tag}.json", {"values": values})
    write(
        data / "minecraft/tags/block/mineable/axe.json",
        {
            "values": [
                "#bibliocraft:bookcases",
                "#bibliocraft:shelves",
                "#bibliocraft:seats",
            ]
        },
    )
    write(
        data / "minecraft/tags/block/mineable/pickaxe.json",
        {"values": ["bibliocraft:desk_bell"]},
    )
    # The seat recipe's wooden-rod ingredient, and the desk bell's iron and
    # redstone, in the 26.3 convention-tag form (the pack ships no `c` tags).
    write(data / "c/tags/item/rods/wooden.json", {"values": ["minecraft:stick"]})
    write(data / "c/tags/item/ingots/iron.json", {"values": ["minecraft:iron_ingot"]})
    write(data / "c/tags/item/dusts/redstone.json", {"values": ["minecraft:redstone"]})

    # --------------------------------------------------------- creative tab
    write(
        data / "bibliocraft/horizon/creative_tab/bibliocraft.json",
        {
            "title": "Bibliocraft",
            "icon": "bibliocraft:oak_bookcase",
            "items": [
                "bibliocraft:oak_bookcase",
                "bibliocraft:oak_shelf",
                "bibliocraft:black_oak_seat",
                "bibliocraft:desk_bell",
            ],
        },
    )

    # The manifest is NOT generated: since 0.2.0 the root `horizon-mod.toml` is
    # the package's only identity (id, version, api, capabilities and the exact
    # `[native]` pins), and a generator that rewrote it would drop the pins.
    # This tool owns `assets/` and `data/` only.


if __name__ == "__main__":
    main()
