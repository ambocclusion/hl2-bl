#!/usr/bin/env bash
# Install HL2: Borderlands into your Garry's Mod directory (copies files, so it
# works even if this repo is moved or deleted). Auto-detects GMod across all
# Steam library folders. For live development use scripts/deploy.sh (symlinks).
#
# Override detection with:  GMOD_DIR=/path/to/.../garrysmod scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_NAME="hl2bl"

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
die()  { red "ERROR: $*"; exit 1; }

# --- locate the GarrysMod/garrysmod directory ------------------------------
find_gmod() {
	if [ -n "${GMOD_DIR:-}" ]; then
		[ -d "$GMOD_DIR" ] && { echo "$GMOD_DIR"; return 0; }
		die "GMOD_DIR set but not a directory: $GMOD_DIR"
	fi

	local roots=( "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/root" )
	local libs=()

	# Steam roots themselves are also library folders.
	for r in "${roots[@]}"; do
		[ -d "$r" ] && libs+=( "$r" )
		# Extra library folders listed in libraryfolders.vdf.
		local vdf="$r/steamapps/libraryfolders.vdf"
		if [ -f "$vdf" ]; then
			while IFS= read -r p; do libs+=( "$p" ); done < <(
				grep -oE '"path"[[:space:]]*"[^"]+"' "$vdf" \
					| sed -E 's/.*"path"[[:space:]]*"([^"]+)".*/\1/'
			)
		fi
	done

	for base in "${libs[@]}"; do
		local cand="$base/steamapps/common/GarrysMod/garrysmod"
		[ -d "$cand" ] && { echo "$cand"; return 0; }
	done
	return 1
}

GMOD="$(find_gmod || true)"
[ -n "$GMOD" ] || die "Garry's Mod not found. Install it via Steam, or set GMOD_DIR=/path/.../garrysmod"

grn "Found Garry's Mod: $GMOD"

# --- copy helper (rsync if available, else cp) -----------------------------
copy_into() {
	local src="$1" dest="$2"
	[ -d "$src" ] || die "Missing source: $src"
	rm -rf "$dest"
	mkdir -p "$(dirname "$dest")"
	if command -v rsync >/dev/null 2>&1; then
		rsync -a --exclude '.git' "$src/" "$dest/"
	else
		cp -r "$src" "$dest"
	fi
}

# --- install addon + gamemode ----------------------------------------------
copy_into "$ROOT/addon"          "$GMOD/addons/$ADDON_NAME"
grn "Installed addon    -> $GMOD/addons/$ADDON_NAME"

copy_into "$ROOT/gamemodes/$ADDON_NAME" "$GMOD/gamemodes/$ADDON_NAME"
grn "Installed gamemode -> $GMOD/gamemodes/$ADDON_NAME"

echo
grn "HL2: Borderlands installed."
ylw "Launch GMod -> New Game -> Gamemode: \"HL2: Borderlands\" -> pick a map."
ylw "To uninstall: rm -rf \"$GMOD/addons/$ADDON_NAME\" \"$GMOD/gamemodes/$ADDON_NAME\""
