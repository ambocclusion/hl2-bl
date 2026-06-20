#!/usr/bin/env bash
# Auto-update HL2: Borderlands from git, then reinstall into Garry's Mod.
# Works either from a clone of the repo or standalone (it keeps a cache clone).
#   scripts/update.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_HTTPS="https://github.com/ambocclusion/hl2-bl.git"
BRANCH="${HL2BL_BRANCH:-main}"

grn() { printf '\033[32m%s\033[0m\n' "$*"; }
ylw() { printf '\033[33m%s\033[0m\n' "$*"; }

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }

if [ -d "$ROOT/.git" ]; then
	# Running inside a clone: fast-forward (won't clobber local work).
	grn "Updating repo: $ROOT"
	git -C "$ROOT" pull --ff-only origin "$BRANCH"
	SRC="$ROOT"
else
	# Standalone install: maintain a managed cache clone.
	SRC="${HL2BL_CACHE:-$HOME/.local/share/hl2bl-src}"
	if [ -d "$SRC/.git" ]; then
		grn "Updating cached source: $SRC"
		git -C "$SRC" fetch --depth 1 origin "$BRANCH"
		git -C "$SRC" reset --hard "origin/$BRANCH"
	else
		grn "Cloning $REPO_HTTPS -> $SRC"
		git clone --depth 1 --branch "$BRANCH" "$REPO_HTTPS" "$SRC"
	fi
fi

grn "Reinstalling into Garry's Mod..."
GMOD_DIR="${GMOD_DIR:-}" bash "$SRC/scripts/install.sh"

grn "Update complete."
ylw "Restart Garry's Mod (or change level) to load the new version."
