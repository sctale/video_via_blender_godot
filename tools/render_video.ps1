# Render final 1920x1080 video and verify artifacts (pure ASCII messages).
param([switch]$RebuildAssets)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($RebuildAssets) {
    Write-Host "[1/5] Rebuild Blender assets ..."
    blender -b --factory-startup --python blender\build_assets.py
    if ($LASTEXITCODE -ne 0) { throw "Blender asset build failed" }
} else {
    Write-Host "[1/5] Skip Blender rebuild (use -RebuildAssets to force)"
}

Write-Host "[2/5] Import Godot assets ..."
godot --headless --path godot --import
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

Write-Host "[3/5] Render movie (Movie Maker, 30 fps) ..."
if (Test-Path godot\build\final.avi) { Remove-Item godot\build\final.avi -Force }
godot --path godot --fixed-fps 30 --write-movie build\final.avi
if ($LASTEXITCODE -ne 0) { throw "Godot render failed" }

Write-Host "[4/5] Encode MP4 + mux audio ..."
ffmpeg -y -v error -i godot\build\final.avi -i audio\mix.m4a `
    -map 0:v:0 -map 1:a:0 `
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -profile:v high -level 4.1 `
    -movflags +faststart -c:a aac -b:a 192k -ar 48000 -shortest installation-robot-v1.2.0.mp4
if ($LASTEXITCODE -ne 0) { throw "ffmpeg encode failed" }

Write-Host "[5/5] Extract poster + contact sheet + verify ..."
ffmpeg -y -v error -ss 14 -i installation-robot-v1.2.0.mp4 -vframes 1 poster-v1.2.0.png
ffmpeg -y -v error -i installation-robot-v1.2.0.mp4 -vf "select='not(mod(n\,220))',scale=480:-1,tile=4x3" -frames:v 1 contact_sheet-v1.2.0.png

$probeJson = ffprobe -v error -show_streams -show_format -of json installation-robot-v1.2.0.mp4 | ConvertFrom-Json
$v = $probeJson.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
$a = $probeJson.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1
Write-Host ("video: {0}x{1} {2} fps {3} codec={4}" -f $v.width, $v.height, $v.r_frame_rate, $v.nb_frames, $v.codec_name)
Write-Host ("audio: {0} Hz {1} codec={2}" -f $a.sample_rate, $a.channels, $a.codec_name)
Write-Host ("duration: {0}s size: {1} MB" -f [math]::Round([double]$probeJson.format.duration, 2), [math]::Round([double]$probeJson.format.size / 1MB, 2))
if ($v.width -ne 1920 -or $v.height -ne 1080) { throw "Resolution check failed" }
Write-Host "DONE -> installation-robot-v1.2.0.mp4"
