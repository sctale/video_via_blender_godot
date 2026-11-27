# Render deterministic key stills through the real Godot scene.
param(
    [string]$Times = "0.5,8.5,14,21.5,29.7,38,47.6,57,66.5,70.2,75,82",
    [switch]$Audit,
    [string]$OutDir = "out/previews/current"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$py = "py"
$pyArgs = @("-3")
if (-not (Get-Command py -ErrorAction SilentlyContinue)) { $py = "python"; $pyArgs = @() }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if ($Audit) { $env:CAMERA_AUDIT = "1" } else { Remove-Item Env:CAMERA_AUDIT -ErrorAction SilentlyContinue }
$list = $Times.Split(",")
foreach ($t in $list) {
    $t = $t.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) { continue }
    Write-Host ("[still] t={0}" -f $t)
    $env:STILL_T = $t
    godot --path godot --fixed-fps 30 --write-movie "build/still_$t.avi"
    if ($LASTEXITCODE -ne 0) { Remove-Item Env:STILL_T; Remove-Item Env:CAMERA_AUDIT -ErrorAction SilentlyContinue; throw "Godot still render failed at $t" }
    ffmpeg -y -v error -i "godot/build/still_$t.avi" -frames:v 1 "$OutDir/still_$t.png"
    if ($LASTEXITCODE -ne 0) { Remove-Item Env:STILL_T; Remove-Item Env:CAMERA_AUDIT -ErrorAction SilentlyContinue; throw "Still extract failed at $t" }
}
Remove-Item Env:STILL_T
Remove-Item Env:CAMERA_AUDIT -ErrorAction SilentlyContinue
& $py @pyArgs tools\make_contact_sheet.py --dir $OutDir --times $Times --out "$OutDir/contact_sheet.png"
if ($LASTEXITCODE -ne 0) { throw "Contact sheet failed" }
Write-Host ("STILLS OK -> {0}" -f $OutDir)
