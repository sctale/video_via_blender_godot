# Render final 1920x1080 video, mux designed audio, and verify artifacts.
param(
    [switch]$RebuildAssets,
    [switch]$SkipAudio
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$py = "py"
$pyArgs = @("-3")
if (-not (Get-Command py -ErrorAction SilentlyContinue)) { $py = "python"; $pyArgs = @() }
$ver = "1.4.0"

if ($RebuildAssets) {
    Write-Host "[1/7] Rebuild Blender assets ..."
    blender -b --factory-startup --python blender\build_assets.py
    if ($LASTEXITCODE -ne 0) { throw "Blender asset build failed" }
} else {
    Write-Host "[1/7] Skip Blender rebuild (use -RebuildAssets to force)"
}

Write-Host "[2/7] Import Godot assets ..."
godot --headless --path godot --import
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

if (-not $SkipAudio) {
    Write-Host "[3/7] Generate BGM + SFX + final mix ..."
    & $py @pyArgs tools\make_bgm.py
    if ($LASTEXITCODE -ne 0) { throw "BGM generation failed" }
    & $py @pyArgs tools\make_sfx.py
    if ($LASTEXITCODE -ne 0) { throw "SFX generation failed" }
    & $py @pyArgs tools\mix_audio.py
    if ($LASTEXITCODE -ne 0) { throw "Audio mix failed" }
} else {
    Write-Host "[3/7] Skip audio generation (use existing audio/mix.m4a)"
}

Write-Host "[4/7] Render movie (Movie Maker, 30 fps) ..."
if (Test-Path godot\build\final.avi) { Remove-Item godot\build\final.avi -Force }
godot --path godot --fixed-fps 30 --write-movie build\final.avi
if ($LASTEXITCODE -ne 0) { throw "Godot render failed" }

Write-Host "[5/7] Encode MP4 + mux audio (BT.709 limited range) ..."
ffmpeg -y -v error -i godot\build\final.avi -i audio\mix.m4a `
    -map 0:v:0 -map 1:a:0 `
    -vf "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p" `
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -profile:v high -level 4.1 `
    -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 `
    -bsf:v "h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1" `
    -movflags +faststart -c:a aac -b:a 192k -ar 48000 -frames:v 2630 -shortest installation-robot-v$ver.mp4
if ($LASTEXITCODE -ne 0) { throw "ffmpeg encode failed" }

Write-Host "[6/7] Extract poster + event-based contact sheet ..."
$previewDir = "out/previews/v$ver"
New-Item -ItemType Directory -Force -Path $previewDir | Out-Null
ffmpeg -y -v error -ss 0.5 -i installation-robot-v$ver.mp4 -vframes 1 poster-v$ver.png
if ($LASTEXITCODE -ne 0) { throw "Poster extract failed" }
$times = @("0.5", "8.5", "14", "21.5", "29.7", "38", "47.6", "57", "66.5", "70.2", "75", "82")
foreach ($t in $times) {
    ffmpeg -y -v error -ss $t -i installation-robot-v$ver.mp4 -vframes 1 "$previewDir/frame_$t.png"
    if ($LASTEXITCODE -ne 0) { throw "Contact frame extract failed at $t" }
}
& $py @pyArgs tools\make_contact_sheet.py --dir $previewDir --times ($times -join ",") --out contact_sheet-v$ver.png
if ($LASTEXITCODE -ne 0) { throw "Contact sheet failed" }

Write-Host "[7/7] Verify specs, color metadata, black frames and loudness ..."
& (Join-Path $PSScriptRoot "verify_video.ps1") -Version $ver
Write-Host ("DONE -> installation-robot-v{0}.mp4" -f $ver)
