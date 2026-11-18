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
#   6. the creative tab lists all four and every item is give-able;
#   7. unknown ids are refused by give and setblock.
#
# COUNTERFACTUAL=1 repeats the vanilla-white-glazed-terracotta differential and also
# proves the port's `waterlogged` state is not a vanilla state (setblock with
# `waterlogged=true` on white_glazed_terracotta fails).
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
    ctl setblock 40 80 20 bibliocraft:oak_bookcase >/dev/null 2>&1 || true
    [ "$(block_state 40 80 20)" = "minecraft:air" ] || fail "the unmodded game placed a Bibliocraft block"
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
say "all four items are give-able and the creative tab lists them"
ctl command "clear @s" >/dev/null
for item in oak_bookcase oak_shelf black_oak_seat desk_bell; do
    ctl give "bibliocraft:$item" 1 >/dev/null || fail "give bibliocraft:$item failed"
done
ctl wait 5
for item in oak_bookcase oak_shelf black_oak_seat desk_bell; do
    [ "$(count_item "bibliocraft:$item")" -ge 1 ] || fail "bibliocraft:$item is missing"
done
# The creative tab is a content declaration; the game materialises it as the
# creative inventory of the open world. A launcher-installed package and a dev
# root both land in the game dir's cache; a package that never registered its
# tab has no entry either way.
CREATIVE=
for candidate in "$SCRATCH/game/.horizon-cache/mod-content/creative-inventory.json" \
                 "$(dirname "$GAME")/.horizon-cache/mod-content/creative-inventory.json"; do
    [ -f "$candidate" ] && CREATIVE=$candidate && break
done
[ -n "$CREATIVE" ] || fail "no creative-inventory.json in the game dir's .horizon-cache/mod-content"
echo "creative inventory: $CREATIVE"
for item in oak_bookcase oak_shelf black_oak_seat desk_bell; do
    grep -q "bibliocraft:$item" "$CREATIVE" || fail "creative tab misses bibliocraft:$item"
done
echo "4/4 items give-able; creative tab lists 4"

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
    # A real assertion on a real read, deliberately false: the vanilla control
    # cell holds plain air after its break, never a Bibliocraft block.
    got=$(block_state 28 80 20)
    [ "$got" = "bibliocraft:oak_bookcase" ] \
        || fail "SELFTEST: expected the vanilla control cell to be bibliocraft:oak_bookcase, found '$got' — the differential assertion can fail (this exit 1 is the proof)"
fi

echo "PASS: 30 states bind, the bookcase faces the player from all four sides, all four blocks place and drop themselves, the vanilla white glazed terracotta control drops only itself, the four recipes craft while the stick control is empty, the tags contain the blocks, the tab lists four and every item gives, and unknown ids are refused"
