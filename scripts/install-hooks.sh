#!/usr/bin/env bash
# Point git at the version-controlled hooks in .githooks/. Run once per clone.
. "$(dirname "$0")/lib.sh"

cd "$PROJECT_ROOT"
chmod +x .githooks/* scripts/*.sh
git config core.hooksPath .githooks
info "Hooks installed (core.hooksPath=.githooks)."
info "Enable the pre-push build check with: git config hl2bl.prepushBuild true"
