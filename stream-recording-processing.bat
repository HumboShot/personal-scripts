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
  "$out = @(); $index = 1;" ^
  "foreach ($line in $lines) {" ^
  "  $parts = $line -split ',', 2;" ^
  "  $seconds = [double]($parts[0]);" ^
    "  $title = if ($parts.Count -gt 1 -and $parts[1].Trim().Length -gt 0) { $parts[1].Trim().Trim([char]34) } else { 'Chapter ' + $index };" ^
  "  $ts = [TimeSpan]::FromSeconds([math]::Floor($seconds));" ^
  "  if ($ts.Hours -gt 0) { $stamp = ('{0}:{1:00}:{2:00}' -f $ts.Hours, $ts.Minutes, $ts.Seconds) } else { $stamp = ('{0}:{1:00}' -f $ts.Minutes, $ts.Seconds) }" ^
  "  $out += ($stamp + ' ' + $title);" ^
  "  $index++;" ^
  "}" ^
  "$out | Set-Content -Path '%CHAPTERS_FILE%' -Encoding UTF8;"

if errorlevel 1 (
    echo Failed to generate YouTube chapter timestamps.
) else (
    echo YouTube chapters exported to: "%CHAPTERS_FILE%"
)

if exist "%TMP_CHAPTERS%" del /q "%TMP_CHAPTERS%" >nul 2>nul

