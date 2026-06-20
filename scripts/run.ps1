# Launch Garry's Mod via Steam on a map. Windows equivalent of run.sh.
#   .\run.ps1            -> gm_construct
#   .\run.ps1 d2_coast_03
. "$PSScriptRoot\lib.ps1"

$map   = if ($args.Count -ge 1) { $args[0] } else { "gm_construct" }
$steam = Get-SteamPath
$exe   = if ($steam) { Join-Path $steam "steam.exe" } else { "steam.exe" }

Write-Host "Launching Garry's Mod on '$map'..." -ForegroundColor Green
Start-Process -FilePath $exe -ArgumentList @("-applaunch", "4000", "-console", "+map", $map)
