Set-StrictMode -Version 3.0

# ==== Config ====

$RootDir     = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$BuildDir    = Join-Path $RootDir 'build'
$ReleaseDir  = Join-Path $RootDir 'releases'
$BuildScript = Join-Path $RootDir 'build.ps1'


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


# ==== Build ====

& $BuildScript

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: build failed (exit $LASTEXITCODE)."
    exit 1
}

Write-Host ""


# ==== Sanity checks ====

if (-not (Test-Path $BuildDir)) {
    Write-Error "ERROR: expected build output folder not found: $BuildDir"
    exit 1
}

if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: robocopy not found."
    exit 1
}


# ==== Read mod.manifest to name the zip ====

function Sanitize-FileName([string]$s) {
    # Replace characters that are invalid in Windows' file names.
    if (-not $s) { return $null }
    foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) {
        $s = $s.Replace($ch, '_')
    }
    return ($s -replace '\s+', ' ').Trim()
}

function ReadManifestData([string]$ManifestPath) {
    if (-not (Test-Path $ManifestPath)) {
        throw "ERROR: mod.manifest not found: $ManifestPath"
    }

    try {
        [xml]$xml = Get-Content -LiteralPath $ManifestPath -Raw
    } catch {
        throw "ERROR: failed to read/parse mod.manifest as XML: $ManifestPath"
    }

    # Expected shape:
    # <kcd_mod><info> <modid></modid> <name></name> <version></version> </info></kcd_mod>
    $info = $xml.SelectSingleNode('/kcd_mod/info')
    if (-not $info) {
        throw "ERROR: invalid mod.manifest: missing /kcd_mod/info node: $ManifestPath"
    }

    $modId   = $info.SelectSingleNode('modid')?.InnerText?.Trim()
    $name    = $info.SelectSingleNode('name')?.InnerText?.Trim()
    $version = $info.SelectSingleNode('version')?.InnerText?.Trim()

    if ([string]::IsNullOrWhiteSpace($modId))   { $modId   = $null }
    if ([string]::IsNullOrWhiteSpace($name))    { $name    = $null }
    if ([string]::IsNullOrWhiteSpace($version)) { $version = $null }

    # If the manifest is readable but some required fields are missing, return $null.
    if (-not $modId -or -not $name -or -not $version) {
        return $null
    }

    return [pscustomobject]@{
        Id      = $modId
        Name    = $name
        Version = $version
    }
}

$Manifest = ReadManifestData (Join-Path $BuildDir 'mod.manifest')

if (-not $Manifest) {
    Write-Error "ERROR: mod.manifest is missing required fields (mod ID, name, and version)."
    exit 1
}


Write-Host "Mod name: $($Manifest.Name)"
Write-Host "Release version: $($Manifest.Version)"

$modName  = Sanitize-FileName $Manifest.Name
$version  = Sanitize-FileName $Manifest.Version

if (-not $modName) {
    Write-Error "ERROR: could not derive a valid archive name from mod name."
    exit 1
}

$ReleaseFileName = if ($version) { "$modName v$version.zip" } else { "$modName.zip" }
$ReleasePath = Join-Path $ReleaseDir $ReleaseFileName

Write-Host "Using release archive name: `"$ReleaseFileName`""


# ==== Create the release archive ====

New-Item -Path $ReleaseDir -ItemType Directory -Force | Out-Null

if (Test-Path $ReleasePath) {
    Remove-Item -LiteralPath $ReleasePath -Force -ErrorAction Stop
}

$StagingDir    = Join-Path ([System.IO.Path]::GetTempPath()) ("kcd_release_" + [guid]::NewGuid().ToString('N'))
$StagingModDir = Join-Path $StagingDir $Manifest.Id

New-Item -Path $StagingModDir -ItemType Directory -Force | Out-Null

& robocopy $BuildDir $StagingModDir /MIR /FFT /R:1 /W:1 > $null

if ($LASTEXITCODE -ge 8) {
    Remove-Item -LiteralPath $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "ERROR: robocopy failed staging files (exit code $LASTEXITCODE)."
    exit 1
}

Push-Location $StagingDir
try {
    & $SevenZip a -tzip $ReleasePath $Manifest.Id -r -mx9 > $null
} finally {
    Pop-Location
    Remove-Item -LiteralPath $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: 7-Zip failed to create zip (exit code $LASTEXITCODE)."
    exit 1
}

Write-Host "Release packaged at $ReleasePath" -ForegroundColor Blue
exit 0
