Set-StrictMode -Version 3.0

# ==== Config ====

$RootDir     = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$SrcDir      = Join-Path $RootDir 'src'
$BuildDir    = Join-Path $RootDir 'build'
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

if (-not (Test-Path $BuildDir)) {
    Write-Error "ERROR: build directory not found: $BuildDir"
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

robocopy $BuildDir $TargetDir /MIR /FFT /R:1 /W:1 >$null

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
    $raw = Get-Content -LiteralPath $ModOrderPath -Raw
    $trimmed = ($raw -split "`r?`n") | ForEach-Object { $_.Trim() }

    if (-not ($trimmed -contains $ModDirName)) {
        # If the file doesn't end with a newline, add one so we don't glue two mod names together.
        if ($raw.Length -gt 0 -and -not $raw.EndsWith("`n")) {
            Add-Content -LiteralPath $ModOrderPath -Value ""
        }

        Add-Content -LiteralPath $ModOrderPath -Value $ModDirName
    }
}

Write-Host "mod_order.txt edited."

Write-Host "Mod deployed to $TargetDir." -ForegroundColor Blue

exit 0
