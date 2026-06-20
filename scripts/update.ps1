# Auto-update from git, then reinstall into Garry's Mod. Windows equivalent of
# update.sh. Works from a clone or standalone (keeps a cache clone).
. "$PSScriptRoot\lib.ps1"

$branch   = if ($env:HL2BL_BRANCH) { $env:HL2BL_BRANCH } else { "main" }
$repoHttp = "https://github.com/ambocclusion/hl2-bl.git"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error "git is required (install Git for Windows)."; exit 1 }

if (Test-Path (Join-Path $RepoRoot ".git")) {
	Write-Host "Updating repo: $RepoRoot" -ForegroundColor Green
	git -C $RepoRoot pull --ff-only origin $branch
	$src = $RepoRoot
} else {
	$cache = if ($env:HL2BL_CACHE) { $env:HL2BL_CACHE } else { Join-Path $env:LOCALAPPDATA "hl2bl-src" }
	if (Test-Path (Join-Path $cache ".git")) {
		Write-Host "Updating cached source: $cache" -ForegroundColor Green
		git -C $cache fetch --depth 1 origin $branch
		git -C $cache reset --hard "origin/$branch"
	} else {
		Write-Host "Cloning $repoHttp -> $cache" -ForegroundColor Green
		git clone --depth 1 --branch $branch $repoHttp $cache
	}
	$src = $cache
}

Write-Host "Reinstalling into Garry's Mod..." -ForegroundColor Green
& "$src\scripts\install.ps1"
Write-Host "Update complete. Restart GMod (or change level) to load it." -ForegroundColor Yellow
