param(
    [string]$SuiteId = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    if ($PSScriptRoot) {
        return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }

    return (Get-Location).Path
}

function Get-SuiteIds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuitesRoot,

        [string]$SuiteId = ""
    )

    if (-not (Test-Path $SuitesRoot)) {
        throw "Suites root not found: $SuitesRoot"
    }

    if (-not [string]::IsNullOrWhiteSpace($SuiteId)) {
        return @($SuiteId)
    }

    $suiteFiles = Get-ChildItem -Path $SuitesRoot -Recurse -Filter "suite.json" -ErrorAction SilentlyContinue |
        Sort-Object FullName

    if (-not $suiteFiles -or $suiteFiles.Count -eq 0) {
        throw "No suite.json files found under: $SuitesRoot"
    }

    $suiteIds = New-Object System.Collections.Generic.List[string]

    foreach ($file in $suiteFiles) {
        $suiteDirName = Split-Path $file.DirectoryName -Leaf
        if (-not [string]::IsNullOrWhiteSpace($suiteDirName)) {
            $suiteIds.Add($suiteDirName)
        }
    }

    if ($suiteIds.Count -eq 0) {
        throw "No suites found."
    }

    return $suiteIds
}

function Get-SuiteVerdictFromOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$OutputLines
    )

    foreach ($line in $OutputLines) {
        if ($line -match '^SUITE_RESULT:\s*(.+?)\s*\|\s*Verdict=(.+?)\s*$') {
            return [pscustomobject]@{
                SuiteId = $matches[1].Trim()
                Verdict = $matches[2].Trim()
            }
        }
    }

    return $null
}

$repoRoot = Get-RepoRoot
$suitesRoot = Join-Path $repoRoot "tests\suites"
$runSuiteScript = Join-Path $PSScriptRoot "run-suite.ps1"

if (-not (Test-Path $runSuiteScript)) {
    throw "run-suite.ps1 not found: $runSuiteScript"
}

$suiteIds = Get-SuiteIds -SuitesRoot $suitesRoot -SuiteId $SuiteId

$summaryLines = New-Object System.Collections.Generic.List[string]

$passCount = 0
$reviewCount = 0
$failCount = 0
$skippedCount = 0

Write-Host "===== REGRESSION START ====="

foreach ($currentSuiteId in $suiteIds) {
    Write-Host ""
    $capturedLines = New-Object System.Collections.Generic.List[string]

    try {
        & $runSuiteScript -SuiteId $currentSuiteId 2>&1 | ForEach-Object {
            $line = $_.ToString()
            $capturedLines.Add($line)
            Write-Host $line
        }
    }
    catch {
        Write-Error ("run-suite failed for {0}: {1}" -f $currentSuiteId, $_.Exception.Message)
        throw
    }

    $suiteResult = Get-SuiteVerdictFromOutput -OutputLines @($capturedLines)

    if (-not $suiteResult) {
        throw "SUITE_RESULT not found in run-suite output for suite: $currentSuiteId"
    }

    $summaryLines.Add(("{0} : {1}" -f $suiteResult.SuiteId, $suiteResult.Verdict))

    switch ($suiteResult.Verdict) {
        "PASS" {
            $passCount++
        }
        "REVIEW" {
            $reviewCount++
        }
        "FAIL" {
            $failCount++
        }
        default {
            $skippedCount++
        }
    }
}

Write-Host ""
Write-Host "===== REGRESSION SUMMARY ====="
Write-Host ""

foreach ($line in $summaryLines) {
    Write-Host $line
}

$total = $passCount + $reviewCount + $failCount + $skippedCount

Write-Host ""
Write-Host ("Total             : {0}" -f $total)
Write-Host ("PASS              : {0}" -f $passCount)
Write-Host ("REVIEW            : {0}" -f $reviewCount)
Write-Host ("FAIL              : {0}" -f $failCount)
Write-Host ("SKIPPED_OR_PENDING: {0}" -f $skippedCount)
Write-Host ""
Write-Host "===== REGRESSION DONE ====="
