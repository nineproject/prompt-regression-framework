param(
    [string]$RunDate = (Get-Date).ToString("yyyy-MM-dd")
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8BomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return ($raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-StringOrDefault {
    param(
        $Value,
        [string]$Default = ""
    )

    if ($null -eq $Value) {
        return $Default
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Default
    }

    return $text
}

function Get-Array {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @($Value)
}

function Get-Count {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return 0
    }

    return @($Value).Count
}

function Get-PropertyValueOrDefault {
    param(
        $Object,
        [string]$PropertyName,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $prop = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $prop) {
        return $Default
    }

    if ($null -eq $prop.Value) {
        return $Default
    }

    return $prop.Value
}

function Get-ResponseState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResponsePath
    )

    if (-not (Test-Path $ResponsePath)) {
        return "missing"
    }

    try {
        $raw = Get-Content -LiteralPath $ResponsePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return "empty"
        }
        return "filled"
    }
    catch {
        return "unreadable"
    }
}

function Get-RunDateFromManifest {
    param(
        $Manifest
    )

    if ($null -eq $Manifest) {
        return ""
    }

    $runDate = Get-StringOrDefault (Get-PropertyValueOrDefault -Object $Manifest -PropertyName "runDate" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($runDate)) {
        return $runDate
    }

    $executedAt = Get-StringOrDefault (Get-PropertyValueOrDefault -Object $Manifest -PropertyName "executedAt" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($executedAt) -and $executedAt.Length -ge 10) {
        return $executedAt.Substring(0, 10)
    }

    return ""
}

function Get-ExecutedAtSortValue {
    param(
        $Manifest,
        [string]$RunId
    )

    $executedAt = Get-StringOrDefault (Get-PropertyValueOrDefault -Object $Manifest -PropertyName "executedAt" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($executedAt)) {
        try {
            return [DateTime]::Parse($executedAt)
        }
        catch {
        }
    }

    if ($RunId -match '^RUN_(\d{8})_(\d{6})_') {
        $stamp = "$($matches[1])$($matches[2])"
        try {
            return [DateTime]::ParseExact($stamp, "yyyyMMddHHmmss", $null)
        }
        catch {
        }
    }

    return [DateTime]::MinValue
}

function Get-ActionSummary {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    switch ($Item.Status) {
        "FAIL" {
            return @(
                "1. 必須情報の欠落を確認"
                "2. 出力形式を確認"
                "3. compare evidence を確認"
                "4. eval judgment を確認"
            )
        }
        "REVIEW" {
            return @(
                "1. 差分が意図した変更か確認"
                "2. compare evidence を確認"
                "3. eval judgment を確認"
                "4. promote の可否を判断"
            )
        }
        "PASS" {
            return @(
                "1. 結果を確認"
                "2. 問題なければ promote を検討"
            )
        }
        "SKIPPED_OR_PENDING" {
            if ($Item.ResponseState -eq "missing" -or $Item.ResponseState -eq "empty") {
                return @(
                    "1. response.txt を入力"
                    "2. compare を実行"
                    "3. eval を実行"
                )
            }

            if ($Item.HasCompare -and -not $Item.HasEval) {
                return @(
                    "1. eval を実行"
                    "2. 結果を確認"
                )
            }

            return @(
                "1. 状態を確認"
                "2. 必要な処理を再実行"
            )
        }
        default {
            return @(
                "1. 状態を確認"
            )
        }
    }
}

function Get-SummaryLine {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $parts = @()

    if (($Item.ResponseState -eq "missing" -or $Item.ResponseState -eq "empty") -and -not $Item.InitialBaselineReview) {
        $parts += "response 未入力"
    }

    if ($Item.Status -eq "FAIL") {
        if ($Item.PossibleOmissionDetected) {
            $parts += "要約の欠落あり"
        }
        if (-not $Item.FormatMatchKnown -or -not $Item.FormatMatch) {
            $parts += "形式差異あり"
        }
        if ($Item.NormalizedDiffDetected) {
            $parts += "正規化差分あり"
        }
    }
    elseif ($Item.Status -eq "REVIEW") {
        if ($Item.InitialBaselineReview) {
            $parts += "baseline 未作成のため差分比較は未実施"
            $parts += "初回レビュー候補"
        }
        else {
            if ($Item.PossibleOmissionDetected) {
                $parts += "欠落疑いあり"
            }
            if ($Item.NormalizedDiffDetected) {
                $parts += "差分あり"
            }
            if ($Item.FormatMatchKnown -and -not $Item.FormatMatch) {
                $parts += "形式差異あり"
            }
        }
    }
    elseif ($Item.Status -eq "PASS") {
        $parts += "大きな問題なし"
    }
    elseif ($Item.Status -eq "SKIPPED_OR_PENDING") {
        if ($Item.HasCompare -and -not $Item.HasEval) {
            $parts += "compare 済み / eval 未実行"
        }
        elseif (-not $Item.HasCompare -and -not $Item.HasEval) {
            $parts += "compare / eval 未実行"
        }
        else {
            $parts += "処理待ち"
        }
    }

    if ((Get-Count $parts) -eq 0) {
        return "状態確認"
    }

    return ($parts -join " + ")
}

function Get-NextStepLines {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $runId = $Item.RunId
    $runDir = $Item.RunDir

    $lines = @()

    if ($Item.ResponseState -eq "missing" -or $Item.ResponseState -eq "empty") {
        $lines += "1. Fill response:"
        $lines += "   type `"$runDir\response.txt`""
        $lines += ""
        $lines += "2. Run compare:"
        $lines += "   ./scripts/compare-run.ps1 -RunId $runId"
        $lines += ""
        $lines += "3. Run eval:"
        $lines += "   ./scripts/eval-run.ps1 -RunId $runId"
        return @($lines)
    }

    if (-not $Item.HasCompare) {
        $lines += "1. Run compare:"
        $lines += "   ./scripts/compare-run.ps1 -RunId $runId"
        $lines += ""
        $lines += "2. Run eval:"
        $lines += "   ./scripts/eval-run.ps1 -RunId $runId"
        return @($lines)
    }

    if ($Item.HasCompare -and -not $Item.HasEval) {
        $lines += "1. Run eval:"
        $lines += "   ./scripts/eval-run.ps1 -RunId $runId"
        return @($lines)
    }

    if ($Item.Status -eq "FAIL" -or $Item.Status -eq "REVIEW") {
        $lines += "1. Inspect compare:"
        $lines += "   type `"$runDir\compare.json`""
        $lines += ""
        $lines += "2. Inspect eval:"
        $lines += "   type `"$runDir\eval.json`""
        $lines += ""
        $lines += "3. Human decision:"
        $lines += "   - keep as review/fail and revise prompt"
        $lines += "   - or promote if change is intentional"
        return @($lines)
    }

    if ($Item.Status -eq "PASS") {
        $lines += "1. Inspect eval:"
        $lines += "   type `"$runDir\eval.json`""
        $lines += ""
        $lines += "2. If acceptable, promote baseline:"
        $lines += "   ./scripts/promote-baseline.ps1 -RunId $runId"
        return @($lines)
    }

    $lines += "1. Check run state"
    return @($lines)
}

function New-RunSummaryItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunDir
    )

    $manifestPath = Join-Path $RunDir "manifest.json"
    $comparePath  = Join-Path $RunDir "compare.json"
    $evalPath     = Join-Path $RunDir "eval.json"
    $responsePath = Join-Path $RunDir "response.txt"

    $manifest = Read-JsonFile -Path $manifestPath
    if ($null -eq $manifest) {
        return $null
    }

    $runId = Split-Path $RunDir -Leaf
    $caseId = Get-StringOrDefault (Get-PropertyValueOrDefault -Object $manifest -PropertyName "caseId" -Default "(unknown)") "(unknown)"
    $runDate = Get-RunDateFromManifest -Manifest $manifest

    $responseState = Get-ResponseState -ResponsePath $responsePath
    $compare = Read-JsonFile -Path $comparePath
    $eval = Read-JsonFile -Path $evalPath

    $hasCompare = ($null -ne $compare)
    $hasEval = ($null -ne $eval)

    $status = "SKIPPED_OR_PENDING"
    $severity = "N/A"
    $reasons = @()
    $reviewFocus = @()

    if ($hasEval) {
        $status = Get-StringOrDefault (Get-PropertyValueOrDefault -Object $eval -PropertyName "recommendedVerdict" -Default "OTHER") "OTHER"

        $evalEvidence = Get-PropertyValueOrDefault -Object $eval -PropertyName "evidence" -Default $null
        $evidenceSeverity = Get-PropertyValueOrDefault -Object $evalEvidence -PropertyName "severityHint" -Default "N/A"
        $severity = Get-StringOrDefault $evidenceSeverity "N/A"

        $reasons = @(Get-Array (Get-PropertyValueOrDefault -Object $eval -PropertyName "reasons" -Default @()))
        $reviewFocus = @(Get-Array (Get-PropertyValueOrDefault -Object $eval -PropertyName "reviewFocus" -Default @()))
    }
    elseif ($responseState -eq "missing" -or $responseState -eq "empty") {
        $status = "SKIPPED_OR_PENDING"
        $severity = "N/A"
        $reasons = @("response.txt is empty or pending")
    }
    elseif ($hasCompare -and -not $hasEval) {
        $status = "SKIPPED_OR_PENDING"
        $compareSeverity = Get-PropertyValueOrDefault -Object $compare -PropertyName "severityHint" -Default "N/A"
        $severity = Get-StringOrDefault $compareSeverity "N/A"
        $reasons = @("compare completed but eval.json not found")
    }
    else {
        $status = "SKIPPED_OR_PENDING"
        $severity = "N/A"
        $reasons = @("compare has not been executed", "eval has not been executed")
    }

    $formatMatchKnown = $false
    $formatMatch = $true
    $normalizedDiffDetected = $false
    $rawDiffDetected = $false
    $possibleOmissionDetected = $false

    if ($hasCompare) {
        $compareFormatMatch = Get-PropertyValueOrDefault -Object $compare -PropertyName "formatMatch" -Default $null
        $compareNormalizedDiff = Get-PropertyValueOrDefault -Object $compare -PropertyName "normalizedDiffDetected" -Default $false
        $compareRawDiff = Get-PropertyValueOrDefault -Object $compare -PropertyName "rawDiffDetected" -Default $false
        $compareOmission = Get-PropertyValueOrDefault -Object $compare -PropertyName "possibleOmissionDetected" -Default $false

        if ($null -ne $compareFormatMatch) {
            $formatMatchKnown = $true
            $formatMatch = [bool]$compareFormatMatch
        }

        $normalizedDiffDetected = [bool]$compareNormalizedDiff
        $rawDiffDetected = [bool]$compareRawDiff
        $possibleOmissionDetected = [bool]$compareOmission
    }
    elseif ($hasEval) {
        $evalEvidence = Get-PropertyValueOrDefault -Object $eval -PropertyName "evidence" -Default $null

        $evalFormatMatch = Get-PropertyValueOrDefault -Object $evalEvidence -PropertyName "formatMatch" -Default $null
        $evalNormalizedDiff = Get-PropertyValueOrDefault -Object $evalEvidence -PropertyName "normalizedDiffDetected" -Default $false
        $evalRawDiff = Get-PropertyValueOrDefault -Object $evalEvidence -PropertyName "rawDiffDetected" -Default $false
        $evalOmission = Get-PropertyValueOrDefault -Object $evalEvidence -PropertyName "possibleOmissionDetected" -Default $false

        if ($null -ne $evalFormatMatch) {
            $formatMatchKnown = $true
            $formatMatch = [bool]$evalFormatMatch
        }

        $normalizedDiffDetected = [bool]$evalNormalizedDiff
        $rawDiffDetected = [bool]$evalRawDiff
        $possibleOmissionDetected = [bool]$evalOmission
    }

    $executedAtSort = Get-ExecutedAtSortValue -Manifest $manifest -RunId $runId

    $isInitialBaselineReview = $false

    if ($hasEval -and $status -eq "REVIEW") {
        foreach ($reason in @($reasons)) {
            $text = [string]$reason
            if ($text -like "comparison not available: BASELINE_MISSING*") {
                $isInitialBaselineReview = $true
                break
            }
        }
    }

    return [PSCustomObject]@{
        CaseId                   = $caseId
        RunId                    = $runId
        RunDir                   = $RunDir
        RunDate                  = $runDate
        Status                   = $status
        Severity                 = $severity
        Reasons                  = @($reasons)
        ReviewFocus              = @($reviewFocus)
        HasCompare               = $hasCompare
        HasEval                  = $hasEval
        ResponseState            = $responseState
        FormatMatchKnown         = $formatMatchKnown
        FormatMatch              = $formatMatch
        RawDiffDetected          = $rawDiffDetected
        NormalizedDiffDetected   = $normalizedDiffDetected
        PossibleOmissionDetected = $possibleOmissionDetected
        InitialBaselineReview    = $isInitialBaselineReview
        ExecutedAtSort           = $executedAtSort
    }
}

function Test-IsInitialBaselineReview {
    param(
        [Parameter(Mandatory = $true)]
        $Eval
    )

    if ($null -eq $Eval) {
        return $false
    }

    $verdict = ""
    if ($null -ne $Eval.PSObject.Properties["recommendedVerdict"]) {
        $verdict = [string]$Eval.recommendedVerdict
    }

    if ($verdict -ne "REVIEW") {
        return $false
    }

    if ($null -eq $Eval.PSObject.Properties["reasons"]) {
        return $false
    }

    foreach ($reason in @($Eval.reasons)) {
        $text = [string]$reason
        if ($text -like "comparison not available: BASELINE_MISSING*") {
            return $true
        }
    }

    return $false
}

function Get-EvalEvidenceValue {
    param(
        [Parameter(Mandatory = $true)]
        $Eval,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ($null -eq $Eval) {
        return $null
    }

    $evidenceProp = $Eval.PSObject.Properties["evidence"]
    if ($null -eq $evidenceProp) {
        return $null
    }

    $evidence = $evidenceProp.Value
    if ($null -eq $evidence) {
        return $null
    }

    $targetProp = $evidence.PSObject.Properties[$Key]
    if ($null -eq $targetProp) {
        return $null
    }

    return $targetProp.Value
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$runsRoot = Join-Path $repoRoot "runs"
$evalsRoot = Join-Path $repoRoot "evals"
$outDir = Join-Path $evalsRoot $RunDate
$outPath = Join-Path $outDir "summary.txt"

if (-not (Test-Path $runsRoot)) {
    Write-Error "runs directory not found: $runsRoot"
    exit 1
}

$runDirs = @(Get-ChildItem -LiteralPath $runsRoot -Directory | Where-Object {
    $_.Name -like "RUN_*"
})

$items = @()
foreach ($dir in $runDirs) {
    $item = New-RunSummaryItem -RunDir $dir.FullName
    if ($null -ne $item -and $item.RunDate -eq $RunDate) {
        $items += $item
    }
}

$latestItems = @()
if ((Get-Count $items) -gt 0) {
    $latestItems = @(
        $items |
            Sort-Object CaseId, @{ Expression = { $_.ExecutedAtSort }; Descending = $true } |
            Group-Object CaseId |
            ForEach-Object { $_.Group | Select-Object -First 1 }
    )
}

$reviewQueue = @(
    $latestItems | Where-Object {
        $_.Status -eq "FAIL" -or $_.Status -eq "REVIEW"
    }
)

$totalCount = (Get-Count $latestItems)
$passCount = (Get-Count @($latestItems | Where-Object { $_.Status -eq "PASS" }))
$reviewCount = (Get-Count @($latestItems | Where-Object { $_.Status -eq "REVIEW" }))
$failCount = (Get-Count @($latestItems | Where-Object { $_.Status -eq "FAIL" }))
$pendingCount = (Get-Count @($latestItems | Where-Object { $_.Status -eq "SKIPPED_OR_PENDING" }))
$otherCount = (Get-Count @($latestItems | Where-Object {
    $_.Status -ne "PASS" -and
    $_.Status -ne "REVIEW" -and
    $_.Status -ne "FAIL" -and
    $_.Status -ne "SKIPPED_OR_PENDING"
}))

$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("===== REVIEW QUEUE =====")
$lines.Add("")

if ((Get-Count $reviewQueue) -eq 0) {
    $lines.Add("(none)")
    $lines.Add("")
}
else {
    $sortedReviewQueue = @(
        $reviewQueue | Sort-Object CaseId, @{ Expression = { $_.ExecutedAtSort }; Descending = $true }
    )

    foreach ($item in $sortedReviewQueue) {
        $severityUpper = (Get-StringOrDefault $item.Severity "N/A").ToUpper()
        $severityLower = (Get-StringOrDefault $item.Severity "n/a").ToLower()
        $isInitialBaselineReview = [bool]$item.InitialBaselineReview

        if ($isInitialBaselineReview) {
            $lines.Add("[$($item.Status)] $($item.CaseId) ($severityUpper / $severityLower) [latest]")
            $lines.Add("Run: $($item.RunId)")
            $lines.Add("")

            $lines.Add("▶ ACTION")
            $lines.Add("1. candidate output を人間確認")
            $lines.Add("2. 初回 baseline として妥当なら promote")
            $lines.Add("3. 不適切なら prompt / case / response を見直し")
            $lines.Add("")

            $lines.Add("▶ SUMMARY")
            $lines.Add((Get-SummaryLine -Item $item))
            $lines.Add("")

            $lines.Add("▶ SIGNALS")
            $lines.Add("- compareStatus: BASELINE_MISSING")
            $lines.Add("- comparable: False")
            $lines.Add("- severity: $($item.Severity)")
            $lines.Add("")

            $lines.Add("▶ DECISION GUIDE")
            $lines.Add("")
            $lines.Add("- INITIAL REVIEW:")
            $lines.Add("  初回 baseline 未確立。出力が妥当なら promote 検討")
            $lines.Add("")
            $lines.Add("- REVIEW:")
            $lines.Add("  人間確認後、意図通りなら promote 可能")
            $lines.Add("")
            $lines.Add("▶ NEXT STEP")
            $lines.Add("1. response / output を確認")
            $lines.Add("2. 初回 baseline として採用可否を判断")
            $lines.Add("3. Promote (if accepted):")
            $lines.Add("   ./scripts/promote-baseline.ps1 -RunId $($item.RunId)")
            $lines.Add("")
            $lines.Add("--------------------------------------------------")
            $lines.Add("")

            continue
        }

        $lines.Add("[$($item.Status)] $($item.CaseId) ($severityUpper / $severityLower) [latest]")
        $lines.Add("Run: $($item.RunId)")
        $lines.Add("")

        $lines.Add("▶ ACTION")
        foreach ($action in @(Get-ActionSummary -Item $item)) {
            $lines.Add($action)
        }
        $lines.Add("")

        $lines.Add("▶ SUMMARY")
        $lines.Add((Get-SummaryLine -Item $item))
        $lines.Add("")

        $lines.Add("▶ SIGNALS")
        $omissionText = if ($item.PossibleOmissionDetected) { "True" } else { "False" }
        $diffText = if ($item.NormalizedDiffDetected) { "True" } else { "False" }
        $formatText = if ($item.FormatMatchKnown) {
            if ($item.FormatMatch) { "True" } else { "False" }
        }
        else {
            "Unknown"
        }

        $lines.Add("- omission: $omissionText")
        $lines.Add("- diff: $diffText")
        $lines.Add("- formatMatch: $formatText")
        $lines.Add("- severity: $($item.Severity)")
        $lines.Add("")

        $lines.Add("▶ DECISION GUIDE")
        $lines.Add("")

        $lines.Add("- FAIL:")
        $lines.Add("  原則NG。意図した変更でない限り修正")
        $lines.Add("")

        $lines.Add("- REVIEW:")
        $lines.Add("  仕様変更ならOK。意図通りなら promote 検討")
        $lines.Add("")

        $lines.Add("- PASS:")
        $lines.Add("  問題なし。promote 可能")
        $lines.Add("")

        $lines.Add("▶ NEXT STEP")
        foreach ($step in @(Get-NextStepLines -Item $item)) {
            $lines.Add($step)
        }
        $lines.Add("")
        $lines.Add("4. Promote (if accepted):")
        $lines.Add("   ./scripts/promote-baseline.ps1 -RunId $($item.RunId)")
        $lines.Add("")
        $lines.Add("--------------------------------------------------")
        $lines.Add("")
    }
}

$lines.Add("===== CURRENT RUN SUMMARY =====")
$lines.Add("")

if ((Get-Count $latestItems) -eq 0) {
    $lines.Add("(none)")
    $lines.Add("")
}
else {
    $sortedLatestItems = @($latestItems | Sort-Object CaseId)

    foreach ($item in $sortedLatestItems) {
        $severityText = Get-StringOrDefault $item.Severity "N/A"
        $reasonText = ""

        if ((Get-Count $item.Reasons) -gt 0) {
            $reasonText = (@($item.Reasons) -join "; ")
        }
        elseif ($item.Status -eq "SKIPPED_OR_PENDING") {
            if ($item.ResponseState -eq "missing" -or $item.ResponseState -eq "empty") {
                $reasonText = "response.txt is empty or pending"
            }
            elseif ($item.HasCompare -and -not $item.HasEval) {
                $reasonText = "eval.json not found"
            }
            else {
                $reasonText = "compare/eval pending"
            }
        }
        else {
            $reasonText = "n/a"
        }

        $lines.Add("$($item.CaseId) : $($item.Status) | Severity=$severityText | Run=$($item.RunId) | $reasonText")
    }
    $lines.Add("")
}

$lines.Add("===== COUNTS =====")
$lines.Add(("Total             : {0}" -f $totalCount))
$lines.Add(("PASS              : {0}" -f $passCount))
$lines.Add(("REVIEW            : {0}" -f $reviewCount))
$lines.Add(("FAIL              : {0}" -f $failCount))
$lines.Add(("SKIPPED_OR_PENDING: {0}" -f $pendingCount))
$lines.Add(("OTHER             : {0}" -f $otherCount))
$lines.Add("")

$summaryText = ($lines -join [Environment]::NewLine)

Write-Host $summaryText
Write-Utf8BomFile -Path $outPath -Content $summaryText
Write-Host "Saved summary: $outPath"
