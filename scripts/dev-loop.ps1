param(
    [Parameter(Mandatory = $true)]
    [string]$SuiteId,

    [string]$RunDate = "",

    [string]$CurrentTask = "",

    [string]$Notes = "",

    [string]$HandoffOutFile = "",

    [switch]$SkipSummary,

    [switch]$SkipHandoff
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

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host ("===== " + $Title + " =====")
}

function Test-ScriptExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.File]::Exists($Path)
}

function Resolve-RunDate {
    param(
        [string]$RequestedRunDate
    )
    
    if (-not [string]::IsNullOrWhiteSpace($RequestedRunDate)) {
        return $RequestedRunDate.Trim()
    }

    return (Get-Date).ToString("yyyy-MM-dd")
}

function Resolve-HandoffOutFile {
    param(
        [string]$RequestedPath,
        [string]$ResolvedRunDate,
        [string]$ResolvedSuiteId
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return $RequestedPath.Trim()
    }

    return ("tmp/handoff-" + $ResolvedRunDate + "-" + $ResolvedSuiteId + ".txt")
}

$repoRoot = Get-RepoRoot

$runEntryPath = Join-Path $PSScriptRoot "run-regression-and-summary.ps1"

if (-not (Test-ScriptExists $runEntryPath)) {
    throw ("Required script not found: " + $runEntryPath)
}

$resolvedRunDate = Resolve-RunDate -RequestedRunDate $RunDate
$resolvedHandoffOutFile = Resolve-HandoffOutFile -RequestedPath $HandoffOutFile -ResolvedRunDate $resolvedRunDate -ResolvedSuiteId $SuiteId

Write-Section "DEV LOOP START"
Write-Host ("Suite : " + $SuiteId)
Write-Host ("RunDate : " + $resolvedRunDate)
Write-Host ("Repo : " + $repoRoot)

if (-not [string]::IsNullOrWhiteSpace($CurrentTask)) {
    Write-Host ("Task : " + $CurrentTask)
}

if (-not [string]::IsNullOrWhiteSpace($Notes)) {
    Write-Host ("Notes : " + $Notes)
}

try {
    Write-Section "STEP 1 - RUN ENTRY FLOW"

    if (-not [string]::IsNullOrWhiteSpace($CurrentTask) -and -not [string]::IsNullOrWhiteSpace($Notes)) {
        if ($SkipSummary -and $SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile -SkipSummary -SkipHandoff
        }
        elseif ($SkipSummary) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile -SkipSummary
        }
        elseif ($SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile -SkipHandoff
        }
        else {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($CurrentTask)) {
        if ($SkipSummary -and $SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -HandoffOutFile $resolvedHandoffOutFile -SkipSummary -SkipHandoff
        }
        elseif ($SkipSummary) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -HandoffOutFile $resolvedHandoffOutFile -SkipSummary
        }
        elseif ($SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -HandoffOutFile $resolvedHandoffOutFile -SkipHandoff
        }
        else {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -CurrentTask $CurrentTask -HandoffOutFile $resolvedHandoffOutFile
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Notes)) {
        if ($SkipSummary -and $SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile -SkipSummary -SkipHandoff
        }
        elseif ($SkipSummary) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile -SkipSummary
        }
        elseif ($SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile -SkipHandoff
        }
        else {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -Notes $Notes -HandoffOutFile $resolvedHandoffOutFile
        }
    }
    else {
        if ($SkipSummary -and $SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -HandoffOutFile $resolvedHandoffOutFile -SkipSummary -SkipHandoff
        }
        elseif ($SkipSummary) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -HandoffOutFile $resolvedHandoffOutFile -SkipSummary
        }
        elseif ($SkipHandoff) {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -HandoffOutFile $resolvedHandoffOutFile -SkipHandoff
        }
        else {
            & $runEntryPath -SuiteId $SuiteId -RunDate $resolvedRunDate -HandoffOutFile $resolvedHandoffOutFile
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw ("Script failed: " + $runEntryPath)
    }

    Write-Section "DEV LOOP RESULT"
    Write-Host "Main flow completed."

    if (-not $SkipHandoff) {
        Write-Host ("Handoff : " + $resolvedHandoffOutFile)
    }
    else {
        Write-Host "Handoff : skipped"
    }

    if ($SkipSummary) {
        Write-Host "Summary : skipped"
    }
    else {
        Write-Host "Summary : attempted"
    }

    # ===== Phase11-2: Operation Entry Guidance =====
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $summaryPath = Join-Path $repoRoot ("evals\" + $resolvedRunDate + "\summary.txt")

    Write-Host ""
    if ($SkipSummary) {
        Write-Host "Next:"
        Write-Host "1. Summary generation was skipped"
        Write-Host ("2. Run: ./scripts/summary-evals.ps1 -RunDate " + $resolvedRunDate)
        Write-Host "3. Review FAIL / REVIEW items first"
        Write-Host "4. Follow the NEXT STEP section in summary"
        Write-Host ""
        Write-Host "Rules:"
        Write-Host "  - compare = evidence"
        Write-Host "  - eval = interpretation"
        Write-Host "  - human = decision"
    }
    elseif (Test-Path $summaryPath) {
        Write-Host "Next:"
        Write-Host ("1. Open summary: " + $summaryPath)
        Write-Host "2. Review FAIL / REVIEW items first"
        Write-Host "3. Follow the NEXT STEP section in summary"
        Write-Host ""
        Write-Host "Rules:"
        Write-Host "  - compare = evidence"
        Write-Host "  - eval = interpretation"
        Write-Host "  - human = decision"
    }
    else {
        Write-Host "Next:"
        Write-Host ("1. Summary not found: " + $summaryPath)
        Write-Host ("2. Run: ./scripts/summary-evals.ps1 -RunDate " + $resolvedRunDate)
        Write-Host "3. Review FAIL / REVIEW items first"
        Write-Host "4. Follow the NEXT STEP section in summary"
        Write-Host ""
        Write-Host "Rules:"
        Write-Host "  - compare = evidence"
        Write-Host "  - eval = interpretation"
        Write-Host "  - human = decision"
    }

    Write-Section "DEV LOOP DONE"
}
catch {
    Write-Section "DEV LOOP ERROR"
    Write-Host $_.Exception.Message
    throw
}
