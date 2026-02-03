Set-StrictMode -Version 3.0

# ==== Config ====

$RootDir  = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$SrcDir   = Join-Path $RootDir 'src'
$DataDir  = Join-Path $SrcDir 'Data'
$BuildDir = Join-Path $RootDir 'build'
$PakName  = 'data'


# ==== Find 7zip ====

$SevenZip = Get-Command '7z.exe' -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source

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


# ==== Prepare build\ directory ====

if (Test-Path $BuildDir) {
    Remove-Item -LiteralPath $BuildDir -Recurse -Force -ErrorAction Stop
}

New-Item -Path $BuildDir -ItemType Directory -Force | Out-Null


# ==== Copy everything to build\ ====

if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: robocopy not found."
    exit 1
}

Write-Host "Copying everything ... " -NoNewLine
& robocopy $SrcDir $BuildDir /MIR /XD 'Data' /FFT /R:1 /W:1 >$null

if ($LASTEXITCODE -ge 8) {
    Write-Error "ERROR: robocopy failed copying files (exit code $LASTEXITCODE)."
    exit 1
}

Write-Host "✔"


# ==== 'Pak' the contents of the Data\ directory ====

New-Item -Path (Join-Path $BuildDir 'Data') -ItemType Directory -Force | Out-Null

$pakPath = Join-Path $BuildDir "Data\$PakName.pak"
Write-Host "Building .pak with contents of Data\ ... " -NoNewLine

Push-Location $DataDir
try {
    & $SevenZip a -tzip $pakPath * -r -mx9 >$null
} finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: 7-Zip failed to create pak (exit code $LASTEXITCODE)."
    exit 1
}

Write-Host "✔"

Write-Host "Build complete in $BuildDir." -ForegroundColor Blue
exit 0
