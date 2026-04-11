param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$MigName = "",

    [string]$RunDate = "",

    [string]$BaseName = "",

    [switch]$CompareToBaseline
)

if ([string]::IsNullOrWhiteSpace($BaseName)) {
    $BaseName = "base"
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$ErrorActionPreference = "Stop"

function Write-Utf8BomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
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

function Test-FileHasNonWhitespaceContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        return $false
    }

    $text = Get-Content -Path $Path -Raw -Encoding UTF8
    return -not [string]::IsNullOrWhiteSpace($text)
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

function Resolve-CaseMetaPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CasesRoot,

        [Parameter(Mandatory = $true)]
        [string]$CaseId
    )

    $metaPath = Join-Path (Join-Path $CasesRoot $CaseId) "meta.json"

    if (Test-Path $metaPath) {
        return $metaPath
    }

    return $null
}

function Resolve-BuildPromptOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TmpRoot,

        [Parameter(Mandatory = $true)]
        [string]$CaseId
    )

    $candidate1 = Join-Path $TmpRoot "${CaseId}_prompt.txt"
    $candidate2 = Join-Path $TmpRoot "${CaseId}.prompt.txt"
    $candidate3 = Join-Path $TmpRoot "prompt.txt"

    if (Test-Path $candidate1) { return $candidate1 }
    if (Test-Path $candidate2) { return $candidate2 }
    if (Test-Path $candidate3) { return $candidate3 }

    Write-Error "Generated prompt file not found after build-prompt."
    Write-Error "Checked:"
    Write-Error " - $candidate1"
    Write-Error " - $candidate2"
    Write-Error " - $candidate3"
    exit 1
}

function Get-FileFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $hash = Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop
        if ($null -ne $hash -and -not [string]::IsNullOrWhiteSpace($hash.Hash)) {
            return $hash.Hash.ToLower()
        }
    }
    catch {
        return $null
    }

    return $null
}

# -----------------------------
# Paths
# -----------------------------

$repoRoot        = Split-Path -Parent $PSScriptRoot
$casesRoot       = Join-Path $repoRoot "tests/cases"
$runsRoot        = Join-Path $repoRoot "runs"
$tmpRoot         = Join-Path $repoRoot "tmp"
$scriptsRoot     = $PSScriptRoot
$buildPromptPath = Join-Path $scriptsRoot "build-prompt.ps1"

if (!(Test-Path $buildPromptPath)) {
    Write-Error "build-prompt.ps1 not found: $buildPromptPath"
    exit 1
}

if (!(Test-Path $casesRoot)) {
    Write-Error "Cases directory not found: $casesRoot"
    exit 1
}

# -----------------------------
# Resolve case
# -----------------------------

$casePath = Resolve-CasePath -CasesRoot $casesRoot -CaseId $CaseId
$caseMetaPath = Resolve-CaseMetaPath -CasesRoot $casesRoot -CaseId $CaseId

Write-Host "Using case file: $casePath"
if ($caseMetaPath) {
    Write-Host "Using case meta: $caseMetaPath"
}

# -----------------------------
# Build prompt
# -----------------------------

if (!(Test-Path $tmpRoot)) {
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
}

$buildArgs = @{
    CaseId = $CaseId
}

if (-not [string]::IsNullOrWhiteSpace($MigName)) {
    $buildArgs["MigName"] = $MigName
}

if (-not [string]::IsNullOrWhiteSpace($BaseName)) {
    $buildArgs["BaseName"] = $BaseName
}

Write-Host ""
Write-Host "Building prompt..."
& $buildPromptPath @buildArgs

$generatedPromptPath = Resolve-BuildPromptOutputPath -TmpRoot $tmpRoot -CaseId $CaseId
$promptText = Read-TextFileSafe -Path $generatedPromptPath

# -----------------------------
# Prepare run folder
# -----------------------------

if ([string]::IsNullOrWhiteSpace($RunDate)) {
    $RunDate = (Get-Date).ToString("yyyy-MM-dd")
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runId = "RUN_${timestamp}_${CaseId}"

$runDir = Join-Path $runsRoot $runId
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$runPromptPath   = Join-Path $runDir "prompt.txt"
$runResponsePath = Join-Path $runDir "response.txt"
$runManifestPath = Join-Path $runDir "manifest.json"
$runCaseCopyPath = Join-Path $runDir "case.md"

Write-Utf8BomFile -Path $runPromptPath -Content $promptText
Write-Utf8BomFile -Path $runCaseCopyPath -Content (Read-TextFileSafe -Path $casePath)

$responseStatus = 'manual'

# response.txt は後続で人手貼り付け or 別工程で埋める前提の空ファイル
if (!(Test-Path $runResponsePath)) {
    Write-Utf8BomFile -Path $runResponsePath -Content ""
}

$promptFingerprint = Get-FileFingerprint -Path $runPromptPath
$responseFingerprint = Get-FileFingerprint -Path $runResponsePath

$manifest = [ordered]@{
    runId               = $runId
    runDate             = $RunDate
    executedAt          = (Get-Date).ToString("s")
    caseId              = $CaseId
    casePath            = $casePath
    caseMetaPath        = $caseMetaPath
    migName             = $(if ([string]::IsNullOrWhiteSpace($MigName)) { "NO-MIG" } else { $MigName })
    baseName            = $BaseName
    generatedPromptPath = $generatedPromptPath
    runPromptPath       = $runPromptPath
    runResponsePath     = $runResponsePath
    responseStatus      = $responseStatus
    fingerprints = [ordered]@{
        prompt   = $promptFingerprint
        response = $responseFingerprint
    }
}

$manifestJson = $manifest | ConvertTo-Json -Depth 10
Write-Utf8BomFile -Path $runManifestPath -Content $manifestJson

# meta.json があれば run 配下にもコピー
if ($caseMetaPath) {
    $runMetaCopyPath = Join-Path $runDir "meta.json"
    Write-Utf8BomFile -Path $runMetaCopyPath -Content (Read-TextFileSafe -Path $caseMetaPath)
}

# -----------------------------
# Optional compare to baseline
# -----------------------------

if ($CompareToBaseline) {
    if (-not (Test-FileHasNonWhitespaceContent -Path $runResponsePath)) {
        Write-Warning "response.txt is empty. Skipping baseline comparison and evaluation."
    }
    else {
        $compareScript = Join-Path $PSScriptRoot "compare-run.ps1"
        $evalScript = Join-Path $PSScriptRoot "eval-run.ps1"
        $baselinePath = Join-Path (Join-Path $repoRoot "tests/baselines") ("{0}.json" -f $CaseId)

        $compareSucceeded = $false

        if (!(Test-Path $compareScript)) {
            Write-Warning "compare-run.ps1 not found. Skipping baseline comparison."
        }
        elseif (!(Test-Path $baselinePath)) {
            Write-Warning ("Baseline file not found for case: " + $CaseId + ". Skipping baseline comparison.")
        }
        else {
            Write-Host ""
            Write-Host "===== BASELINE COMPARE START ====="

            try {
                & $compareScript -RunId $runId
                $compareSucceeded = $true
            }
            catch {
                Write-Warning ("Baseline comparison failed: " + $_.Exception.Message)
            }

            Write-Host "===== BASELINE COMPARE END ====="
            Write-Host ""
        }

        if ($compareSucceeded) {
            if (!(Test-Path $evalScript)) {
                Write-Warning "eval-run.ps1 not found. Skipping evaluation."
            }
            else {
                Write-Host ""
                Write-Host "===== EVALUATION START ====="

                try {
                    & $evalScript -RunId $runId
                }
                catch {
                    Write-Warning ("Evaluation failed: " + $_.Exception.Message)
                }

                Write-Host "===== EVALUATION END ====="
                Write-Host ""
            }
        }
    }
}

# -----------------------------
# Output
# -----------------------------

Write-Host ""
Write-Host "Run created: $runId"
Write-Host "- $runPromptPath"
Write-Host "- $runResponsePath"
Write-Host "- $runManifestPath"

Write-Host ""
Write-Host "===== BEGIN GENERATED PROMPT ====="
Write-Host $promptText
Write-Host "===== END GENERATED PROMPT ====="

Write-Output ("RUN_RESULT: " + $runId)
