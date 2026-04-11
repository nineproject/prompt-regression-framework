param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$Title = "",

    [string]$Purpose = "",

    [string]$Suite = "",

    [string[]]$Tags = @()
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$ErrorActionPreference = "Stop"

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and !(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # UTF-8 BOM付き
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Normalize-Tags {
    param(
        [string[]]$InputTags
    )

    $normalized = @()

    foreach ($tag in $InputTags) {

        if ($null -eq $tag) { continue }

        $parts = $tag -split ","

        foreach ($part in $parts) {

            $trimmed = $part.Trim()

            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

            $normalized += $trimmed
        }
    }

    $seen = @{}
    $result = @()

    foreach ($t in $normalized) {

        if (-not $seen.ContainsKey($t)) {

            $seen[$t] = $true
            $result += $t
        }
    }

    return $result
}

function Update-SuiteFile {
    param(
        [string]$SuiteName,
        [string]$CaseId,
        [string]$SuitesRoot
    )

    $suiteFileName = if ($SuiteName.ToLower().EndsWith(".txt")) {
        $SuiteName
    }
    else {
        "$SuiteName.txt"
    }

    $suitePath = Join-Path $SuitesRoot $suiteFileName

    if (!(Test-Path $SuitesRoot)) {
        New-Item -ItemType Directory -Path $SuitesRoot -Force | Out-Null
    }

    $existingLines = @()

    if (Test-Path $suitePath) {
        $existingLines = Get-Content -Path $suitePath -Encoding UTF8
    }

    $trimmedLines = @(
        $existingLines |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
    )

    if ($trimmedLines -contains $CaseId) {

        return @{
            Updated = $false
            Path = $suitePath
            Message = "Case already exists in suite"
        }
    }

    $newContent = ""

    if ($existingLines.Count -gt 0) {

        $joined = ($existingLines -join [Environment]::NewLine).TrimEnd("`r","`n")

        $newContent =
            $joined +
            [Environment]::NewLine +
            $CaseId +
            [Environment]::NewLine
    }
    else {

        $newContent =
            $CaseId +
            [Environment]::NewLine
    }

    Write-Utf8File -Path $suitePath -Content $newContent

    return @{
        Updated = $true
        Path = $suitePath
        Message = "Suite updated"
    }
}

# -----------------------------
# CaseId validation
# -----------------------------

if ($CaseId -notmatch '^TC-\d{4}$') {

    Write-Error "Invalid CaseId format. Expected: TC-0001"
    exit 1
}

# -----------------------------
# Paths
# -----------------------------

$repoRoot = Split-Path -Parent $PSScriptRoot

$casesRoot = Join-Path $repoRoot "tests/cases"
$suitesRoot = Join-Path $repoRoot "tests/suites"

$caseDir = Join-Path $casesRoot $CaseId

$caseMdPath = Join-Path $caseDir "case.md"
$metaJsonPath = Join-Path $caseDir "meta.json"

# -----------------------------
# Duplicate check
# -----------------------------

if (Test-Path $caseDir) {

    Write-Error "Case already exists: $CaseId"
    exit 1
}

# -----------------------------
# Prepare values
# -----------------------------

$normalizedTags = Normalize-Tags -InputTags $Tags

$createdAt = (Get-Date).ToString("yyyy-MM-dd")

if ([string]::IsNullOrWhiteSpace($Title)) {

    $Title = $CaseId
}

# -----------------------------
# case.md template
# -----------------------------

$caseMd = @"
# $CaseId

## Title
$Title

## Purpose
$Purpose

## Input
ここにテストケース本文を書く。
ユーザー入力、条件、期待観点などを記述する。
"@

# -----------------------------
# meta.json
# -----------------------------

$metaObject = [ordered]@{
    caseId = $CaseId
    title = $Title
    status = "active"
    tags = $normalizedTags
    purpose = $Purpose
    createdAt = $createdAt
}

$metaJson =
    $metaObject |
    ConvertTo-Json -Depth 5

# -----------------------------
# Create case
# -----------------------------

try {

    New-Item -ItemType Directory -Path $caseDir -Force | Out-Null

    Write-Utf8File -Path $caseMdPath -Content $caseMd

    Write-Utf8File -Path $metaJsonPath -Content $metaJson

    Write-Host ""
    Write-Host "Created case: $CaseId"
    Write-Host "- $caseMdPath"
    Write-Host "- $metaJsonPath"

    if (-not [string]::IsNullOrWhiteSpace($Suite)) {

        try {

            $suiteResult =
                Update-SuiteFile `
                -SuiteName $Suite `
                -CaseId $CaseId `
                -SuitesRoot $suitesRoot

            if ($suiteResult.Updated) {

                Write-Host ""
                Write-Host "Updated suite:"
                Write-Host "- $($suiteResult.Path)"
            }
            else {

                Write-Warning "Suite not updated: $($suiteResult.Message)"
            }
        }
        catch {

            Write-Warning "Case created but suite update failed: $($_.Exception.Message)"
        }
    }

}
catch {

    Write-Error "Failed to create case. $($_.Exception.Message)"
    exit 1
}
