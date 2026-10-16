<#
.SYNOPSIS
    Downloads the latest VYTR build into dist\.

.DESCRIPTION
    Re-signing an existing app does not need a new build - the same IPA
    can be signed again and again. Use this only when the source has
    changed and you want those changes on the phone.

    Nothing already in dist\ is deleted or overwritten. The download
    lands in a private staging folder and is moved into dist\ only once
    it is complete, under a name that is not already taken.

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

# Deletes the staging folder, but only when it is unmistakably the one
# this run created: the exact name we generated, sitting directly in the
# temp root, a real directory rather than a link to somewhere else.
function Remove-StagingDirectory {
    param(
        [string]$Path,
        [string]$ExpectedName,
        [string]$ExpectedParent
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if ($ExpectedName -notmatch '^vytr-ipa-[0-9a-f]{32}$') { return }

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    if (-not ($item -is [System.IO.DirectoryInfo])) { return }
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { return }
    if ($item.Name -ne $ExpectedName) { return }

    $parent = [System.IO.Path]::GetFullPath($item.Parent.FullName).TrimEnd('\')
    $expected = [System.IO.Path]::GetFullPath($ExpectedParent).TrimEnd('\')
    if ($parent -ne $expected) { return }

    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

# dist\VYTR-<sha>.ipa, or -2, -3 ... when that name is already taken.
function Get-FreeTargetPath {
    param(
        [string]$Directory,
        [string]$BaseName
    )

    $candidate = Join-Path $Directory ($BaseName + '.ipa')
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }

    for ($n = 2; $n -lt 1000; $n++) {
        $candidate = Join-Path $Directory ("$BaseName-$n.ipa")
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    throw "Could not find a free name for $BaseName in $Directory."
}

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

$workflow = 'Build VYTR IPA'

$stagingRoot = [System.IO.Path]::GetTempPath()
$stagingName = 'vytr-ipa-' + [guid]::NewGuid().ToString('n')
$stagingPath = Join-Path $stagingRoot $stagingName
$stagingOwned = $false

Push-Location $repoRoot
try {
    $runId = $null

    if ($Build) {
        Write-Host 'Starting a build on the macOS runner...' -ForegroundColor Cyan
        $dispatchedAt = (Get-Date).ToUniversalTime().AddSeconds(-30)
        & $gh workflow run $workflow
        if ($LASTEXITCODE -ne 0) { throw 'Could not start the build.' }

        # The dispatched run takes a few seconds to appear. Poll for a run
        # of this workflow started by this dispatch, instead of trusting
        # whatever happens to be newest across every workflow.
        for ($attempt = 1; $attempt -le 20; $attempt++) {
            Start-Sleep -Seconds 3

            $candidate = & $gh run list --workflow $workflow --event workflow_dispatch --limit 1 --json databaseId,createdAt --jq '.[0] | select(.databaseId) | "\(.databaseId) \(.createdAt)"'
            if ($LASTEXITCODE -ne 0) { continue }
            if (-not $candidate) { continue }

            $parts = ([string]$candidate).Trim() -split '\s+'
            if ($parts.Count -lt 2) { continue }

            $createdAt = [datetime]::MinValue
            if (-not [datetime]::TryParse($parts[1], [ref]$createdAt)) { continue }
            if ($createdAt.ToUniversalTime() -lt $dispatchedAt) { continue }

            $runId = $parts[0]
            break
        }

        if (-not $runId) { throw 'The dispatched build did not appear in the run list.' }

        Write-Host "Watching run $runId" -ForegroundColor Cyan
        & $gh run watch $runId --interval 10 --compact --exit-status
        if ($LASTEXITCODE -ne 0) { throw "Run $runId did not finish successfully." }
    }

    if (-not $runId) {
        $runId = & $gh run list --workflow $workflow --status success --limit 1 --json databaseId --jq '.[0].databaseId'
        if ($LASTEXITCODE -ne 0) { throw 'Could not list builds.' }
        if (-not $runId) { throw 'No successful build found.' }
    }

    $runId = ([string]$runId).Trim()

    $headSha = & $gh run view $runId --json headSha --jq '.headSha'
    if ($LASTEXITCODE -ne 0 -or -not $headSha) {
        $baseName = "VYTR-run$runId"
    } else {
        $baseName = 'VYTR-' + ([string]$headSha).Trim().Substring(0, 7)
    }

    if (-not (Test-Path -LiteralPath $distPath)) {
        New-Item -ItemType Directory -Path $distPath | Out-Null
    }

    New-Item -ItemType Directory -Path $stagingPath -ErrorAction Stop | Out-Null
    $stagingOwned = $true

    Write-Host "Downloading the IPA from run $runId..." -ForegroundColor Cyan
    & $gh run download $runId -n 'VYTR-ipa' -D $stagingPath
    if ($LASTEXITCODE -ne 0) { throw 'The download failed. Nothing in dist\ was changed.' }

    $staged = Get-ChildItem -LiteralPath $stagingPath -Filter '*.ipa' -Recurse -File |
        Sort-Object Length -Descending | Select-Object -First 1
    if (-not $staged) { throw 'The run produced no IPA. Nothing in dist\ was changed.' }
    if ($staged.Length -eq 0) { throw 'The downloaded IPA is empty. Nothing in dist\ was changed.' }

    $stagedHash = (Get-FileHash -LiteralPath $staged.FullName -Algorithm SHA256).Hash

    # An identical copy already in dist\ means there is nothing to do, and
    # certainly nothing to overwrite.
    $existing = Get-ChildItem -LiteralPath $distPath -Filter '*.ipa' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -eq $staged.Length } |
        Where-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $stagedHash } |
        Select-Object -First 1

    if ($existing) {
        $sizeMb = [math]::Round($existing.Length / 1MB, 1)
        Write-Host ''
        Write-Host "Already have this build: $($existing.FullName)  ($sizeMb MB)" -ForegroundColor Green
        Write-Host 'Open Sideloadly, drop this file in, and press Start.' -ForegroundColor Green
        return
    }

    $targetPath = Get-FreeTargetPath -Directory $distPath -BaseName $baseName
    Move-Item -LiteralPath $staged.FullName -Destination $targetPath

    $ipa = Get-Item -LiteralPath $targetPath
    $sizeMb = [math]::Round($ipa.Length / 1MB, 1)
    Write-Host ''
    Write-Host "Ready: $($ipa.FullName)  ($sizeMb MB)" -ForegroundColor Green
    Write-Host 'Open Sideloadly, drop this file in, and press Start.' -ForegroundColor Green
}
finally {
    if ($stagingOwned) {
        Remove-StagingDirectory -Path $stagingPath -ExpectedName $stagingName -ExpectedParent $stagingRoot
    }
    Pop-Location
}
