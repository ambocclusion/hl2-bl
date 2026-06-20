#!/usr/bin/env bash
# Launch Garry's Mod (listen server) with the addon, via Steam so the runtime
# is set up. Pass a map as the first arg (default gm_construct).
#   scripts/run.sh                 # gm_construct
#   scripts/run.sh d1_trainstation_02   # an HL2 campaign map (HL2 must be mounted)
. "$(dirname "$0")/lib.sh"

[ -d "$GMOD_DIR" ] || die "Garry's Mod not installed at: $GMOD_DIR"

MAP="${1:-gm_construct}"
info "Launching Garry's Mod on map '$MAP'..."
# -applaunch routes through Steam so the GMod runtime/libraries load correctly.
exec steam -applaunch "$GMOD_APPID" -console +map "$MAP"
