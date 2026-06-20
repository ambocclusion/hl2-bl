# Install HL2: Borderlands into Garry's Mod (copies files). Windows equivalent
# of install.sh. Override detection with: $env:GMOD_DIR = "C:\...\garrysmod"
. "$PSScriptRoot\lib.ps1"

$gmod = Find-GMod
if (-not $gmod) { Write-Error "Garry's Mod not found. Install it via Steam or set `$env:GMOD_DIR."; exit 1 }
Write-Host "Found Garry's Mod: $gmod" -ForegroundColor Green

function Install-Dir([string]$src, [string]$dest) {
	if (-not (Test-Path $src)) { Write-Error "Missing source: $src"; exit 1 }
	Remove-LinkOrDir $dest
	$parent = Split-Path -Parent $dest
	if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
	Copy-Item -Recurse -Force $src $dest
}

Install-Dir "$RepoRoot\addon"                  (Join-Path $gmod "addons\$AddonName")
Write-Host "Installed addon    -> $gmod\addons\$AddonName" -ForegroundColor Green
Install-Dir "$RepoRoot\gamemodes\$AddonName"   (Join-Path $gmod "gamemodes\$AddonName")
Write-Host "Installed gamemode -> $gmod\gamemodes\$AddonName" -ForegroundColor Green

Write-Host ""
Write-Host "HL2: Borderlands installed." -ForegroundColor Green
Write-Host "Launch GMod -> New Game -> Gamemode: 'HL2: Borderlands' -> pick a map." -ForegroundColor Yellow
