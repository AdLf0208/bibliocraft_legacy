#!/usr/bin/env bash
# In-game check for the Bibliocraft Legacy slice 1 (four plain furniture
# blocks: oak bookcase, oak shelf, black oak seat, desk bell) — SDK package,
# mod API 0.2.
#
# NEEDS A LAUNCHER-BUILT GAME. The retired `.hnmod` was compiled into a game by
# the staging tools and its content was loaded with `--dev-mod content/`; the
# flat SDK package is built by the launcher instead:
#
#   horizon-launcher native-build ports/bibliocraft --instance <instance> --trust-native-code
#   GAME=<instance>/horizon-client tools/e2e.sh
#
# The package carries its own content (`assets/` + `data/` are inside
# `bibliocraft.hmod`), so there is no `--dev-mod` leg and no embedded-content leg
# any more. `CONTROL_GAME=` optionally names the same build WITHOUT the mod: the
# run then checks that every Bibliocraft id is unknown there, so the default
# leg's blocks and items cannot come from a vanilla world. Without it the
# control is skipped and `SELFTEST=1` stays the fail-capable proof.
#
# Default run (creative launch, then survival for drops/crafting; The End):
#   1. all 30 declared states bind: bookcase and shelf 8 each (facing x
#      waterlogged), seat 12 (axis x occupied x waterlogged), desk bell 2
#      (waterlogged);
#   2. each block item places, and the bookcase's four placements read back
#      the player-facing `facing` (south/north/east/west);
#   3. breaking each block in survival drops itself; a vanilla white glazed terracotta
#      (the template) drops itself and never a Bibliocraft item;
#   4. the four shaped recipes craft in a crafting table, and the stick
#      control leaves the result empty;
#   5. the block tags (`bibliocraft:bookcases`/`shelves`/`seats`,
#      `minecraft:mineable/axe`, `minecraft:mineable/pickaxe`) contain them;
#   6. every item is give-able, and the package's creative tab declares all five;
#   7. slice 2, the storage furniture:
#      a. the bookcase opens a 16-slot menu (`ctl screen` lists slots 300-315);
#      b. a plain book goes into slot 5 and answers no comparator, a redstone
#         book in slot 3 answers 3 through a comparator onto a wire, and the
#         same book moved to slot 1 answers 0 (the book's own scale);
#      c. the bookcase hands back a stone put into a slot, while the shelf
#         (4 slots) keeps it;
#      d. a hopper above fills the bookcase and a hopper below empties it into
#         a chest;
#      e. a broken bookcase spills its books as a container's do (the engine's
#         `Containers.dropContents`), drops itself, and the item placed again
#         is empty;
#   8. unknown ids are refused by give and setblock.
#
# COUNTERFACTUAL=1 repeats the vanilla-white-glazed-terracotta differential, proves
# the port's `waterlogged` state is not a vanilla state (setblock with
# `waterlogged=true` on white_glazed_terracotta fails), and runs the storage
# phase against a vanilla barrel instead of the bookcase: 27 slots, not 16, and
# the barrel takes the stone a bookcase refuses.
# SELFTEST=1 ends the default leg with an assertion that the vanilla control cell
# is a Bibliocraft block, which is impossible: it MUST fail (exit 1), proving the
# drop/differential assertions are not vacuous. It replaces the 0.1.0 NEGATIVE=1
# knob (the same false expectation, read from the world instead of a break reply).
#
# The 0.1.0 runs in ../_shared/evidence/bibliocraft/ (e2e*.log, 2026-11-05/06) are
# historical: they drive the retired `.hnmod` + `--dev-mod content/` path, which no
# longer exists in the SDK package.
set -Eeuo pipefail

CLONE=${CLONE:-/home/adlf/Desktop/all_the_mods_10_rust_rewrite}
PORT=$CLONE/ports/bibliocraft
# A launcher-built game carries the mod; the control client must come from a
# build of the same game version (the SDK pin's own ctl works, `CTL=` overrides).
PIN_BIN=$CLONE/ports/_shared/bin/horizon-1d63e0a5
CTL=${CTL:-$PIN_BIN/horizon-ctl}
GAME=${GAME:-}
CONTROL_GAME=${CONTROL_GAME:-}
RES=${RES:-${HORIZON_RES:-/home/adlf/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/bibliocraft-e2e.sock}
COUNTERFACTUAL=${COUNTERFACTUAL:-0}
SELFTEST=${SELFTEST:-0}
KEEP=${KEEP:-0}
EVIDENCE=$CLONE/ports/_shared/evidence/bibliocraft

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL (set CTL= to the launcher build's)" >&2; exit 1; }
[ -n "$GAME" ] || {
    echo "GAME is required: the SDK package is built into a game by the launcher," >&2
    echo "  horizon-launcher native-build ports/bibliocraft --instance <i> --trust-native-code" >&2
    exit 1
}
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/bibliocraft.hmod" ] || { echo "missing package: $PORT/bibliocraft.hmod" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/bibliocraft-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; ctl logs --lines 40 >&2 || true; exit 1; }
say() { echo "+ $*"; }
count_item() { ctl inventory | jq -r --arg i "$1" '.counts[$i] // 0'; }
block_state() { ctl block "$1" "$2" "$3" | jq -r '.block // "unknown"'; }
full_state() { ctl block "$1" "$2" "$3" | jq -r '.state // "unknown"'; }
prop() { echo "$1" | grep -o "$2=[a-z]*" | head -1 | cut -d= -f2 || true; }
assert_prop() {
    local state=$1 key=$2 want=$3 got
    got=$(prop "$state" "$key")
    [ "$got" = "$want" ] || fail "$state: $key is '$got', expected '$want'"
}
end() { ctl command "execute in minecraft:the_end run $1"; }
# The open menu's own container slots (300+), and the item in one of them.
container_slots() { ctl screen | jq '[.slots[] | select(.slot >= 300)] | length'; }
container_item() { ctl screen | jq -r --arg s "$1" '[.slots[] | select(.slot == ($s | tonumber))][0].item // ""'; }
# The first inventory slot (hotbar + main, below 100) holding `item`.
slot_with() { ctl screen | jq -r --arg i "$1" '[.slots[] | select(.item == $i and .slot < 100)][0].slot // ""'; }
# A redstone wire's strength (`power` in its block state).
wire_power() { ctl block "$1" "$2" "$3" | jq -r '.state // ""' | sed -n 's/.*power=\([0-9][0-9]*\).*/\1/p'; }

cleanup() {
    local status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    if [ "$KEEP" = 1 ]; then
        echo "kept scratch: $SCRATCH" >&2
    else
        rm -rf "$SCRATCH" 2>/dev/null || true
    fi
    echo "EXIT:$status"
}
trap cleanup EXIT

# ------------------------------------------------------- the control leg
# The same build WITHOUT this package: every Bibliocraft id must be unknown, so
# the default leg's blocks cannot be vanilla content under another name.
if [ -n "$CONTROL_GAME" ]; then
    say "control leg: the same build without the package knows no Bibliocraft id"
    [ -x "$CONTROL_GAME" ] || fail "missing CONTROL_GAME: $CONTROL_GAME"
    rm -f "$SOCK"
    "$CTL" --socket "$SOCK" launch \
        --game "$CONTROL_GAME" --world BibliocraftControl --seed 20261105 --creative \
        --offscreen --wait --game-dir "$SCRATCH/game" --resources "$RES" >/dev/null
    ctl wait-ready 180
    if ctl give bibliocraft:oak_bookcase 1 >/dev/null 2>&1; then
        fail "the unmodded game accepted bibliocraft:oak_bookcase"
    fi
    # A cell far above the control world's terrain, which is air there. (The
    # first version probed 40 80 20 and read a hillside, failing on the world
    # rather than on the package — y=200 is air in every Overworld.)
    [ "$(block_state 40 200 20)" = "minecraft:air" ] \
        || fail "the control cell 40 200 20 is not air before the probe"
    ctl setblock 40 200 20 bibliocraft:oak_bookcase >/dev/null 2>&1 || true
    [ "$(block_state 40 200 20)" = "minecraft:air" ] || fail "the unmodded game placed a Bibliocraft block"
    echo "control: give and setblock refuse every Bibliocraft id"
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -f "$SOCK"
fi

say "launch (offscreen renderer, creative, the launcher-built game carries the package)"
"$CTL" --socket "$SOCK" launch \
    --game "$GAME" --world BibliocraftE2E --seed 20261105 --creative --offscreen --wait \
    --game-dir "$SCRATCH/game" --resources "$RES"
ctl wait-ready 180

say "The End platform at y=79 and an empty box above it"
end "forceload add -2 -2 32 24"
ctl wait 20
end "tp @s 0.5 80 2.5"
ctl wait 40
end "fill -2 79 -2 32 79 24 minecraft:stone"
end "fill -2 80 -2 32 88 24 minecraft:air"
end "kill @e[type=minecraft:item]"
end "kill @e[type=minecraft:ender_dragon]"
end "kill @e[type=minecraft:end_crystal]"
end "difficulty peaceful"
end "tp @s 0.5 80 2.5"
ctl wait 10
ctl close >/dev/null 2>&1 || true
ctl wait 3

# ---------------------------------------------------------------- state bind
say "all 30 declared states bind"
state_case() { # x z block props
    ctl setblock "$1" 80 "$2" "$3[$4]" >/dev/null || fail "setblock $3[$4] failed"
}
idx=0
for facing in north east south west; do
    for wl in false true; do
        state_case 0 "$idx" bibliocraft:oak_bookcase "facing=$facing,waterlogged=$wl"
        state_case 1 "$idx" bibliocraft:oak_shelf "facing=$facing,waterlogged=$wl"
        idx=$((idx + 1))
    done
done
idx=0
for axis in x y z; do
    for occupied in false true; do
        for wl in false true; do
            state_case 2 "$idx" bibliocraft:black_oak_seat "axis=$axis,occupied=$occupied,waterlogged=$wl"
            idx=$((idx + 1))
        done
    done
done
state_case 3 0 bibliocraft:desk_bell "waterlogged=false"
state_case 3 1 bibliocraft:desk_bell "waterlogged=true"
ctl wait 5

idx=0
for facing in north east south west; do
    for wl in false true; do
        assert_prop "$(full_state 0 80 "$idx")" facing "$facing"
        assert_prop "$(full_state 0 80 "$idx")" waterlogged "$wl"
        assert_prop "$(full_state 1 80 "$idx")" facing "$facing"
        assert_prop "$(full_state 1 80 "$idx")" waterlogged "$wl"
        idx=$((idx + 1))
    done
done
idx=0
for axis in x y z; do
    for occupied in false true; do
        for wl in false true; do
            assert_prop "$(full_state 2 80 "$idx")" axis "$axis"
            assert_prop "$(full_state 2 80 "$idx")" occupied "$occupied"
            assert_prop "$(full_state 2 80 "$idx")" waterlogged "$wl"
            idx=$((idx + 1))
        done
    done
done
assert_prop "$(full_state 3 80 0)" waterlogged false
assert_prop "$(full_state 3 80 1)" waterlogged true
echo "30/30 states bound: 8 bookcase + 8 shelf + 12 seat + 2 desk bell"

# ---------------------------------------------------------------- placement
say "bookcase places facing the player from all four sides"
place_case() { # target_x target_z player_x player_z yaw expected_facing
    ctl command "tp @s $3 80 $4 $5 30" >/dev/null
    ctl wait 4
    ctl give bibliocraft:oak_bookcase 1 >/dev/null || fail "cannot give oak bookcase"
    ctl wait 2
    reply=$(ctl place "$1" 80 "$2" --item bibliocraft:oak_bookcase 2>&1) || { echo "place reply: $reply"; fail "cannot place bookcase at $1,80,$2"; }
    ctl wait 3
    [ "$(block_state "$1" 80 "$2")" = "bibliocraft:oak_bookcase" ] || fail "bookcase not at $1,80,$2"
    assert_prop "$(full_state "$1" 80 "$2")" facing "$6"
    echo "bookcase $1,80,$2 facing=$6"
}
place_case 10 10 10.5 12.5 180 south
place_case 13 10 13.5 7.5 0 north
place_case 16 10 18.5 10.5 90 east
place_case 19 10 16.5 10.5 270 west

say "shelf, seat and desk bell place"
ctl command "tp @s 22.5 80 12.5 180 30" >/dev/null
ctl wait 3
ctl give bibliocraft:oak_shelf 1 >/dev/null || fail "cannot give oak shelf"
ctl wait 2
reply=$(ctl place 22 80 10 --item bibliocraft:oak_shelf 2>&1) || { echo "place reply: $reply"; fail "cannot place shelf"; }
ctl wait 3
[ "$(block_state 22 80 10)" = "bibliocraft:oak_shelf" ] || fail "shelf not placed"
assert_prop "$(full_state 22 80 10)" facing south

ctl command "tp @s 24.5 80 12.5 180 30" >/dev/null
ctl wait 3
ctl give bibliocraft:black_oak_seat 1 >/dev/null || fail "cannot give seat"
ctl wait 2
reply=$(ctl place 24 80 10 --item bibliocraft:black_oak_seat 2>&1) || { echo "place reply: $reply"; fail "cannot place seat"; }
ctl wait 3
[ "$(block_state 24 80 10)" = "bibliocraft:black_oak_seat" ] || fail "seat not placed"

ctl command "tp @s 25.5 80 12.5 180 30" >/dev/null
ctl wait 3
ctl give bibliocraft:desk_bell 1 >/dev/null || fail "cannot give desk bell"
ctl wait 2
reply=$(ctl place 25 80 10 --item bibliocraft:desk_bell 2>&1) || { echo "place reply: $reply"; fail "cannot place desk bell"; }
ctl wait 3
[ "$(block_state 25 80 10)" = "bibliocraft:desk_bell" ] || fail "desk bell not placed"
echo "shelf/seat/desk bell placed"

# ------------------------------------------------------------------- drops
say "survival drops: each block drops itself"
ctl command "gamemode survival @s" >/dev/null
ctl wait 20
[ "$(ctl state | jq -r '.gamemode')" = "survival" ] || fail "the client is not in survival"
ctl command "clear @s" >/dev/null
ctl give minecraft:iron_axe 1 >/dev/null
ctl give minecraft:diamond_pickaxe 1 >/dev/null
ctl wait 3
drop_case() { # x z item tool
    ctl command "tp @s $1.5 80 12.5" >/dev/null
    ctl wait 3
    ctl select "$4" >/dev/null || fail "cannot select $4"
    ctl wait 2
    ctl look-at-block "$1" 80 "$2" >/dev/null || true
    broken=$(ctl break "$1" 80 "$2") || { echo "break reply: $broken"; fail "cannot break $3"; }
    echo "$broken" | jq -c '{block,block_before,drops}'
    [ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "$3 did not break"
    got=$(echo "$broken" | jq -r --arg i "bibliocraft:$3" '.drops[$i] // 0')
    [ "$got" -ge 1 ] || fail "$3 dropped $got of itself"
}
drop_case 10 10 oak_bookcase minecraft:iron_axe
drop_case 22 10 oak_shelf minecraft:iron_axe
drop_case 24 10 black_oak_seat minecraft:iron_axe
drop_case 25 10 desk_bell minecraft:diamond_pickaxe

say "vanilla white glazed terracotta control drops itself and no Bibliocraft item"
ctl command "tp @s 28.5 80 12.5" >/dev/null
ctl wait 3
ctl select minecraft:diamond_pickaxe >/dev/null
ctl wait 2
ctl command "setblock 28 80 10 minecraft:white_glazed_terracotta" >/dev/null || fail "cannot set the vanilla control"
ctl wait 3
ctl look-at-block 28 80 10 >/dev/null || true
broken=$(ctl break 28 80 10) || { echo "break reply: $broken"; fail "cannot break the vanilla control"; }
echo "$broken" | jq -c '{block,block_before,drops}'
[ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "vanilla white glazed terracotta did not break"
vanilla=$(echo "$broken" | jq -r '.drops["minecraft:white_glazed_terracotta"] // 0')
[ "$vanilla" -ge 1 ] || fail "vanilla white glazed terracotta dropped $vanilla of itself"
for item in oak_bookcase oak_shelf black_oak_seat desk_bell; do
    got=$(echo "$broken" | jq -r --arg i "bibliocraft:$item" '.drops[$i] // 0')
    [ "$got" -eq 0 ] || fail "vanilla white glazed terracotta dropped $got bibliocraft:$item"
done
echo "vanilla white glazed terracotta: self only, no Bibliocraft item"

# ----------------------------------------------------------------- recipes
say "the four shaped recipes craft in a crafting table"
ctl command "gamemode creative @s" >/dev/null
ctl wait 10
ctl command "clear @s" >/dev/null
end "setblock 30 80 10 minecraft:crafting_table"
ctl command "tp @s 30.5 80 11.5" >/dev/null
ctl wait 5
python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 30 80 10 || fail "the recipe check failed"
ctl close >/dev/null 2>&1 || true
ctl wait 3

# -------------------------------------------------------------------- tags
say "the blocks carry their 26.3 tags"
ctl setblock 0 80 20 bibliocraft:oak_bookcase >/dev/null
ctl setblock 1 80 20 bibliocraft:oak_shelf >/dev/null
ctl setblock 2 80 20 bibliocraft:black_oak_seat >/dev/null
ctl setblock 3 80 20 bibliocraft:desk_bell >/dev/null
ctl wait 3
ctl command "execute in minecraft:the_end if block 0 80 20 #bibliocraft:bookcases run say TAG_BOOKCASE" >/dev/null
ctl command "execute in minecraft:the_end if block 1 80 20 #bibliocraft:shelves run say TAG_SHELF" >/dev/null
ctl command "execute in minecraft:the_end if block 2 80 20 #bibliocraft:seats run say TAG_SEAT" >/dev/null
ctl command "execute in minecraft:the_end if block 0 80 20 #minecraft:mineable/axe run say TAG_BOOKCASE_AXE" >/dev/null
ctl command "execute in minecraft:the_end if block 1 80 20 #minecraft:mineable/axe run say TAG_SHELF_AXE" >/dev/null
ctl command "execute in minecraft:the_end if block 2 80 20 #minecraft:mineable/axe run say TAG_SEAT_AXE" >/dev/null
ctl command "execute in minecraft:the_end if block 3 80 20 #minecraft:mineable/pickaxe run say TAG_BELL_PICKAXE" >/dev/null
ctl wait 3
messages=$(ctl messages 60 | jq -r '.chat[]')
for tag in TAG_BOOKCASE TAG_SHELF TAG_SEAT TAG_BOOKCASE_AXE TAG_SHELF_AXE TAG_SEAT_AXE TAG_BELL_PICKAXE; do
    echo "$messages" | grep -q "$tag" || fail "missing tag message $tag"
done
echo "tags: bookcases/shelves/seats + mineable/axe + mineable/pickaxe"

# ---------------------------------------------------------------- item side
say "all five items are give-able and the creative tab lists them"
ctl command "clear @s" >/dev/null
for item in oak_bookcase oak_shelf black_oak_seat desk_bell redstone_book; do
    ctl give "bibliocraft:$item" 1 >/dev/null || fail "give bibliocraft:$item failed"
done
ctl wait 5
for item in oak_bookcase oak_shelf black_oak_seat desk_bell redstone_book; do
    [ "$(count_item "bibliocraft:$item")" -ge 1 ] || fail "bibliocraft:$item is missing"
done
# The creative tab is a content declaration inside the delivered package: a
# native package's merged content is baked into the package at build time, so
# there is no `--dev-mod` cache for it (the 0.1.0 assertion read one). The tab
# is checked where it is declared, and the items themselves are given above in
# the running game.
TAB=$(unzip -p "$PORT/bibliocraft.hmod" data/bibliocraft/horizon/creative_tab/bibliocraft.json) \
    || fail "the delivered package has no creative_tab declaration"
echo "creative tab (package data): $(echo "$TAB" | jq -c .)"
for item in oak_bookcase oak_shelf black_oak_seat desk_bell redstone_book; do
    echo "$TAB" | grep -q "\"bibliocraft:$item\"" || fail "creative tab misses bibliocraft:$item"
done
echo "5/5 items give-able in game; the package's creative tab declares 5"


# ------------------------------------------------- storage (slice 2)
# The bookcase is a 16-slot, book-only block entity with a content menu, a
# comparator answer and contents that survive a break; the shelf is a plain
# 4-slot one. Everything below is read back through the game (the menu, the
# comparator's wire, the hopper's chest), never through the port's own code.
open_menu() { # x y z face
    ctl close >/dev/null 2>&1 || true
    ctl wait 3
    ctl interact "$1" "$2" "$3" "$4" >/dev/null || fail "the click on $1,$2,$3 failed"
    ctl wait-for screen container --timeout 10 >/dev/null 2>&1 \
        || fail "no container menu opened at $1,$2,$3 (screen=$(ctl state | jq -r '.screen // ""'))"
    ctl wait 3
}
# Put `item` into container slot `to`: pick the stack up from the inventory,
# right-click one into the slot, put the rest back where it came from.
put_one() { # item to
    local from
    from=$(slot_with "$1")
    [ -n "$from" ] || fail "no $1 in the inventory to put in slot $2"
    ctl click-slot "$from" >/dev/null || fail "cannot pick up $1"
    ctl wait 2
    ctl click-slot "$2" right >/dev/null || fail "cannot put $1 in slot $2"
    ctl wait 2
    ctl click-slot "$from" >/dev/null || fail "cannot put the rest of $1 back"
    ctl wait 3
}
# Take container slot `from` and put it in the first free inventory slot.
take_one() { # from
    local free
    free=$(ctl screen | jq -r '[.slots[] | select(.slot >= 9 and .slot < 36) | select(.item == null)][0].slot // ""')
    [ -n "$free" ] || fail "no free inventory slot to put the taken stack in"
    ctl click-slot "$1" >/dev/null || fail "cannot take from slot $1"
    ctl wait 2
    ctl click-slot "$free" >/dev/null || fail "cannot put the taken stack in $free"
    ctl wait 3
}

AX=8
AZ=16
ctl setblock $AX 80 $AZ bibliocraft:oak_bookcase >/dev/null || fail "cannot set the bookcase"
ctl wait 5
ctl command "tp @s $AX.5 80 $((AZ + 2)).5 180 20" >/dev/null
ctl wait 6

if [ "$COUNTERFACTUAL" = 1 ]; then
    say "counterfactual: a vanilla barrel opens a 27-slot menu and takes the stone a bookcase refuses"
    ctl setblock $AX 80 $AZ minecraft:barrel >/dev/null || fail "cannot set the barrel"
    ctl wait 5
    open_menu $AX 80 $AZ south
    slots=$(container_slots)
    echo "vanilla barrel menu slots: $slots"
    [ "$slots" = 27 ] || fail "the vanilla barrel menu shows $slots slots, expected 27"
    ctl command "clear @s" >/dev/null
    ctl give minecraft:stone 1 >/dev/null
    ctl wait 4
    put_one minecraft:stone 300
    [ "$(container_item 300)" = "minecraft:stone" ] \
        || fail "the vanilla barrel did not keep the stone the bookcase refuses"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3
    echo "COUNTERFACTUAL PASS: a barrel is a 27-slot chest that takes stone; the bookcase's 16 slots and its book filter are its own code"
else
    say "the bookcase opens a 16-slot menu"
    open_menu $AX 80 $AZ south
    slots=$(container_slots)
    echo "bookcase menu slots: $slots"
    [ "$slots" = 16 ] || fail "the bookcase menu shows $slots slots, expected 16 (upstream BookcaseBlockEntity: SLOTS = 16)"

    say "a book goes into the bookcase through its menu"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3
    ctl command "clear @s" >/dev/null
    ctl give minecraft:book 3 >/dev/null || fail "cannot give books"
    ctl give bibliocraft:redstone_book 1 >/dev/null || fail "cannot give a redstone book"
    ctl wait 4
    open_menu $AX 80 $AZ south
    put_one minecraft:book 305
    [ "$(container_item 305)" = "minecraft:book" ] || fail "slot 305 holds '$(container_item 305)', expected a book"
    echo "slot 5 (300+5) holds a plain book"

    # ------------------------------------------------------------ comparator
    say "a plain book answers no comparator; a redstone book answers its slot index"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3
    # The comparator at X+1 faces west, so it reads the bookcase at X and drives
    # the wire at X+2 (`diode_input_signal` reads `pos + facing`).
    ctl setblock $((AX + 1)) 80 $AZ "minecraft:comparator[facing=west]" >/dev/null \
        || fail "cannot place the comparator"
    ctl setblock $((AX + 2)) 80 $AZ minecraft:redstone_wire >/dev/null || fail "cannot place the wire"
    ctl wait 20
    power=$(wire_power $((AX + 2)) 80 $AZ)
    echo "wire power with a plain book in slot 5: ${power:-none}"
    [ "$power" = 0 ] || fail "a plain book answered ${power}, expected 0 (only a redstone book does)"

    open_menu $AX 80 $AZ south
    put_one bibliocraft:redstone_book 303
    [ "$(container_item 303)" = "bibliocraft:redstone_book" ] \
        || fail "slot 303 holds '$(container_item 303)', expected the redstone book"
    ctl close >/dev/null 2>&1 || true
    ctl wait 20
    power=$(wire_power $((AX + 2)) 80 $AZ)
    echo "wire power with a redstone book in slot 3: ${power:-none}"
    [ "$power" = 3 ] || fail "a redstone book in slot 4 (index 3) answered ${power}, expected 3"

    # The book's own text: slot 1 (index 0) yields no signal.
    open_menu $AX 80 $AZ south
    take_one 303
    put_one bibliocraft:redstone_book 300
    [ "$(container_item 300)" = "bibliocraft:redstone_book" ] \
        || fail "slot 300 holds '$(container_item 300)', expected the redstone book"
    ctl close >/dev/null 2>&1 || true
    ctl wait 20
    power=$(wire_power $((AX + 2)) 80 $AZ)
    echo "wire power with the redstone book in slot 1: ${power:-none}"
    [ "$power" = 0 ] || fail "the redstone book in slot 1 answered ${power}, expected 0 (the book's own scale)"

    say "a stone put into a bookcase slot is handed back (books only)"
    ctl command "clear @s" >/dev/null
    ctl give minecraft:stone 1 >/dev/null
    ctl wait 4
    open_menu $AX 80 $AZ south
    put_one minecraft:stone 309
    ctl wait 10
    [ "$(container_item 309)" = "" ] || fail "the bookcase kept the stone in slot 309 ('$(container_item 309)')"
    echo "slot 309 is empty again: the bookcase refused the stone"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3

    # ---------------------------------------------------------------- hoppers
    say "a hopper above fills the bookcase and a hopper below empties it into a chest"
    BX=12
    BZ=16
    ctl setblock $BX 80 $BZ bibliocraft:oak_bookcase >/dev/null || fail "cannot set the second bookcase"
    ctl setblock $BX 81 $BZ "minecraft:hopper[facing=down]" >/dev/null || fail "cannot set the upper hopper"
    ctl wait 5
    ctl command "item replace block $BX 81 $BZ container.0 with minecraft:book 3" >/dev/null \
        || fail "cannot fill the hopper"
    ctl wait 80
    ctl command "tp @s $BX.5 80 $((BZ + 2)).5 180 20" >/dev/null
    ctl wait 4
    open_menu $BX 80 $BZ south
    stored=$(ctl screen | jq '[.slots[] | select(.slot >= 300 and .slot <= 315 and .item == "minecraft:book") | .count] | add // 0')
    echo "books in the bookcase after the hopper: $stored"
    [ "$stored" = 3 ] || fail "the hopper pushed $stored books, expected 3"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3
    ctl setblock $BX 79 $BZ "minecraft:hopper[facing=west]" >/dev/null || fail "cannot set the lower hopper"
    ctl setblock $((BX - 1)) 79 $BZ minecraft:chest >/dev/null || fail "cannot set the chest"
    ctl wait 80
    # The chest sits in the floor, so the face a player reaches is its top one.
    ctl command "tp @s $((BX - 1)).5 80 $((BZ + 2)).5 180 40" >/dev/null
    ctl wait 4
    open_menu $((BX - 1)) 79 $BZ up
    in_chest=$(ctl screen | jq '[.slots[] | select(.item == "minecraft:book") | .count] | add // 0')
    echo "books in the chest: $in_chest"
    [ "$in_chest" -ge 1 ] || fail "the lower hopper moved no book into the chest"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3

    # ------------------------------------------------------- the shelf keeps anything
    say "the shelf opens a 4-slot menu and keeps a stone"
    SX=10
    SZ=20
    ctl setblock $SX 80 $SZ bibliocraft:oak_shelf >/dev/null || fail "cannot set the shelf"
    ctl wait 5
    ctl command "tp @s $SX.5 80 $((SZ + 2)).5 180 20" >/dev/null
    ctl wait 4
    open_menu $SX 80 $SZ south
    slots=$(container_slots)
    echo "shelf menu slots: $slots"
    [ "$slots" = 4 ] || fail "the shelf menu shows $slots slots, expected 4 (upstream ShelfBlockEntity: 4)"
    ctl command "clear @s" >/dev/null
    ctl give minecraft:stone 1 >/dev/null
    ctl wait 4
    put_one minecraft:stone 302
    [ "$(container_item 302)" = "minecraft:stone" ] || fail "the shelf refused the stone (slot 302: '$(container_item 302)')"
    echo "the shelf kept the stone the bookcase refuses"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3

    # --------------------------------------- a broken bookcase spills its books
    # A mod container is a container: the engine runs `Containers.dropContents` for it
    # when the block goes (`spill.rs:485`, `preRemoveSideEffects`), so a broken bookcase
    # spills its books exactly as a broken chest would, and its own item drops beside
    # them. The port writes no `minecraft:block_entity_data` payload: the contents are
    # already on the ground, and carrying them twice is not upstream's behaviour either.
    say "a broken bookcase spills its books and drops itself"
    CX=14
    CZ=16
    ctl setblock $CX 80 $CZ bibliocraft:oak_bookcase >/dev/null || fail "cannot set the third bookcase"
    ctl wait 5
    ctl command "tp @s $CX.5 80 $((CZ + 2)).5 180 20" >/dev/null
    ctl wait 4
    ctl command "clear @s" >/dev/null
    ctl give minecraft:book 2 >/dev/null || fail "cannot give the books"
    ctl wait 4
    open_menu $CX 80 $CZ south
    put_one minecraft:book 301
    put_one minecraft:book 302
    kept=$(ctl screen | jq '[.slots[] | select(.slot >= 300 and .slot <= 315 and .item == "minecraft:book") | .count] | add // 0')
    echo "books before the break: $kept"
    [ "$kept" = 2 ] || fail "the bookcase holds $kept books before the break, expected 2"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3

    ctl command "gamemode survival @s" >/dev/null
    ctl wait 20
    ctl command "clear @s" >/dev/null
    ctl command "kill @e[type=minecraft:item]" >/dev/null
    ctl give minecraft:iron_axe 1 >/dev/null
    ctl wait 4
    ctl select minecraft:iron_axe >/dev/null || fail "cannot select the axe"
    ctl wait 4
    ctl look-at-block $CX 80 $CZ >/dev/null || true
    broken=$(ctl break $CX 80 $CZ) || { echo "break reply: $broken"; fail "cannot break the bookcase"; }
    echo "$broken" | jq -c '{block,drops}'
    [ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "the bookcase did not break"
    [ "$(echo "$broken" | jq -r '.drops["bibliocraft:oak_bookcase"] // 0')" -ge 1 ] \
        || fail "the broken bookcase did not drop itself"
    # The break reply is the engine's own report of what the block dropped: the
    # container's two books ride it beside the block item (`Containers.dropContents`).
    spilled=$(echo "$broken" | jq -r '.drops["minecraft:book"] // 0')
    echo "books in the break reply: $spilled"
    [ "$spilled" -ge 2 ] || fail "the broken bookcase spilled $spilled books, expected the 2 it held"
    ctl wait 10
    # And they are real items in the world or in the breaker's inventory (a drop
    # that lands at the player's feet is picked up on the next tick).
    ground=$(ctl entities 16 item | jq '[.entities[]? | select(.kind == "item" and .item.item == "minecraft:book") | .item.count] | add // 0')
    carried=$(count_item minecraft:book)
    echo "books after the break: on the ground $ground, carried $carried"
    [ $((ground + carried)) -ge 2 ] || fail "the 2 spilled books are nowhere: ground $ground, carried $carried"

    # And the block item is a plain bookcase again: placing it gives an empty one.
    ctl command "tp @s $CX.5 80 $CZ.5" >/dev/null
    ctl wait 30
    held=$(count_item bibliocraft:oak_bookcase)
    echo "bookcase items in the inventory: $held"
    [ "$held" -ge 1 ] || fail "the dropped bookcase was not picked up"
    ctl command "tp @s $CX.5 80 $((CZ + 3)).5" >/dev/null
    ctl wait 6
    ctl command "gamemode creative @s" >/dev/null
    ctl wait 10
    ctl select bibliocraft:oak_bookcase >/dev/null 2>&1 || true
    ctl wait 4
    reply=$(ctl place $CX 80 $CZ --item bibliocraft:oak_bookcase 2>&1) \
        || { echo "place reply: $reply"; fail "cannot place the bookcase again"; }
    ctl wait 8
    [ "$(block_state $CX 80 $CZ)" = "bibliocraft:oak_bookcase" ] || fail "the bookcase was not placed again"
    open_menu $CX 80 $CZ south
    restored=$(ctl screen | jq '[.slots[] | select(.slot >= 300 and .slot <= 315 and .item == "minecraft:book") | .count] | add // 0')
    echo "books in the replaced bookcase: $restored"
    [ "$restored" = 0 ] || fail "the replaced bookcase kept $restored books (the block item carries no contents)"
    ctl close >/dev/null 2>&1 || true
    ctl wait 3

fi

# ------------------------------------------------------------- unknown ids
say "unknown ids are refused"
if ctl give bibliocraft:not_a_block 1 >/dev/null 2>&1; then
    fail "give bibliocraft:not_a_block succeeded"
fi
for id in bogus_bookcase bogus_shelf bogus_seat bogus_desk_bell; do
    ctl setblock 40 80 20 "bibliocraft:$id" >/dev/null 2>&1 || true
    [ "$(block_state 40 80 20)" = "minecraft:air" ] || fail "bibliocraft:$id became a block"
done
echo "unknown block/item ids are refused"

if [ "$COUNTERFACTUAL" = 1 ]; then
    say "counterfactual: the vanilla template has no waterlogged state"
    if ctl setblock 29 80 20 "minecraft:white_glazed_terracotta[waterlogged=true]" >/dev/null 2>&1; then
        fail "minecraft:white_glazed_terracotta accepted waterlogged=true"
    fi
    [ "$(block_state 29 80 20)" = "minecraft:air" ] || fail "the refused vanilla state left a block"
    echo "vanilla white_glazed_terracotta refuses waterlogged=true"

    say "counterfactual: break the vanilla template and assert no Bibliocraft drop"
    ctl command "setblock 28 80 20 minecraft:white_glazed_terracotta" >/dev/null || fail "cannot set the counterfactual white glazed terracotta"
    ctl command "tp @s 28.5 80 22.5" >/dev/null
    ctl wait 3
    ctl command "gamemode survival @s" >/dev/null
    ctl command "clear @s" >/dev/null
    ctl give minecraft:diamond_pickaxe 1 >/dev/null
    ctl select minecraft:diamond_pickaxe >/dev/null 2>&1 || ctl select 1 >/dev/null
    ctl wait 3
    ctl look-at-block 28 80 20 >/dev/null || true
    broken=$(ctl break 28 80 20) || { echo "break reply: $broken"; fail "cannot break the counterfactual white glazed terracotta"; }
    echo "$broken" | jq -c '{block,block_before,drops}'
    [ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "counterfactual white glazed terracotta did not break"
    vanilla=$(echo "$broken" | jq -r '.drops["minecraft:white_glazed_terracotta"] // 0')
    [ "$vanilla" -ge 1 ] || fail "counterfactual white glazed terracotta dropped $vanilla of itself"
    for item in oak_bookcase oak_shelf black_oak_seat desk_bell; do
        got=$(echo "$broken" | jq -r --arg i "bibliocraft:$item" '.drops[$i] // 0')
        [ "$got" -eq 0 ] || fail "counterfactual white glazed terracotta dropped $got bibliocraft:$item"
    done
    echo "COUNTERFACTUAL PASS: the vanilla template has no waterlogged state and drops no Bibliocraft item"
fi

if [ "$SELFTEST" = 1 ]; then
    # Slice 2's own fail-capable assertion first: the bookcase's menu is 16 slots,
    # never a vanilla barrel's 27, so this must fail on the real package.
    ctl command "tp @s 8.5 80 18.5 180 20" >/dev/null
    ctl wait 6
    open_menu 8 80 16 south
    got=$(container_slots)
    [ "$got" = 27 ] \
        || fail "SELFTEST: expected the bookcase menu to show 27 slots, found '$got' — the 16-slot assertion can fail (this exit 1 is the proof)"
    # And slice 1's, a real assertion on a real read, deliberately false: the
    # vanilla control cell holds plain air after its break, never a Bibliocraft block.
    got=$(block_state 28 80 20)
    [ "$got" = "bibliocraft:oak_bookcase" ] \
        || fail "SELFTEST: expected the vanilla control cell to be bibliocraft:oak_bookcase, found '$got' — the differential assertion can fail (this exit 1 is the proof)"
fi

if [ "$COUNTERFACTUAL" = 1 ]; then
    echo "PASS (counterfactual): the slice-1 differentials hold and the storage phase ran against a vanilla barrel (27 slots, takes stone)"
else
    echo "PASS: 30 states bind, the bookcase faces the player from all four sides, all four blocks place and drop themselves, the vanilla white glazed terracotta control drops only itself, the five recipes craft while the wrong-ingredient controls are empty, the tags contain the blocks, the tab lists five and every item gives, the bookcase opens a 16-slot books-only menu whose redstone book answers its slot index on a comparator wire (and a plain book answers 0), a hopper fills it and another empties it into a chest, the shelf opens 4 slots and keeps a stone, a broken bookcase spills its books and drops itself (a plain item placed again is empty), and unknown ids are refused"
fi
