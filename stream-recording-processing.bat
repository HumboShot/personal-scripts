@echo off
REM Check if a file was provided
IF "%~1"=="" (
    echo Usage: %~nx0 filename
    exit /b 1
)

REM Store the input file in a variable
set "INPUT_FILE=%~1"

REM Get the filename without extension
set "BASENAME=%~n1"

set "OUTPUT_DIR=D:\Stream"
set "OUTPUT_FILE=%OUTPUT_DIR%\%BASENAME%.mp4"
set "CHAPTERS_FILE=%OUTPUT_DIR%\%BASENAME%-chapters.txt"
set "TMP_CHAPTERS=%TEMP%\%BASENAME%_chapters_%RANDOM%.tmp"

mkdir "D:\Stream" 2>nul

if exist "%OUTPUT_FILE%" (
  echo Output already exists. Skipping MP4 generation: "%OUTPUT_FILE%"
) else (
  ffmpeg -i "%INPUT_FILE%" -map 0:v -map 0:s? -map 0:d? -map 0:a:5 -c:v copy -c:a copy "%OUTPUT_FILE%"
)

REM Extract chapters from input file as CSV: start_time,title
if exist "%TMP_CHAPTERS%" del /q "%TMP_CHAPTERS%" >nul 2>nul
ffprobe -v error -show_entries chapter=start_time:chapter_tags=title -of csv=p=0 "%INPUT_FILE%" > "%TMP_CHAPTERS%"

for %%A in ("%TMP_CHAPTERS%") do if %%~zA EQU 0 (
    echo No chapters found. Skipping chapter file generation.
    if exist "%TMP_CHAPTERS%" del /q "%TMP_CHAPTERS%" >nul 2>nul
    goto :eof
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$lines = Get-Content -Path '%TMP_CHAPTERS%' | Where-Object { $_.Trim().Length -gt 0 };" ^
  "if (-not $lines) { exit 2 }" ^
  "$out = @(); $chapters = @(); $index = 1;" ^
  "foreach ($line in $lines) {" ^
  "  $parts = $line -split ',', 2;" ^
  "  $seconds = [double]($parts[0]);" ^
  "  $title = if ($seconds -eq 0) { 'Start of stream' } elseif ($parts.Count -gt 1 -and $parts[1].Trim().Length -gt 0) { $parts[1].Trim().Trim([char]34) } else { 'Chapter ' + $index };" ^
  "  $ts = [TimeSpan]::FromSeconds([math]::Floor($seconds));" ^
  "  if ($ts.Hours -gt 0) { $stamp = ('{0}:{1:00}:{2:00}' -f $ts.Hours, $ts.Minutes, $ts.Seconds) } else { $stamp = ('{0}:{1:00}' -f $ts.Minutes, $ts.Seconds) }" ^
  "  $out += ($stamp + ' ' + $title);" ^
  "  $chapters += [pscustomobject]@{ Start = $seconds; Title = $title };" ^
  "  $index++;" ^
  "}" ^
  "$out | Set-Content -Path '%CHAPTERS_FILE%' -Encoding UTF8;" ^
  "$switchPoints = @($chapters | Where-Object { $_.Title -ieq 'Game switch' } | ForEach-Object { $_.Start } | Sort-Object -Unique);" ^
  "if ($switchPoints.Count -gt 0) {" ^
  "  if (-not (Test-Path '%OUTPUT_FILE%')) { Write-Error 'MP4 output not found for splitting.'; exit 3 }" ^
  "  $durationRaw = (& ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 '%OUTPUT_FILE%').Trim();" ^
  "  if (-not $durationRaw) { Write-Error 'Unable to get output duration for splitting.'; exit 4 }" ^
  "  $totalDuration = [double]$durationRaw;" ^
  "  $starts = @(0) + $switchPoints;" ^
  "  $starts = @($starts | Where-Object { $_ -lt $totalDuration } | Sort-Object -Unique);" ^
  "  for ($i = 0; $i -lt $starts.Count; $i++) {" ^
  "    $start = [double]$starts[$i];" ^
  "    $end = if ($i -lt ($starts.Count - 1)) { [double]$starts[$i + 1] } else { $totalDuration };" ^
  "    if ($end -le $start) { continue }" ^
  "    $partFile = Join-Path '%OUTPUT_DIR%' ('%BASENAME%-part{0:00}.mp4' -f ($i + 1));" ^
  "    & ffmpeg -y -v error -ss ('{0:F3}' -f $start) -to ('{0:F3}' -f $end) -i '%OUTPUT_FILE%' -map 0 -c copy $partFile;" ^
  "    if ($LASTEXITCODE -ne 0) { Write-Error ('Failed to create part file: ' + $partFile); exit 5 }" ^
  "    $partChapterFile = Join-Path '%OUTPUT_DIR%' ('%BASENAME%-part{0:00}-chapters.txt' -f ($i + 1));" ^
  "    $partChapterLines = @();" ^
  "    $partIndex = 1;" ^
  "    foreach ($ch in ($chapters | Where-Object { $_.Start -ge $start -and $_.Start -lt $end })) {" ^
  "      $relative = [math]::Max(0, ($ch.Start - $start));" ^
  "      $relTs = [TimeSpan]::FromSeconds([math]::Floor($relative));" ^
  "      if ($relTs.Hours -gt 0) { $relStamp = ('{0}:{1:00}:{2:00}' -f $relTs.Hours, $relTs.Minutes, $relTs.Seconds) } else { $relStamp = ('{0}:{1:00}' -f $relTs.Minutes, $relTs.Seconds) }" ^
  "      $relTitle = if ($ch.Title -and $ch.Title.Trim().Length -gt 0) { $ch.Title } else { 'Chapter ' + $partIndex };" ^
  "      $partChapterLines += ($relStamp + ' ' + $relTitle);" ^
  "      $partIndex++;" ^
  "    }" ^
  "    if (-not $partChapterLines) {" ^
  "      $partChapterLines = @('0:00 Start of part');" ^
  "    }" ^
  "    $partChapterLines | Set-Content -Path $partChapterFile -Encoding UTF8;" ^
  "  }" ^
  "  Write-Host ('Split files exported to: %OUTPUT_DIR% (%BASENAME%-partXX.mp4)');" ^
  "  Write-Host ('Part chapter files exported to: %OUTPUT_DIR% (%BASENAME%-partXX-chapters.txt)');" ^
  "}"

if errorlevel 1 (
    echo Failed to process chapters and split output.
) else (
    echo YouTube chapters exported to: "%CHAPTERS_FILE%"
)

if exist "%TMP_CHAPTERS%" del /q "%TMP_CHAPTERS%" >nul 2>nul

