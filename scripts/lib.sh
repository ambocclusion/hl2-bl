#!/usr/bin/env bash
# Shared paths and helpers for hl2bl (Garry's Mod addon) automation scripts.
# Source this from other scripts:  . "$(dirname "$0")/lib.sh"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The GMod addon source (mounted into GarrysMod/garrysmod/addons).
ADDON_SRC="$PROJECT_ROOT/addon"
ADDON_NAME="${ADDON_NAME:-hl2bl}"
# Gamemode (shipped at repo top level; symlinked into garrysmod/gamemodes).
GAMEMODE_SRC="$PROJECT_ROOT/gamemodes/hl2bl"
GAMEMODE_NAME="${GAMEMODE_NAME:-hl2bl}"

# Steam / GMod. Override STEAM_ROOT if Steam lives elsewhere.
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
STEAM_APPS="$STEAM_ROOT/steamapps"
GMOD_DIR="$STEAM_APPS/common/GarrysMod/garrysmod"
GMOD_ADDONS="$GMOD_DIR/addons"
GMOD_GAMEMODES="$GMOD_DIR/gamemodes"
GMOD_APPID=4000

c_red()   { printf '\033[31m%s\033[0m\n' "$*"; }
c_grn()   { printf '\033[32m%s\033[0m\n' "$*"; }
c_ylw()   { printf '\033[33m%s\033[0m\n' "$*"; }
info()    { c_grn  "==> $*"; }
warn()    { c_ylw  "!!! $*"; }
die()     { c_red  "ERROR: $*"; exit 1; }
