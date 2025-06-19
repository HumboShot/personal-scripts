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

mkdir "D:\Stream" 2>nul

ffmpeg -i "%INPUT_FILE%" -map 0:v -map 0:s? -map 0:d? -map 0:a:5 -c:v copy -c:a copy "D:\Stream\%BASENAME%.mp4"