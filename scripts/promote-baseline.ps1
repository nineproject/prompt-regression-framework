param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

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

if ($baselineExists) {
    $existing = Read-JsonFile -Path $baselinePath
    $previousBaselineRunId = $existing.baselineRunId

    if (($previousBaselineRunId -ne $RunId) -and (-not $Force)) {
        Write-Host ""
        Write-Host "Baseline already exists:"
        Write-Host ("Case ID          : {0}" -f $caseId)
        Write-Host ("Current Baseline : {0}" -f $previousBaselineRunId)
        Write-Host ("New Candidate    : {0}" -f $RunId)
        Write-Host ""
        throw "Use -Force to overwrite the existing baseline."
    }
}

$baseline = [ordered]@{
    caseId = $caseId
    baselineRunId = $RunId
    approvedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    approvedBy = $ApprovedBy
    status = "active"
    notes = $Notes
}

$baselineJson = $baseline | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $baselinePath -Value $baselineJson -Encoding UTF8

Write-Host ""
Write-Host "===== BASELINE PROMOTED ====="
Write-Host ("Case ID          : {0}" -f $caseId)
Write-Host ("Baseline Run ID  : {0}" -f $RunId)

if ($previousBaselineRunId) {
    Write-Host ("Previous Baseline: {0}" -f $previousBaselineRunId)
}
else {
    Write-Host "Previous Baseline: (none)"
}

Write-Host ("Approved By      : {0}" -f $ApprovedBy)
Write-Host ("Saved            : {0}" -f $baselinePath)
Write-Host ""
