<#
.SYNOPSIS
    Downloads the latest VYTR build into dist\.

.DESCRIPTION
    Re-signing an existing app does not need a new build - the same IPA
    can be signed again and again. Use this only when the source has
    changed and you want those changes on the phone.

.PARAMETER Build
    Compile the current source first and wait for it, instead of taking
    the most recent successful run.

.EXAMPLE
    .\scripts\Get-LatestIPA.ps1
    .\scripts\Get-LatestIPA.ps1 -Build
#>

[CmdletBinding()]
param(
    [switch]$Build
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$distPath = Join-Path $repoRoot 'dist'

# A stale GITHUB_TOKEN in the environment overrides gh's own stored
# credentials and is a common cause of a confusing refusal.
if ($env:GITHUB_TOKEN) {
    Write-Host 'Ignoring GITHUB_TOKEN from the environment for this run.' -ForegroundColor Yellow
    $env:GITHUB_TOKEN = ''
}

$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) {
    $fallback = 'C:\Program Files\GitHub CLI\gh.exe'
    if (Test-Path $fallback) {
        $gh = $fallback
    } else {
        throw 'GitHub CLI not found. Install it with: winget install --id GitHub.cli'
    }
}

Push-Location $repoRoot
try {
    if ($Build) {
        Write-Host 'Starting a build on the macOS runner...' -ForegroundColor Cyan
        & $gh workflow run 'Build VYTR IPA'
        Start-Sleep -Seconds 6

        $runId = & $gh run list --limit 1 --json databaseId --jq '.[0].databaseId'
        Write-Host "Watching run $runId" -ForegroundColor Cyan
        & $gh run watch $runId --interval 10 --compact
    }

    $runId = & $gh run list --workflow 'Build VYTR IPA' --status success --limit 1 --json databaseId --jq '.[0].databaseId'
    if (-not $runId) { throw 'No successful build found.' }

    if (-not (Test-Path $distPath)) {
        New-Item -ItemType Directory -Path $distPath | Out-Null
    }
    Get-ChildItem -Path $distPath -Filter '*.ipa' -ErrorAction SilentlyContinue | Remove-Item -Force

    Write-Host "Downloading the IPA from run $runId..." -ForegroundColor Cyan
    & $gh run download $runId -n 'VYTR-ipa' -D $distPath

    $ipa = Get-ChildItem -Path $distPath -Filter '*.ipa' | Select-Object -First 1
    if (-not $ipa) { throw 'The run produced no IPA.' }

    $sizeMb = [math]::Round($ipa.Length / 1MB, 1)
    Write-Host ''
    Write-Host "Ready: $($ipa.FullName)  ($sizeMb MB)" -ForegroundColor Green
    Write-Host 'Open Sideloadly, drop this file in, and press Start.' -ForegroundColor Green
}
finally {
    Pop-Location
}
