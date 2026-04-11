param(
    [Parameter(Mandatory = $true)]
    [string]$SuiteId,

    [string]$MigName = ""
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

function Read-JsonSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        return Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-CaseRunStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunDir
    )

    $comparePath = Join-Path $RunDir "compare.json"
    $evalPath = Join-Path $RunDir "eval.json"

    $hasCompare = Test-Path $comparePath
    $hasEval = Test-Path $evalPath

    $eval = if ($hasEval) { Read-JsonSafe -Path $evalPath } else { $null }

    $verdict = "SKIPPED_OR_PENDING"

    if ($eval -and $eval.recommendedVerdict) {
        $verdict = [string]$eval.recommendedVerdict
    }

    return [pscustomobject]@{
        Compared  = $hasCompare
        Evaluated = $hasEval
        Verdict   = $verdict
    }
}

function Get-SuiteCaseIds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuitesRoot,

        [Parameter(Mandatory = $true)]
        [string]$SuiteId
    )

    $suitePath = Join-Path $SuitesRoot (Join-Path $SuiteId "suite.json")

    if (-not (Test-Path $suitePath)) {
        throw "Suite not found: $suitePath"
    }

    $suiteJson = Read-JsonSafe -Path $suitePath
    if (-not $suiteJson) {
        throw "Failed to read suite.json: $suitePath"
    }

    if (-not $suiteJson.caseIds -or $suiteJson.caseIds.Count -eq 0) {
        throw "No caseIds found in suite: $SuiteId"
    }

    return [string[]]$suiteJson.caseIds
}

function Get-SuiteVerdict {
    param(
        [int]$PassCount,
        [int]$ReviewCount,
        [int]$FailCount,
        [int]$SkippedCount
    )

    if ($FailCount -gt 0) {
        return "FAIL"
    }

    if ($ReviewCount -gt 0) {
        return "REVIEW"
    }

    if ($SkippedCount -gt 0) {
        return "SKIPPED_OR_PENDING"
    }

    if ($PassCount -gt 0) {
        return "PASS"
    }

    return "SKIPPED_OR_PENDING"
}

$repoRoot = Get-RepoRoot
$suitesRoot = Join-Path $repoRoot "tests\suites"
$runCaseScript = Join-Path $PSScriptRoot "run-case.ps1"
$runsRoot = Join-Path $repoRoot "runs"

if (-not (Test-Path $runCaseScript)) {
    throw "run-case.ps1 not found: $runCaseScript"
}

$caseIds = Get-SuiteCaseIds -SuitesRoot $suitesRoot -SuiteId $SuiteId

$summaryLines = New-Object System.Collections.Generic.List[string]

$passCount = 0
$reviewCount = 0
$failCount = 0
$skippedCount = 0

Write-Host ("===== Running suite: {0} =====" -f $SuiteId)

foreach ($caseId in $caseIds) {
    Write-Host ""
    Write-Host ("===== Running case: {0} =====" -f $caseId)

    $invokeParams = @{
        CaseId = $caseId
    }

    if (-not [string]::IsNullOrWhiteSpace($MigName)) {
        $invokeParams.MigName = $MigName
    }

    $capturedLines = New-Object System.Collections.Generic.List[string]
    $runId = $null

    try {
        & $runCaseScript @invokeParams 2>&1 | ForEach-Object {
            $line = $_.ToString()
            $capturedLines.Add($line)
            Write-Host $line

            if ($line -match '^RUN_RESULT:\s*(.+?)\s*$') {
                $runId = $matches[1].Trim()
            }
        }
    }
    catch {
        Write-Error ("run-case failed for {0}: {1}" -f $caseId, $_.Exception.Message)
        throw
    }

    if ([string]::IsNullOrWhiteSpace($runId)) {
        throw "RUN_RESULT not found in run-case output for case: $caseId"
    }

    $runDir = Join-Path $runsRoot $runId

    if (-not (Test-Path $runDir)) {
        throw "Run directory not found: $runDir"
    }

    $caseStatus = Get-CaseRunStatus -RunDir $runDir

    switch ($caseStatus.Verdict) {
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

    $summaryLines.Add((
        "{0} : {1} (Compared={2}, Evaluated={3})" -f
        $caseId,
        $caseStatus.Verdict,
        $caseStatus.Compared,
        $caseStatus.Evaluated
    ))
}

$suiteVerdict = Get-SuiteVerdict `
    -PassCount $passCount `
    -ReviewCount $reviewCount `
    -FailCount $failCount `
    -SkippedCount $skippedCount

Write-Host ""
Write-Host ("===== SUITE SUMMARY: {0} =====" -f $SuiteId)

foreach ($line in $summaryLines) {
    Write-Host $line
}

Write-Host ""
Write-Host ("SuiteVerdict       : {0}" -f $suiteVerdict)
Write-Host ("PASS              : {0}" -f $passCount)
Write-Host ("REVIEW            : {0}" -f $reviewCount)
Write-Host ("FAIL              : {0}" -f $failCount)
Write-Host ("SKIPPED_OR_PENDING: {0}" -f $skippedCount)

Write-Output ("SUITE_RESULT: {0} | Verdict={1}" -f $SuiteId, $suiteVerdict)
