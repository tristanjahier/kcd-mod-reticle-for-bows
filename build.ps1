# ==== Config ====

$RootDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$SrcDir  = Join-Path $RootDir 'src'
$DataDir = Join-Path $SrcDir 'Data'
$DistDir = Join-Path $RootDir 'dist'
$PakName = 'data'


# ==== Find 7zip ====

$SevenZip = (Get-Command '7z.exe' -ErrorAction SilentlyContinue).Path

if (-not $SevenZip) {
    $candidates = @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
    )

    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { $SevenZip = $c; break }
    }
}

if (-not $SevenZip) {
    Write-Error "ERROR: 7-Zip not found. Install 7-Zip or if it is installed check your `$env:PATH."
    exit 1
}

Write-Host "Using 7zip: $SevenZip"


# ==== Sanity checks ====

if (-not (Test-Path $DataDir)) {
    Write-Error "ERROR: Data directory not found. It is mandatory for KC:D mods."
    exit 1
}


# ==== Prepare dist\ directory ====

if (Test-Path $DistDir) {
    Remove-Item -LiteralPath $DistDir -Recurse -Force -ErrorAction Stop
}

New-Item -Path $DistDir -ItemType Directory -Force | Out-Null


# ==== 'Pak' the contents of the Data\ directory ====

New-Item -Path (Join-Path $DistDir 'Data') -ItemType Directory -Force | Out-Null

$archivePath = Join-Path $DistDir "Data\$PakName.pak"
Write-Host "Building .pak with contents of Data\ ... " -NoNewLine

Push-Location $DataDir
& $SevenZip a -tzip $archivePath * -r -mx9 >$null
Pop-Location

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: 7-Zip failed to create pak (exit code $LASTEXITCODE)."
    exit 1
}

Write-Host "✔"


# ==== Copy everything else to dist ====

if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: robocopy not found."
    exit 1
}

Write-Host "Copying everything else ... " -NoNewLine
& robocopy $SrcDir $DistDir /MIR /XD (Join-Path $SrcDir 'Data') /FFT /R:1 /W:1 >$null

if ($LASTEXITCODE -ge 8) {
    Write-Error "ERROR: robocopy failed copying files (exit code $LASTEXITCODE)."
    exit 1
}

Write-Host "✔"

Write-Host "Build complete in $DistDir." -ForegroundColor Blue
exit 0
