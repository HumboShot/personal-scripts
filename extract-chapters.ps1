param(
    [string]$FolderPath = (Get-Location).Path
)

# Check if FFmpeg is available
$ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
if (-not $ffprobe) {
    Write-Host "Error: FFmpeg/ffprobe is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install FFmpeg from https://ffmpeg.org/download.html" -ForegroundColor Yellow
    exit 1
}

Write-Host "Processing MP4 files in: $FolderPath" -ForegroundColor Cyan
Write-Host ""

# Get all MP4 files
$mp4Files = Get-ChildItem -Path $FolderPath -Filter "*.mp4" -File

if ($mp4Files.Count -eq 0) {
    Write-Host "No MP4 files found in: $FolderPath" -ForegroundColor Yellow
    exit 0
}

foreach ($file in $mp4Files) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor White
    
    $outputFile = Join-Path $file.DirectoryName "$($file.BaseName).txt"
    
    # Remove existing output file
    if (Test-Path $outputFile) {
        Remove-Item $outputFile -Force
    }
    
    # Use ffprobe to extract chapter information
    # ffprobe outputs chapter data in a structured format
    $chapters = @()
    
    try {
        # Get JSON output from ffprobe with chapter information
        $ffprobeOutput = & ffprobe -v error -show_entries chapter=start_time, end_time, tags=title -of json "$($file.FullName)" 2>&1
        $jsonData = $ffprobeOutput | ConvertFrom-Json
        
        if ($jsonData.chapters -and $jsonData.chapters.Count -gt 0) {
            $isFirst = $true
            foreach ($chapter in $jsonData.chapters) {
                $startTime = [double]$chapter.start_time
                $totalSecs = [Math]::Floor($startTime)
                
                # Convert seconds to HH:MM:SS format
                $hours = [Math]::Floor($totalSecs / 3600)
                $minutes = [Math]::Floor(($totalSecs % 3600) / 60)
                $seconds = $totalSecs % 60
                
                $timestamp = "{0:D2}:{1:D2}:{2:D2}" -f [int]$hours, [int]$minutes, [int]$seconds
                
                # First chapter is always "Start of stream"
                if ($isFirst) {
                    $title = "Start of stream"
                    $isFirst = $false
                }
                elseif ($chapter.tags -and $chapter.tags.title) {
                    $title = $chapter.tags.title
                }
                else {
                    $title = "Highlight"
                }
                
                $chapters += "$timestamp $title"
            }
        }
        
        # If no chapters found via JSON, try metadata export
        if ($chapters.Count -eq 0) {
            $tempMetaFile = Join-Path $file.DirectoryName "temp_metadata.txt"
            & ffmpeg -i "$($file.FullName)" -f ffmetadata "$tempMetaFile" -y 2>&1 | Out-Null
            
            if (Test-Path $tempMetaFile) {
                $metadataContent = Get-Content $tempMetaFile
                $inChapter = $false
                $currentTime = $null
                $currentTitle = $null
                
                foreach ($line in $metadataContent) {
                    if ($line -eq "[CHAPTER]") {
                        $inChapter = $true
                    }
                    elseif ($line -match "^\[" -and $line -ne "[CHAPTER]") {
                        if ($inChapter -and $currentTime -and $currentTitle) {
                            $chapters += "$currentTime $currentTitle"
                        }
                        $inChapter = $false
                        $currentTime = $null
                        $currentTitle = $null
                    }
                    elseif ($inChapter) {
                        if ($line -match "TIMEBASE=") {
                            # Extract timebase if needed
                        }
                        elseif ($line -match "^START=(\d+)") {
                            $startFrames = [long]$matches[1]
                            # Convert frames/timebase to seconds
                            $totalSecs = [Math]::Floor($startFrames / 1000)
                            $hours = [Math]::Floor($totalSecs / 3600)
                            $minutes = [Math]::Floor(($totalSecs % 3600) / 60)
                            $seconds = $totalSecs % 60
                            $currentTime = "{0:D2}:{1:D2}:{2:D2}" -f [int]$hours, [int]$minutes, [int]$seconds
                        }
                        elseif ($line -match "^title=(.+)") {
                            $currentTitle = $matches[1]
                        }
                    }
                }
                
                # Add last chapter if exists
                if ($inChapter -and $currentTime -and $currentTitle) {
                    $chapters += "$currentTime $currentTitle"
                }
                
                Remove-Item $tempMetaFile -Force
            }
        }
    }
    catch {
        Write-Host "  [Error] Failed to process: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
    
    # Handle duplicate chapter titles by adding numeric suffixes
    if ($chapters.Count -gt 0) {
        # Count occurrences of each title
        $titleCount = @{}
        $titleIndex = @{}
        
        foreach ($chapter in $chapters) {
            # Extract title from "HH:MM:SS Title" format
            $parts = $chapter -split ' ', 2
            $title = if ($parts.Count -gt 1) { $parts[1] } else { "Highlight" }
            
            if (-not $titleCount.ContainsKey($title)) {
                $titleCount[$title] = 0
                $titleIndex[$title] = 0
            }
            $titleCount[$title]++
        }
        
        # Add suffixes to duplicates
        $titleCounter = @{}
        $processedChapters = @()
        
        foreach ($chapter in $chapters) {
            # Extract timestamp and title
            $parts = $chapter -split ' ', 2
            $timestamp = $parts[0]
            $title = if ($parts.Count -gt 1) { $parts[1] } else { "Highlight" }
            
            # Add suffix if title appears more than once
            if ($titleCount[$title] -gt 1) {
                if (-not $titleCounter.ContainsKey($title)) {
                    $titleCounter[$title] = 1
                }
                else {
                    $titleCounter[$title]++
                }
                $newChapter = "$timestamp $title $($titleCounter[$title])"
            }
            else {
                $newChapter = $chapter
            }
            
            $processedChapters += $newChapter
        }
        
        # Write chapters to output file
        $processedChapters | Out-File -FilePath $outputFile -Encoding UTF8
        Write-Host "  [Created] $($file.BaseName).txt ($($processedChapters.Count) chapters)" -ForegroundColor Green
    }
    else {
        Write-Host "  [Warning] No chapters found in this file" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

Write-Host "Completed! Check for .txt files with the same names as your MP4 files." -ForegroundColor Cyan
