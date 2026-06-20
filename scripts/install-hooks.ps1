# Point git at the version-controlled hooks. Windows equivalent of
# install-hooks.sh. (Hooks are bash; Git for Windows runs them via its bundled sh.)
. "$PSScriptRoot\lib.ps1"

git -C $RepoRoot config core.hooksPath .githooks
Write-Host "Hooks installed (core.hooksPath=.githooks)." -ForegroundColor Green
Write-Host "Enable the opt-in pre-push build check with: git config hl2bl.prepushBuild true" -ForegroundColor Yellow
