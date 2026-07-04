#!/usr/bin/env bash
# Conditional lid handling for Hyprland

case "$1" in
  close)
    # Disable internal panel ONLY if an external monitor is present (clamshell).
    # With no external, do nothing — let systemd-logind suspend the machine.
    if hyprctl monitors | grep '^Monitor' | grep -qv 'Monitor eDP-1'; then
      hyprctl keyword monitor "eDP-1, disable"
    fi
    ;;
  open)
    # Re-enable eDP-1 only if it was actually disabled (i.e. clamshell wake).
    if ! hyprctl monitors | grep -q 'Monitor eDP-1'; then
      hyprctl keyword monitor "eDP-1, preferred, auto, 2"
    fi
    ;;
esac
