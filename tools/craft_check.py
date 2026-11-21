#!/usr/bin/env python3
"""Craft the Bibliocraft port's recipes in a real crafting table.

Called by tools/e2e.sh with the open game's control socket. Uses the harness's
crafting grid (`ctl screen`: slots 100-108 row-major, result 200), gives the
ingredients, and asserts:

1. six oak planks + three oak slabs -> one `bibliocraft:oak_bookcase`
   (`PSP/PSP/PSP`);
2. six oak slabs + one oak plank -> one `bibliocraft:oak_shelf`
   (`SSS/P/SSS`);
3. one black wool + one oak slab + two sticks -> one
   `bibliocraft:black_oak_seat` (` W / S /RSR`);
4. one stone button + three iron ingots + one redstone -> one
   `bibliocraft:desk_bell` (` B / I /IRI`);
5. a book and a redstone torch (shapeless) -> one
   `bibliocraft:redstone_book` (slice 2);
6. six sticks in the bookcase's plank slots leave the result empty
   (a deliberately unmatched item: oak planks would make the bookcase), and
   two books in the shapeless grid leave it empty as well.

The table is replaced before every case, so a failed/untaken result cannot
leak into the next grid. Exits 1 with the observed result on the first
mismatch.
"""
import json
import subprocess
import sys

# Bookcase `PSP/PSP/PSP`: the six P cells and the three S cells.
BOOKCASE_PLANKS = [100, 102, 103, 105, 106, 108]
BOOKCASE_SLABS = [101, 104, 107]
# Shelf `SSS/P/SSS`: the six S cells and the one P cell.
SHELF_SLABS = [100, 101, 102, 106, 107, 108]
SHELF_PLANK = [104]


def main():
    sock, ctl, x, y, z = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

    def run(*args):
        out = subprocess.run([ctl, "--socket", sock, *args], text=True, capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise SystemExit(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(ticks=4):
        run("wait", str(ticks))

    def slots():
        screen = run("screen")
        if "slots" not in screen:
            raise SystemExit(f"no menu is open: {screen}")
        return screen["slots"]

    def find(item):
        for slot in slots():
            if slot.get("item") == item:
                return slot["slot"]
        raise SystemExit(f"missing ingredient {item} in the inventory")

    def open_table():
        wait()
        run("interact", x, y, z)
        wait(5)

    def result():
        stack = [s for s in slots() if s["slot"] == 200]
        if not stack or not stack[0].get("item"):
            return None
        return stack[0]

    def place(item, mode, targets):
        slot = find(item)
        run("click-slot", str(slot))
        wait(1)
        for target in targets:
            if mode == "right":
                run("click-slot", str(target), "right")
            else:
                run("click-slot", str(target))
            wait(1)
        run("click-slot", str(slot))
        wait(2)

    def setup(items):
        try:
            run("close")
        except SystemExit:
            pass
        wait(5)
        run("setblock", x, y, z, "minecraft:air")
        run("setblock", x, y, z, "minecraft:crafting_table")
        wait(2)
        run("command", f"tp @s {float(x) - 0.5} {y} {float(z) + 0.5}")
        wait(3)
        run("command", "clear @s")
        for item, count in items:
            run("give", item, str(count))
        wait(3)
        open_table()

    failures = []

    def check(label, items, placements, want_item, want_count):
        setup(items)
        for item, mode, targets in placements:
            place(item, mode, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if want_item is None:
            if got is not None:
                failures.append(f"{label}: expected an empty result, got {got}")
        elif not got or got.get("item") != want_item or got.get("count") != want_count:
            failures.append(f"{label}: expected {want_count} {want_item}, got {got}")

    check(
        "bookcase",
        [("minecraft:oak_planks", 6), ("minecraft:oak_slab", 3)],
        [
            ("minecraft:oak_planks", "right", BOOKCASE_PLANKS),
            ("minecraft:oak_slab", "right", BOOKCASE_SLABS),
        ],
        "bibliocraft:oak_bookcase",
        1,
    )
    check(
        "shelf",
        [("minecraft:oak_slab", 6), ("minecraft:oak_planks", 1)],
        [
            ("minecraft:oak_slab", "right", SHELF_SLABS),
            ("minecraft:oak_planks", "left", SHELF_PLANK),
        ],
        "bibliocraft:oak_shelf",
        1,
    )
    check(
        "seat",
        [("minecraft:black_wool", 1), ("minecraft:oak_slab", 2), ("minecraft:stick", 2)],
        [
            ("minecraft:black_wool", "left", [101]),
            ("minecraft:oak_slab", "right", [104, 107]),
            ("minecraft:stick", "right", [106, 108]),
        ],
        "bibliocraft:black_oak_seat",
        1,
    )
    check(
        "desk_bell",
        [
            ("minecraft:stone_button", 1),
            ("minecraft:iron_ingot", 3),
            ("minecraft:redstone", 1),
        ],
        [
            ("minecraft:stone_button", "left", [101]),
            ("minecraft:iron_ingot", "right", [104, 106, 108]),
            ("minecraft:redstone", "left", [107]),
        ],
        "bibliocraft:desk_bell",
        1,
    )
    # Slice 2: the redstone book is shapeless (`recipe/redstone_book.json`), so
    # its two ingredients sit in any two cells.
    check(
        "redstone book",
        [("minecraft:book", 1), ("minecraft:redstone_torch", 1)],
        [
            ("minecraft:book", "left", [100]),
            ("minecraft:redstone_torch", "left", [104]),
        ],
        "bibliocraft:redstone_book",
        1,
    )
    check(
        "wrong redstone book ingredients",
        [("minecraft:book", 2)],
        [("minecraft:book", "right", [100, 104])],
        None,
        0,
    )
    check(
        "wrong bookcase ingredients",
        [("minecraft:stick", 6), ("minecraft:oak_slab", 3)],
        [
            ("minecraft:stick", "right", BOOKCASE_PLANKS),
            ("minecraft:oak_slab", "right", BOOKCASE_SLABS),
        ],
        None,
        0,
    )

    if failures:
        for failure in failures:
            print("FAIL:", failure, file=sys.stderr)
        raise SystemExit(1)
    print(
        "PASS: the four shaped recipes and the redstone book's shapeless one craft, "
        "and the wrong-ingredient controls are empty"
    )


if __name__ == "__main__":
    main()
