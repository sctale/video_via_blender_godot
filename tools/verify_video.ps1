# Verify final video specs, color metadata, black frames and loudness.
param(
    [string]$Version = "1.4.1",
    [string]$Video = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if ([string]::IsNullOrWhiteSpace($Video)) { $Video = "installation-robot-v$Version.mp4" }
if (-not (Test-Path $Video)) { throw "Video not found: $Video" }

$probeJson = ffprobe -v error -show_streams -show_format -of json $Video | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "ffprobe failed" }
$v = $probeJson.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
$a = $probeJson.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1
$duration = [double]$probeJson.format.duration
$size = [long]$probeJson.format.size

$checks = [ordered]@{
    video_codec = ($v.codec_name -eq "h264")
    resolution = ([int]$v.width -eq 1920 -and [int]$v.height -eq 1080)
    fps = ($v.r_frame_rate -eq "30/1")
    frames = ([int]$v.nb_frames -eq 2630)
    pix_fmt = ($v.pix_fmt -eq "yuv420p")
    color_range = ($v.color_range -eq "tv")
    color_space = ($v.color_space -eq "bt709")
    color_transfer = ($v.color_transfer -eq "bt709")
    color_primaries = ($v.color_primaries -eq "bt709")
    audio_codec = ($a.codec_name -eq "aac")
    audio_rate = ([int]$a.sample_rate -eq 48000)
    audio_channels = ([int]$a.channels -eq 2)
    duration = ([math]::Abs($duration - 87.669) -le 0.12)
}

$blackLog = Join-Path $env:TEMP "mmr_black_$PID.log"
$oldEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& ffmpeg -hide_banner -i $Video -vf "blackdetect=d=0.15:pix_th=0.10" -an -f null - 2> $blackLog
$blackCode = $LASTEXITCODE
$ErrorActionPreference = $oldEap
$black = Get-Content $blackLog -Raw
Remove-Item $blackLog -Force
if ($blackCode -ne 0) { throw "blackdetect failed" }
$blackSegments = [regex]::Matches($black, "black_start:[\d.]+ black_end:[\d.]+ black_duration:[\d.]+")
$checks["no_black_ge_0.15s"] = ($blackSegments.Count -eq 0)

$loudLog = Join-Path $env:TEMP "mmr_loud_$PID.log"
$ErrorActionPreference = "Continue"
& ffmpeg -hide_banner -nostats -i $Video -map 0:a -af "ebur128=peak=true" -f null - 2> $loudLog
$loudCode = $LASTEXITCODE
$ErrorActionPreference = $oldEap
$loud = Get-Content $loudLog -Raw
Remove-Item $loudLog -Force
if ($loudCode -ne 0) { throw "ebur128 failed" }
$iMatches = [regex]::Matches($loud, "I:\s+(-?[\d.]+)\s+LUFS")
$pMatches = [regex]::Matches($loud, "Peak:\s+(-?[\d.]+)\s+dBFS")
if ($iMatches.Count -eq 0 -or $pMatches.Count -eq 0) { throw "loudness parse failed" }
$integrated = [double]$iMatches[$iMatches.Count - 1].Groups[1].Value
$truePeak = [double]$pMatches[$pMatches.Count - 1].Groups[1].Value
$checks["loudness_-17_to_-15"] = ($integrated -ge -17.0 -and $integrated -le -15.0)
$checks["true_peak_le_-1"] = ($truePeak -le -1.0)

$report = [ordered]@{
    video = $Video
    version = $Version
    duration = $duration
    size = $size
    width = [int]$v.width
    height = [int]$v.height
    fps = $v.r_frame_rate
    frames = [int]$v.nb_frames
    pix_fmt = $v.pix_fmt
    color_range = $v.color_range
    color_space = $v.color_space
    color_transfer = $v.color_transfer
    color_primaries = $v.color_primaries
    audio_codec = $a.codec_name
    sample_rate = [int]$a.sample_rate
    channels = [int]$a.channels
    integrated_lufs = $integrated
    true_peak_dbfs = $truePeak
    black_segments = $blackSegments.Count
    checks = $checks
}
$outDir = Join-Path $root "out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$reportPath = Join-Path $outDir "verify-v$Version.json"
$report | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath -Encoding UTF8

$failed = @()
foreach ($k in $checks.Keys) {
    if ($checks[$k]) { Write-Host ("[PASS] {0}" -f $k) }
    else { Write-Host ("[FAIL] {0}" -f $k); $failed += $k }
}
Write-Host ("duration={0:N3}s size={1:N2}MB loudness={2:N1}LUFS truePeak={3:N1}dBFS" -f $duration, ($size / 1MB), $integrated, $truePeak)
Write-Host ("report -> {0}" -f $reportPath)
if ($failed.Count -gt 0) { throw ("Verification failed: " + ($failed -join ", ")) }
Write-Host "VERIFY OK"
