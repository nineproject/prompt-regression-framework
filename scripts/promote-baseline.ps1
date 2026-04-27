param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$Reason = "",

    [Parameter(Mandatory = $false)]
    [string]$ApprovedBy = "unknown",

    [Parameter(Mandatory = $false)]
    [string]$Notes = "",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        throw "JSON file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "JSON file is empty: $Path"
    }

    return $raw | ConvertFrom-Json
}

function Get-RunPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$TargetRunId
    )

    $runDir = Join-Path $RepoRoot ("runs/" + $TargetRunId)

    if (!(Test-Path $runDir)) {
        throw "Run directory not found: $runDir"
    }

    return @{
        RunDir = $runDir
        ManifestPath = Join-Path $runDir "manifest.json"
        ResponsePath = Join-Path $runDir "response.txt"
        MetaPath = Join-Path $runDir "meta.json"
    }
}

$repoRoot = Get-RepoRoot
$runPaths = Get-RunPaths -RepoRoot $repoRoot -TargetRunId $RunId

$manifest = Read-JsonFile -Path $runPaths.ManifestPath

if ([string]::IsNullOrWhiteSpace($manifest.caseId)) {
    throw "caseId is missing in manifest: $($runPaths.ManifestPath)"
}

$caseId = $manifest.caseId

$baselineDir = Join-Path $repoRoot "tests/baselines"
if (!(Test-Path $baselineDir)) {
    New-Item -ItemType Directory -Path $baselineDir | Out-Null
}

$baselinePath = Join-Path $baselineDir ("{0}.json" -f $caseId)

$previousBaselineRunId = $null
$baselineExists = Test-Path $baselinePath
$promotionMode = "INITIAL_CREATE"

if ($baselineExists) {
    $existing = Read-JsonFile -Path $baselinePath
    $previousBaselineRunId = [string]$existing.baselineRunId

    if ([string]::IsNullOrWhiteSpace($previousBaselineRunId)) {
        $promotionMode = "INITIAL_CREATE"
    }
    else {
        $promotionMode = "UPDATE"
    }

    if (($previousBaselineRunId -ne $RunId) -and (-not [string]::IsNullOrWhiteSpace($previousBaselineRunId)) -and (-not $Force)) {
        Write-Host ""
        Write-Host "Baseline already exists:"
        Write-Host ("Case ID          : {0}" -f $caseId)
        Write-Host ("Current Baseline : {0}" -f $previousBaselineRunId)
        Write-Host ("New Candidate    : {0}" -f $RunId)
        Write-Host ("Mode             : UPDATE")
        Write-Host ""
        throw "Use -Force to overwrite the existing baseline."
    }
}

$storedPreviousBaselineRunId = $null
if (-not [string]::IsNullOrWhiteSpace($previousBaselineRunId)) {
    $storedPreviousBaselineRunId = $previousBaselineRunId
}

$approvedReason = $Reason

if ([string]::IsNullOrWhiteSpace($approvedReason)) {
    $approvedReason = "unspecified"
}

$baseline = [ordered]@{
    caseId                = $caseId
    baselineRunId         = $RunId
    previousBaselineRunId = $storedPreviousBaselineRunId
    approvedAt            = (Get-Date).ToString("s")
    approvedReason        = $approvedReason
    approvedBy            = $ApprovedBy
    status                = "active"
    notes                 = $Notes
}

$baselineJson = $baseline | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $baselinePath -Value $baselineJson -Encoding UTF8

Write-Host ""
Write-Host "===== PROMOTE BASELINE ====="
Write-Host ("Mode             : {0}" -f $promotionMode)
Write-Host ("Case ID          : {0}" -f $caseId)

if ($promotionMode -eq "INITIAL_CREATE") {
    Write-Host ("Source Run       : {0}" -f $RunId)
    Write-Host ("Previous Baseline: (none)")
    Write-Host ("Result           : baseline established")
}
else {
    Write-Host ("Previous Baseline: {0}" -f $previousBaselineRunId)
    Write-Host ("New Baseline     : {0}" -f $RunId)
    Write-Host ("Result           : baseline updated")
}

Write-Host ("Approved By      : {0}" -f $ApprovedBy)
Write-Host ("Saved            : {0}" -f $baselinePath)
Write-Host ""
