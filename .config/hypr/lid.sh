#!/usr/bin/env bash
# Conditional lid handling for Hyprland

# Applies a monitor rule. Prefers the lua API, falls back to hyprlang keyword syntax.
monitor_rule() {
  local lua=$1 keyword=$2
  [[ $(hyprctl eval "hl.monitor({ $lua })" 2>&1) == ok* ]] || hyprctl keyword monitor "$keyword"
}

case "$1" in
  close)
    # Disable internal panel ONLY if an external monitor is present (clamshell).
    # With no external, do nothing — let systemd-logind suspend the machine.
    if hyprctl monitors | grep '^Monitor' | grep -qv 'Monitor eDP-1'; then
      monitor_rule 'output = "eDP-1", disabled = true' "eDP-1, disable"
    fi
    ;;
  open)
    # Re-enable eDP-1 only if it was actually disabled (i.e. clamshell wake).
    if ! hyprctl monitors | grep -q 'Monitor eDP-1'; then
      monitor_rule 'output = "eDP-1", mode = "preferred", position = "auto", scale = 2' "eDP-1, preferred, auto, 2"
    fi
    ;;
esac
