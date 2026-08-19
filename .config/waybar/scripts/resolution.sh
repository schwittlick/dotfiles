#!/usr/bin/env bash
# Waybar resolution changer for Hyprland.
#   status  -> JSON for the waybar module
#   menu    -> rofi: pick an output, then pick one of its modes
set -euo pipefail

notify() { hyprctl notify -1 3000 "rgb(ffff00)" "$1" >/dev/null 2>&1 || true; }

# Applies a mode. Prefers the lua API, falls back to hyprlang keyword syntax.
apply() {
    local name=$1 mode=$2 pos=$3 scale=$4 out
    out=$(hyprctl eval "hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"$pos\", scale = $scale })" 2>&1) || true
    [[ $out == ok* ]] || out=$(hyprctl keyword monitor "$name,$mode,$pos,$scale" 2>&1) || true

    if [[ $out == ok* ]]; then
        notify "$name -> $mode"
    else
        notify "$name: $out"
    fi
}

status() {
    hyprctl monitors all -j | jq -c '
        (map(select(.disabled | not))) as $on
        | (($on | map(select(.focused)))[0] // $on[0]) as $f
        | {
            text: (if $f then "\($f.width)x\($f.height)" else "no output" end),
            tooltip: (
                map("\(.name)  " + (
                    if .disabled then "disabled"
                    else "\(.width)x\(.height)@\(.refreshRate | round)Hz  scale \(.scale)"
                    end))
                | join("\n")
            ),
            class: "resolution"
        }'
}

menu() {
    local mons output line mode pos scale
    mons=$(hyprctl monitors all -j)

    # Pick the output.
    output=$(jq -r '.[] | "\(.name)\t" + (
                 if .disabled then "disabled"
                 else "\(.width)x\(.height)@\(.refreshRate | round)Hz  scale \(.scale)"
                 end) + "  \(.description)"' <<<"$mons" |
        column -t -s $'\t' | rofi -dmenu -i -p "Output" | awk '{print $1}')
    [[ -n $output ]] || exit 0

    # Pick the mode, highest resolution first. "preferred" resets to the native mode.
    line=$(jq -r --arg o "$output" '
            .[] | select(.name == $o)
            | { w: .width, h: .height, r: (.refreshRate * 100 | round) } as $cur
            | [ .availableModes[]
                | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)Hz")
                | { s: "\(.w)x\(.h)@\(.r)Hz", w: (.w | tonumber), h: (.h | tonumber), r: (.r | tonumber) } ]
            | unique_by(.s)
            | sort_by(-.w, -.h, -.r)
            | ["preferred"] + map(.s + (
                  if .w == $cur.w and .h == $cur.h and (.r * 100 | round) == $cur.r
                  then "  (current)" else "" end))
            | .[]' <<<"$mons" |
        rofi -dmenu -i -p "$output mode" | awk '{print $1}')
    [[ -n $line ]] || exit 0
    mode=${line%Hz}

    # Keep the output where it is; a disabled output gets placed automatically.
    pos=$(jq -r --arg o "$output" '.[] | select(.name == $o) | if .disabled then "auto" else "\(.x)x\(.y)" end' <<<"$mons")
    scale=$(jq -r --arg o "$output" '.[] | select(.name == $o) | .scale' <<<"$mons")

    apply "$output" "$mode" "$pos" "$scale"
}

case "${1:-status}" in
    status) status ;;
    menu) menu ;;
    *)
        echo "usage: ${0##*/} [status|menu]" >&2
        exit 1
        ;;
esac
