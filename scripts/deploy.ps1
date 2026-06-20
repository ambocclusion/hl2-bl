# DEV deploy: junction the addon + gamemode into Garry's Mod so repo edits are
# live. Windows equivalent of deploy.sh. Junctions don't require admin.
. "$PSScriptRoot\lib.ps1"

$gmod = Find-GMod
if (-not $gmod) { Write-Error "Garry's Mod not found. Install it via Steam or set `$env:GMOD_DIR."; exit 1 }

function Link-Dir([string]$src, [string]$dest) {
	Remove-LinkOrDir $dest
	$parent = Split-Path -Parent $dest
	if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
	New-Item -ItemType Junction -Path $dest -Target $src | Out-Null
	Write-Host "Linked $dest -> $src" -ForegroundColor Green
}

Link-Dir "$RepoRoot\addon"                (Join-Path $gmod "addons\$AddonName")
Link-Dir "$RepoRoot\gamemodes\$AddonName" (Join-Path $gmod "gamemodes\$AddonName")
Write-Host "In GMod: New Game -> Gamemode 'HL2: Borderlands'." -ForegroundColor Yellow
