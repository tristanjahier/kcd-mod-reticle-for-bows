# ==== Config ====

$RootDir     = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$SrcDir      = Join-Path $RootDir 'src'
$DistDir     = Join-Path $RootDir 'dist'
$BuildScript = Join-Path $RootDir 'build.ps1'
$GameModsDir = 'C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance\Mods'
$ModDirName  = 'reticle_for_bows'


# ==== Build ====

& $BuildScript

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: build failed (exit $LASTEXITCODE)."
    exit 1
}

Write-Host ""


# ==== Sanity checks ====

if (-not (Test-Path $DistDir)) {
    Write-Error "ERROR: dist directory not found: $DistDir"
    exit 1
}

if (-not (Test-Path $GameModsDir)) {
    Write-Error "ERROR: game mods directory not found: $GameModsDir"
    exit 1
}


# ==== Deploy using robocopy (mirror) ====

$TargetDir = Join-Path $GameModsDir $ModDirName

if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: robocopy not found."
    exit 1
}

robocopy $DistDir $TargetDir /MIR /FFT /R:1 /W:1 >$null

if ($LASTEXITCODE -ge 8) {
    Write-Error "ERROR: robocopy failed copying files (exit code $LASTEXITCODE)."
    exit 1
}

Write-Host "Mod files copied in the game mods directory."


# ==== Ensure mod_order.txt contains our mod directory name ====

$ModOrderPath = Join-Path $GameModsDir 'mod_order.txt'

if (-not (Test-Path $ModOrderPath)) {
    # Create the file with a single entry.
    Set-Content -Path $ModOrderPath -Value $ModDirName -Encoding UTF8
} else {
    $lines = Get-Content -Path $ModOrderPath -ErrorAction SilentlyContinue
    $trimmed = $lines | ForEach-Object { $_.Trim() }

    if (-not ($trimmed -contains $ModDirName)) {
        Add-Content -Path $ModOrderPath -Value $ModDirName
    }
}

Write-Host "mod_order.txt edited."

Write-Host "Mod deployed to $TargetDir." -ForegroundColor Blue

exit 0
