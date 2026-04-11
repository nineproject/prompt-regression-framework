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
    param([Parameter(Mandatory = $true)][string]$Title)

    Write-Host ""
    Write-Host ("===== " + $Title + " =====")
}

function Test-ScriptExists {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.File]::Exists($Path)
}

function Resolve-RunDate {
    param([string]$RequestedRunDate)

    if (-not [string]::IsNullOrWhiteSpace($RequestedRunDate)) {
        return $RequestedRunDate.Trim()
    }

    return (Get-Date).ToString("yyyy-MM-dd")
}

function Resolve-HandoffOutFile {
    param(
        [string]$RequestedPath,
        [string]$ResolvedRunDate,
        [string]$SuiteId
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return $RequestedPath.Trim()
    }

    return ("tmp/handoff-" + $ResolvedRunDate + "-" + $SuiteId + ".txt")
}

$repoRoot = Get-RepoRoot

$runRegressionPath   = Join-Path $PSScriptRoot "run-regression.ps1"
$summaryEvalsPath    = Join-Path $PSScriptRoot "summary-evals.ps1"
$generateHandoffPath = Join-Path $PSScriptRoot "generate-handoff-prompt.ps1"

if (-not (Test-ScriptExists $runRegressionPath)) {
    throw ("Required script not found: " + $runRegressionPath)
}

if (-not $SkipSummary -and -not (Test-ScriptExists $summaryEvalsPath)) {
    throw ("Required script not found: " + $summaryEvalsPath)
}

if (-not $SkipHandoff -and -not (Test-ScriptExists $generateHandoffPath)) {
    throw ("Required script not found: " + $generateHandoffPath)
}

$resolvedRunDate = Resolve-RunDate -RequestedRunDate $RunDate
$resolvedHandoffOutFile = Resolve-HandoffOutFile -RequestedPath $HandoffOutFile -ResolvedRunDate $resolvedRunDate -SuiteId $SuiteId

Write-Section "REGRESSION ENTRY START"
Write-Host ("Suite   : " + $SuiteId)
Write-Host ("RunDate : " + $resolvedRunDate)
Write-Host ("Repo    : " + $repoRoot)

if (-not [string]::IsNullOrWhiteSpace($CurrentTask)) {
    Write-Host ("Task    : " + $CurrentTask)
}

try {
    Write-Section "STEP 1 - RUN REGRESSION"

    & $runRegressionPath -SuiteId $SuiteId

    if ($LASTEXITCODE -ne 0) {
        throw ("Script failed: " + $runRegressionPath)
    }

    if (-not $SkipSummary) {
        Write-Section "STEP 2 - SUMMARY EVALS"

        try {
            & $summaryEvalsPath -RunDate $resolvedRunDate

            if ($LASTEXITCODE -ne 0) {
                Write-Warning ("summary-evals returned non-zero exit code: " + $LASTEXITCODE)
            }
        }
        catch {
            Write-Warning ("summary-evals failed: " + $_.Exception.Message)
        }
    }
    else {
        Write-Section "STEP 2 - SUMMARY EVALS"
        Write-Host "Skipped by -SkipSummary"
    }

    if (-not $SkipHandoff) {
        Write-Section "STEP 3 - GENERATE HANDOFF"

        if (-not [string]::IsNullOrWhiteSpace($CurrentTask) -and -not [string]::IsNullOrWhiteSpace($Notes)) {
            & $generateHandoffPath -CurrentTask $CurrentTask -Notes $Notes -OutFile $resolvedHandoffOutFile
        }
        elseif (-not [string]::IsNullOrWhiteSpace($CurrentTask)) {
            & $generateHandoffPath -CurrentTask $CurrentTask -OutFile $resolvedHandoffOutFile
        }
        elseif (-not [string]::IsNullOrWhiteSpace($Notes)) {
            & $generateHandoffPath -Notes $Notes -OutFile $resolvedHandoffOutFile
        }
        else {
            & $generateHandoffPath -OutFile $resolvedHandoffOutFile
        }

        if ($LASTEXITCODE -ne 0) {
            throw ("Script failed: " + $generateHandoffPath)
        }

        Write-Host ("Handoff : " + $resolvedHandoffOutFile)
    }
    else {
        Write-Section "STEP 3 - GENERATE HANDOFF"
        Write-Host "Skipped by -SkipHandoff"
    }

    Write-Section "REGRESSION ENTRY DONE"
}
catch {
    Write-Section "REGRESSION ENTRY ERROR"
    Write-Host $_.Exception.Message
    throw
}
