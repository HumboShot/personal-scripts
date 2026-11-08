param(
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    [string[]]$Images
)

Add-Type -AssemblyName System.Drawing

$sizes = 18, 36, 72
$outputDir = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Twitch Badges'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

foreach ($image in $Images) {
    $file = Get-Item -LiteralPath $image -ErrorAction Stop
    $source = [System.Drawing.Image]::FromFile($file.FullName)

    try {
        if ($source.Width -ne $source.Height) {
            Write-Host "Skipped $($file.Name): the image is $($source.Width)x$($source.Height), but badges must be square" -ForegroundColor Red
            continue
        }

        foreach ($size in $sizes) {
            # Premultiplied alpha stops dark halos around transparent edges.
            $target = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($target)
            $attributes = New-Object System.Drawing.Imaging.ImageAttributes

            try {
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

                # Without this wrap mode, GDI+ blends the outer pixels with empty space.
                $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)

                $rectangle = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
                $graphics.DrawImage($source, $rectangle, 0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)

                $outputFile = Join-Path $outputDir "$($file.BaseName)-$size.png"
                $target.Save($outputFile, [System.Drawing.Imaging.ImageFormat]::Png)
                Write-Host "Saved: $outputFile" -ForegroundColor Green
            }
            finally {
                $attributes.Dispose()
                $graphics.Dispose()
                $target.Dispose()
            }
        }
    }
    finally {
        $source.Dispose()
    }
}
