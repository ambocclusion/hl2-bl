# Shared paths / helpers for the HL2: Borderlands Windows (PowerShell) scripts.
# Dot-sourced by the others:  . "$PSScriptRoot\lib.ps1"
$ErrorActionPreference = "Stop"

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$AddonName = "hl2bl"

function Get-SteamPath {
	try {
		$p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath
		if ($p) { return ($p -replace '/', '\') }
	} catch {}
	foreach ($d in @("C:\Program Files (x86)\Steam", "C:\Program Files\Steam")) {
		if (Test-Path $d) { return $d }
	}
	return $null
}

# Locate GarrysMod\garrysmod across all Steam library folders. Override: $env:GMOD_DIR
function Find-GMod {
	if ($env:GMOD_DIR) {
		if (Test-Path $env:GMOD_DIR) { return $env:GMOD_DIR }
		throw "GMOD_DIR set but not found: $env:GMOD_DIR"
	}

	$libs  = New-Object System.Collections.Generic.List[string]
	$steam = Get-SteamPath
	foreach ($r in @($steam, "C:\Program Files (x86)\Steam", "C:\Program Files\Steam")) {
		if (-not $r) { continue }
		if (Test-Path $r) { $libs.Add($r) }
		$vdf = Join-Path $r "steamapps\libraryfolders.vdf"
		if (Test-Path $vdf) {
			Select-String -Path $vdf -Pattern '"path"\s*"([^"]+)"' | ForEach-Object {
				foreach ($m in $_.Matches) { $libs.Add(($m.Groups[1].Value -replace '\\\\', '\')) }
			}
		}
	}

	foreach ($l in $libs) {
		$cand = Join-Path $l "steamapps\common\GarrysMod\garrysmod"
		if (Test-Path $cand) { return $cand }
	}
	return $null
}

# Remove a directory or junction safely (does NOT delete a junction's target).
function Remove-LinkOrDir([string]$path) {
	if (-not (Test-Path $path)) { return }
	$item = Get-Item $path -Force
	if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
		$item.Delete()                       # remove the junction only
	} else {
		Remove-Item -Recurse -Force $path
	}
}
