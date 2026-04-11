param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$MigName = "",

    [string]$BaseName = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$ErrorActionPreference = "Stop"

function Write-Utf8BomFile {
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

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Read-TextFileSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        throw "File not found: $Path"
    }

    return Get-Content -Path $Path -Raw -Encoding UTF8
}

function Resolve-CasePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CasesRoot,

        [Parameter(Mandatory = $true)]
        [string]$CaseId
    )

    $caseDirPath = Join-Path $CasesRoot $CaseId
    $casePathNew = Join-Path $caseDirPath "case.md"
    $casePathOld = Join-Path $CasesRoot "$CaseId.md"

    if (Test-Path $casePathNew) {
        return $casePathNew
    }

    if (Test-Path $casePathOld) {
        return $casePathOld
    }

    Write-Error "Case not found: $CaseId"
    Write-Error "Checked:"
    Write-Error " - $casePathNew"
    Write-Error " - $casePathOld"
    exit 1
}

function Get-LatestFileByPrefix {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dir,

        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    if (!(Test-Path $Dir)) {
        return $null
    }

    $files = Get-ChildItem -Path $Dir -File | Where-Object {
        $_.BaseName -like "$Prefix*"
    } | Sort-Object Name

    if ($files.Count -eq 0) {
        return $null
    }

    return $files[-1].FullName
}

function Resolve-BasePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseRoot,

        [string]$BaseName
    )

    if (-not [string]::IsNullOrWhiteSpace($BaseName)) {
        $candidateMd = Join-Path $BaseRoot "$BaseName.md"
        $candidateTxt = Join-Path $BaseRoot "$BaseName.txt"

        if (Test-Path $candidateMd) { return $candidateMd }
        if (Test-Path $candidateTxt) { return $candidateTxt }

        Write-Error "Base not found: $BaseName"
        Write-Error "Checked:"
        Write-Error " - $candidateMd"
        Write-Error " - $candidateTxt"
        exit 1
    }

    $latest = Get-LatestFileByPrefix -Dir $BaseRoot -Prefix "BASE"
    if ($null -eq $latest) {
        Write-Error "No base file found under: $BaseRoot"
        exit 1
    }

    return $latest
}

function Resolve-SpecBasePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SpecRoot
    )

    $candidate1 = Join-Path $SpecRoot "spec_base.md"
    $candidate2 = Join-Path $SpecRoot "SPEC_BASE.md"
    $candidate3 = Join-Path $SpecRoot "spec_base.txt"
    $candidate4 = Join-Path $SpecRoot "SPEC_BASE.txt"

    foreach ($p in @($candidate1, $candidate2, $candidate3, $candidate4)) {
        if (Test-Path $p) {
            return $p
        }
    }

    return $null
}

function Resolve-SpecPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SpecRoot
    )

    $candidateNames = @(
        "spec.md",
        "SPEC.md",
        "spec.txt",
        "SPEC.txt",
        "spec_summary.md"
    )

    foreach ($name in $candidateNames) {
        $p = Join-Path $SpecRoot $name
        if (Test-Path $p) {
            return $p
        }
    }

    $files = Get-ChildItem -Path $SpecRoot -File | Where-Object {
        $_.Name -notmatch 'spec_base'
    } | Sort-Object Name

    if ($files.Count -gt 0) {
        return $files[0].FullName
    }

    return $null
}

function Resolve-MigPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MigRoot,

        [string]$MigName
    )

    if ([string]::IsNullOrWhiteSpace($MigName)) {
        return $null
    }

    $candidateMd = Join-Path $MigRoot "$MigName.md"
    $candidateTxt = Join-Path $MigRoot "$MigName.txt"

    if (Test-Path $candidateMd) { return $candidateMd }
    if (Test-Path $candidateTxt) { return $candidateTxt }

    Write-Error "Mig not found: $MigName"
    Write-Error "Checked:"
    Write-Error " - $candidateMd"
    Write-Error " - $candidateTxt"
    exit 1
}

# -----------------------------
# Paths
# -----------------------------

$repoRoot = Split-Path -Parent $PSScriptRoot

$promptsRoot = Join-Path $repoRoot "prompts"
$baseRoot    = Join-Path $promptsRoot "base"
$specRoot    = Join-Path $promptsRoot "spec"
$migRoot     = Join-Path $promptsRoot "mig"

$casesRoot   = Join-Path $repoRoot "tests/cases"
$tmpRoot     = Join-Path $repoRoot "tmp"

if (!(Test-Path $promptsRoot)) {
    Write-Error "prompts directory not found: $promptsRoot"
    exit 1
}

if (!(Test-Path $casesRoot)) {
    Write-Error "cases directory not found: $casesRoot"
    exit 1
}

if (!(Test-Path $tmpRoot)) {
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
}

# -----------------------------
# Resolve files
# -----------------------------

$basePath = Resolve-BasePath -BaseRoot $baseRoot -BaseName $BaseName
$specBasePath = Resolve-SpecBasePath -SpecRoot $specRoot
$specPath = Resolve-SpecPath -SpecRoot $specRoot
$migPath = Resolve-MigPath -MigRoot $migRoot -MigName $MigName
$casePath = Resolve-CasePath -CasesRoot $casesRoot -CaseId $CaseId

$baseText = Read-TextFileSafe -Path $basePath

$specBaseText = ""
if ($specBasePath) {
    $specBaseText = Read-TextFileSafe -Path $specBasePath
}

$specText = ""
if ($specPath) {
    $specText = Read-TextFileSafe -Path $specPath
}

$migText = ""
if ($migPath) {
    $migText = Read-TextFileSafe -Path $migPath
}

$caseText = Read-TextFileSafe -Path $casePath

# -----------------------------
# Compose prompt
# -----------------------------

$sections = @()

if (-not [string]::IsNullOrWhiteSpace($baseText)) {
    $sections += $baseText.Trim()
}

if (-not [string]::IsNullOrWhiteSpace($specBaseText)) {
    $sections += $specBaseText.Trim()
}

if (-not [string]::IsNullOrWhiteSpace($specText)) {
    $sections += $specText.Trim()
}

if (-not [string]::IsNullOrWhiteSpace($migText)) {
    $sections += $migText.Trim()
}

if (-not [string]::IsNullOrWhiteSpace($caseText)) {
    $sections += $caseText.Trim()
}

$promptText = ($sections -join ([Environment]::NewLine + [Environment]::NewLine)).Trim() + [Environment]::NewLine

# -----------------------------
# Output
# -----------------------------

$outPath = Join-Path $tmpRoot "${CaseId}_prompt.txt"
Write-Utf8BomFile -Path $outPath -Content $promptText

$baseDisplay = [System.IO.Path]::GetFileNameWithoutExtension($basePath)
$migDisplay = if ($migPath) {
    [System.IO.Path]::GetFileNameWithoutExtension($migPath)
}
else {
    "NO-MIG"
}

Write-Host "Generated prompt file: $outPath"
Write-Host "Base: $baseDisplay"
Write-Host "Mig : $migDisplay"
