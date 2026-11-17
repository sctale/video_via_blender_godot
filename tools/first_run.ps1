# First-time generation for the demo pipeline (assets + narration + BGM + import).
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\first_run.ps1
#   powershell -ExecutionPolicy Bypass -File tools\first_run.ps1 -Render
param([switch]$Render)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

foreach ($cmd in @("python", "blender", "godot", "ffmpeg", "ffprobe")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Missing command: $cmd. Install it and make sure it is on PATH."
    }
}

Write-Host "[1/6] Generate brand decal texture ..."
python tools\make_logo.py
if ($LASTEXITCODE -ne 0) { throw "make_logo.py failed" }

Write-Host "[2/6] Build voxel assets in Blender ..."
blender -b --factory-startup --python blender\build_assets.py
if ($LASTEXITCODE -ne 0) { throw "Blender asset build failed" }

Write-Host "[3/6] Generate Chinese narration + timeline ..."
python tools\gen_narration.py
if ($LASTEXITCODE -ne 0) { throw "gen_narration.py failed (network or edge-tts?)" }

Write-Host "[4/6] Generate original BGM ..."
python tools\make_bgm.py
if ($LASTEXITCODE -ne 0) { throw "make_bgm.py failed" }

Write-Host "[5/6] Mix narration + BGM ..."
python tools\mix_audio.py
if ($LASTEXITCODE -ne 0) { throw "mix_audio.py failed" }

Write-Host "[6/6] Import Godot assets ..."
godot --headless --path godot --import
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

if ($Render) {
    Write-Host "Rendering final video ..."
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\render_video.ps1
}

Write-Host "DONE. Generated demo media is All Rights Reserved (see LICENSE-DEMO.md)."
