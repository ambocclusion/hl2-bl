#!/usr/bin/env bash
# Mount the addon into Garry's Mod by symlinking it into garrysmod/addons/.
# GMod's legacy-addons folder follows directory symlinks, so edits in the repo
# are live in-game (re-run lua_reloadents / changelevel to pick up changes).
. "$(dirname "$0")/lib.sh"

[ -f "$ADDON_SRC/addon.json" ] || die "No addon.json in $ADDON_SRC"
[ -d "$GMOD_DIR" ] || die "Garry's Mod not found at: $GMOD_DIR
  Install Garry's Mod (AppId $GMOD_APPID) via Steam."

mkdir -p "$GMOD_ADDONS"
LINK="$GMOD_ADDONS/$ADDON_NAME"

if [ -L "$LINK" ]; then
  rm "$LINK"
elif [ -e "$LINK" ]; then
  die "$LINK exists and isn't a symlink; refusing to overwrite."
fi

ln -s "$ADDON_SRC" "$LINK"
info "Linked $LINK -> $ADDON_SRC"

# Gamemode symlink into garrysmod/gamemodes.
mkdir -p "$GMOD_GAMEMODES"
GMLINK="$GMOD_GAMEMODES/$GAMEMODE_NAME"
if [ -L "$GMLINK" ]; then
  rm "$GMLINK"
elif [ -e "$GMLINK" ]; then
  die "$GMLINK exists and isn't a symlink; refusing to overwrite."
fi
ln -s "$GAMEMODE_SRC" "$GMLINK"
info "Linked $GMLINK -> $GAMEMODE_SRC"

info "In GMod: New Game -> Gamemode 'HL2: Borderlands'. Check console for: [HL2BL] v... loaded"
