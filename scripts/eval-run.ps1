param(
    [Parameter(Mandatory = $true)]
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
    Write-Host "ERROR LINE: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "ERROR TEXT: $($_.InvocationInfo.Line.Trim())"
    throw
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

function Write-Utf8BomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (!(Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "JSON file is empty: $Path"
    }

    return $raw | ConvertFrom-Json
}

function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        return $null
    }

    return $prop.Value
}

function Add-UniqueItem {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$List,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if (-not $List.Contains($Value)) {
        [void]$List.Add($Value)
    }
}

function Add-EvalReason {
    param(
        [Parameter(Mandatory = $true)]
        [ref]$List,

        [Parameter(Mandatory = $true)]
        [string]$Category,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $normalizedCategory = $Category.Trim().ToUpperInvariant()
    $text = "[$normalizedCategory] $Message"

    if ($null -eq $List.Value) {
        $List.Value = @()
    }

    if (-not (@($List.Value) -contains $text)) {
        $List.Value = @($List.Value) + $text
    }
}

function Get-VerdictRank {
    param(
        [string]$Verdict
    )

    switch ($Verdict) {
        'PASS'   { return 1 }
        'REVIEW' { return 2 }
        'FAIL'   { return 3 }
        default  { return 0 }
    }
}

function Escalate-AtLeast {
    param(
        [string]$CurrentVerdict,
        [string]$TargetVerdict
    )

    if ((Get-VerdictRank -Verdict $TargetVerdict) -gt (Get-VerdictRank -Verdict $CurrentVerdict)) {
        return $TargetVerdict
    }

    return $CurrentVerdict
}

function Get-BoolOrDefault {
    param(
        $Object,
        [string]$PropertyName,
        [bool]$Default = $false
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

    return [bool]$prop.Value
}

function Add-UniqueItem {
    param(
        [ref]$List,
        [string]$Value
    )

    if ($null -eq $List.Value) {
        $List.Value = @()
    }

    if (-not [string]::IsNullOrWhiteSpace($Value) -and $List.Value -notcontains $Value) {
        $List.Value += $Value
    }
}

function Test-IsMigRun {
    param(
        $Manifest
    )

    if ($null -eq $Manifest) {
        return $false
    }

    if (-not ($Manifest.PSObject.Properties.Name -contains 'migName')) {
        return $false
    }

    $migName = [string]$Manifest.migName

    if ([string]::IsNullOrWhiteSpace($migName)) {
        return $false
    }

    return ($migName -ne 'NO-MIG')
}

function Test-SummaryBasedOmissionStrong {
    param(
        $Compare
    )

    if ($null -eq $Compare) {
        return $false
    }

    if (-not ($Compare.PSObject.Properties.Name -contains 'summarySignals')) {
        return $false
    }

    $summarySignals = $Compare.summarySignals
    if ($null -eq $summarySignals) {
        return $false
    }

    if (-not ($summarySignals.PSObject.Properties.Name -contains 'missingTokenRatio')) {
        return $false
    }

    try {
        $missingTokenRatio = [double]$summarySignals.missingTokenRatio
        return ($missingTokenRatio -ge 0.30)
    }
    catch {
        return $false
    }
}

function Test-AdditionDominantChange {
    param(
        $Compare
    )

    if ($null -eq $Compare) {
        return $false
    }

    if (-not ($Compare.PSObject.Properties.Name -contains 'diffSignals')) {
        return $false
    }

    $diffSignals = $Compare.diffSignals
    if ($null -eq $diffSignals) {
        return $false
    }

    $addedCount = 0
    $missingCount = 0
    $candidateCharCount = 0
    $baselineCharCount = 0
    $candidateLineCount = 0
    $baselineLineCount = 0

    if ($diffSignals.PSObject.Properties.Name -contains 'addedNormalizedLines') {
        $addedCount = @($diffSignals.addedNormalizedLines).Count
    }

    if ($diffSignals.PSObject.Properties.Name -contains 'missingNormalizedLines') {
        $missingCount = @($diffSignals.missingNormalizedLines).Count
    }

    if ($diffSignals.PSObject.Properties.Name -contains 'candidateCharCount' -and $null -ne $diffSignals.candidateCharCount) {
        $candidateCharCount = [int]$diffSignals.candidateCharCount
    }

    if ($diffSignals.PSObject.Properties.Name -contains 'baselineCharCount' -and $null -ne $diffSignals.baselineCharCount) {
        $baselineCharCount = [int]$diffSignals.baselineCharCount
    }

    if ($diffSignals.PSObject.Properties.Name -contains 'candidateLineCount' -and $null -ne $diffSignals.candidateLineCount) {
        $candidateLineCount = [int]$diffSignals.candidateLineCount
    }

    if ($diffSignals.PSObject.Properties.Name -contains 'baselineLineCount' -and $null -ne $diffSignals.baselineLineCount) {
        $baselineLineCount = [int]$diffSignals.baselineLineCount
    }

    if ($addedCount -gt $missingCount) {
        return $true
    }

    if ($candidateCharCount -gt 0 -and $baselineCharCount -gt 0 -and $candidateCharCount -ge $baselineCharCount) {
        return $true
    }

    if ($candidateLineCount -gt 0 -and $baselineLineCount -gt 0 -and $candidateLineCount -ge $baselineLineCount) {
        return $true
    }

    return $false
}

function Test-ShouldModerateToReviewForMig {
    param(
        $Manifest,
        $Compare
    )

    if (-not (Test-IsMigRun -Manifest $Manifest)) {
        return $false
    }

    if ($null -eq $Compare) {
        return $false
    }

    $formatMatch = $true
    if ($Compare.PSObject.Properties.Name -contains 'formatMatch' -and $null -ne $Compare.formatMatch) {
        $formatMatch = [bool]$Compare.formatMatch
    }

    if (-not $formatMatch) {
        return $false
    }

    $normalizedDiffDetected = $false
    if ($Compare.PSObject.Properties.Name -contains 'normalizedDiffDetected' -and $null -ne $Compare.normalizedDiffDetected) {
        $normalizedDiffDetected = [bool]$Compare.normalizedDiffDetected
    }

    $possibleOmissionDetected = $false
    if ($Compare.PSObject.Properties.Name -contains 'possibleOmissionDetected' -and $null -ne $Compare.possibleOmissionDetected) {
        $possibleOmissionDetected = [bool]$Compare.possibleOmissionDetected
    }

    if (-not ($normalizedDiffDetected -or $possibleOmissionDetected)) {
        return $false
    }

    $summaryBasedOmissionStrong = Test-SummaryBasedOmissionStrong -Compare $Compare
    if ($summaryBasedOmissionStrong) {
        return $false
    }

    $additionDominant = Test-AdditionDominantChange -Compare $Compare

    if ($possibleOmissionDetected -and -not $additionDominant) {
        return $false
    }

    return $true
}

function New-NonComparableEvalResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaseId,

        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [Parameter(Mandatory = $true)]
        $Compare,

        [Parameter(Mandatory = $false)]
        [string]$MigName = "NO-MIG",

        [Parameter(Mandatory = $false)]
        [string]$MigType = "none",

        [Parameter(Mandatory = $false)]
        [string]$MigTypeSource = "no-mig"
    )

    $compareStatus = $null
    if ($null -ne $Compare.PSObject.Properties["compareStatus"]) {
        $value = [string]$Compare.compareStatus
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $compareStatus = $value
        }
    }

    if ([string]::IsNullOrWhiteSpace($compareStatus)) {
        if ($null -ne $Compare.PSObject.Properties["comparable"] -and [bool]$Compare.comparable -eq $false) {
            $compareStatus = "ERROR"
        }
        else {
            $compareStatus = "ERROR"
        }
    }

    $reasonDetail = [string]$Compare.notComparableReason

    $reasons = @()
    $reasons += "comparison not available: $compareStatus"

    if (-not [string]::IsNullOrWhiteSpace($reasonDetail)) {
        $reasons += $reasonDetail
    }

    $reviewFocus = switch ($compareStatus) {
        "BASELINE_MISSING" {
            @(
                "review candidate output manually",
                "confirm output is acceptable as an initial baseline",
                "promote as baseline if approved"
            )
        }
        "BASELINE_UNREADABLE" {
            @(
                "review candidate output manually",
                "check baseline artifact integrity",
                "repair baseline state before relying on comparison results"
            )
        }
        default {
            @(
                "review candidate output manually",
                "inspect compare artifact and script logs",
                "verify whether the comparison pipeline completed correctly"
            )
        }
    }

    return [ordered]@{
        caseId = $CaseId
        runId  = $RunId

        recommendedVerdict = "REVIEW"
        reasons            = $reasons
        reviewFocus        = $reviewFocus

        evidence = [ordered]@{
            compareStatus            = $compareStatus
            comparable               = $Compare.comparable
            severityHint             = $Compare.severityHint
            formatMatch              = $Compare.formatMatch
            rawDiffDetected          = $Compare.rawDiffDetected
            normalizedDiffDetected   = $Compare.normalizedDiffDetected
            possibleOmissionDetected = $Compare.possibleOmissionDetected
            migName                  = $MigName
            migType                  = $MigType
            migTypeSource            = $MigTypeSource
            migAwareAdjustmentApplied = $false
        }
    }
}

function Get-MigType {
    param(
        [string]$MigName
    )

    if ([string]::IsNullOrWhiteSpace($MigName) -or $MigName -eq "NO-MIG") {
        return "none"
    }

    $name = $MigName.ToLowerInvariant()

    if ($name -match "breaking|break|remove|delete|drop") {
        return "breaking"
    }

    if ($name -match "refactor|cleanup|rename|restructure") {
        return "refactor"
    }

    if ($name -match "modify|change|update|adjust|revise") {
        return "modify"
    }

    if ($name -match "add|append|introduce|new") {
        return "add-only"
    }

    return "unknown"
}

function Get-ExplicitMigTypeFromMeta {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$MigName
    )

    if ([string]::IsNullOrWhiteSpace($MigName) -or $MigName -eq "NO-MIG") {
        return $null
    }

    $allowedMigTypes = @(
        "add-only",
        "modify",
        "refactor",
        "breaking",
        "unknown"
    )

    $metaCandidates = @()

    # 1. Exact match:
    #    prompts/mig-meta/0001-add-comment.md
    $metaCandidates += Join-Path $RepoRoot "prompts\mig-meta\$MigName.md"

    # 2. MIG-ID match:
    #    migName = 0001-add-comment
    #    meta    = MIG-0001.md
    if ($MigName -match '^(\d{4})(?:-|$)') {
        $migId = $Matches[1]
        $metaCandidates += Join-Path $RepoRoot "prompts\mig-meta\MIG-$migId.md"
    }

    foreach ($metaPath in $metaCandidates) {
        if (-not (Test-Path $metaPath)) {
            continue
        }

        $lines = Get-Content $metaPath -Encoding UTF8

        foreach ($line in $lines) {
            if ($line -match '^\s*migType\s*:\s*(.+?)\s*$') {
                $migType = $Matches[1].Trim().ToLowerInvariant()

                if ($allowedMigTypes -contains $migType) {
                    return $migType
                }

                return "unknown"
            }
        }
    }

    return $null
}

function Add-UniqueItem {
    param(
        [System.Collections.ArrayList]$List,
        [string]$Item
    )

    if (-not [string]::IsNullOrWhiteSpace($Item) -and -not $List.Contains($Item)) {
        [void]$List.Add($Item)
    }
}

function Apply-MigTypeAwareVerdictAdjustment {
    param(
        [string]$RecommendedVerdict,
        [string]$MigType,
        [string]$SeverityHint,
        [bool]$PossibleOmissionDetected,
        [bool]$FormatMatch,
        [bool]$NormalizedDiffDetected,
        [System.Collections.ArrayList]$Reasons,
        [System.Collections.ArrayList]$ReviewFocus
    )

    $adjustmentApplied = $false
    $finalVerdict = $RecommendedVerdict

    if ($MigType -eq "none") {
        return [pscustomobject]@{
            Verdict = $finalVerdict
            AdjustmentApplied = $false
        }
    }

    switch ($MigType) {
        "add-only" {
            if ($RecommendedVerdict -eq "FAIL") {
                if ($PossibleOmissionDetected) {
                    Add-UniqueItem $Reasons "MIG type add-only kept FAIL because omission risk was detected"
                    Add-UniqueItem $ReviewFocus "check whether existing behavior or required information was removed"
                }
                elseif (-not $FormatMatch) {
                    Add-UniqueItem $Reasons "MIG type add-only kept FAIL because output format changed"
                    Add-UniqueItem $ReviewFocus "check whether output format change is intentional and backward compatible"
                }
                else {
                    Add-UniqueItem $Reasons "MIG type add-only softened FAIL to REVIEW"
                    Add-UniqueItem $ReviewFocus "check whether added behavior is intentional and backward compatible"
                    $finalVerdict = "REVIEW"
                    $adjustmentApplied = $true
                }
            }
            elseif ($RecommendedVerdict -eq "REVIEW") {
                if ($PossibleOmissionDetected) {
                    Add-EvalReason -List ([ref]$reasons) -Category "MIG" -Message "add-only kept REVIEW because omission risk was detected"
                    Add-UniqueItem $ReviewFocus "check whether existing behavior or required information was removed"
                }
                elseif (-not $FormatMatch) {
                    Add-EvalReason -List ([ref]$reasons) -Category "MIG" -Message "add-only kept REVIEW because output format changed"
                    Add-UniqueItem $ReviewFocus "check whether output format change is intentional and backward compatible"
                }
                else {
                    Add-EvalReason -List ([ref]$reasons) -Category "MIG" -Message "add-only kept REVIEW for human validation of added behavior"
                    Add-UniqueItem $ReviewFocus "check whether added behavior is intentional and backward compatible"
                }
            }
        }

        "modify" {
            if ($RecommendedVerdict -eq "FAIL") {
                if ($SeverityHint -eq "HIGH" -or $PossibleOmissionDetected) {
                    Add-UniqueItem $Reasons "MIG type modify kept FAIL because high-risk drift was detected"
                    Add-UniqueItem $ReviewFocus "check whether modified behavior removed required behavior"
                }
                else {
                    Add-UniqueItem $Reasons "MIG type modify allowed human review for non-critical drift"
                    Add-UniqueItem $ReviewFocus "check whether modified behavior matches intended MIG"
                    $finalVerdict = "REVIEW"
                    $adjustmentApplied = $true
                }
            }
        }

        "refactor" {
            if ($RecommendedVerdict -eq "PASS" -and $NormalizedDiffDetected) {
                Add-UniqueItem $Reasons "MIG type refactor escalated normalized diff to REVIEW"
                Add-UniqueItem $ReviewFocus "check whether refactor preserved observable behavior"
                $finalVerdict = "REVIEW"
                $adjustmentApplied = $true
            }

            if ($RecommendedVerdict -eq "FAIL" -and -not $PossibleOmissionDetected -and $FormatMatch -and $SeverityHint -ne "HIGH") {
                Add-UniqueItem $Reasons "MIG type refactor softened non-critical FAIL to REVIEW"
                Add-UniqueItem $ReviewFocus "check whether refactor changed behavior unexpectedly"
                $finalVerdict = "REVIEW"
                $adjustmentApplied = $true
            }
        }

        "breaking" {
            if ($RecommendedVerdict -eq "PASS") {
                Add-UniqueItem $Reasons "MIG type breaking escalated PASS to REVIEW"
                Add-UniqueItem $ReviewFocus "confirm breaking change is explicitly intended"
                $finalVerdict = "REVIEW"
                $adjustmentApplied = $true
            }
            elseif ($RecommendedVerdict -eq "REVIEW" -and ($SeverityHint -eq "HIGH" -or $PossibleOmissionDetected -or -not $FormatMatch)) {
                Add-UniqueItem $Reasons "MIG type breaking escalated REVIEW to FAIL due to high-risk evidence"
                Add-UniqueItem $ReviewFocus "check whether breaking behavior is explicitly intended"
                $finalVerdict = "FAIL"
                $adjustmentApplied = $true
            }
        }

        default {
            if ($RecommendedVerdict -eq "FAIL") {
                Add-UniqueItem $Reasons "MIG type unknown; keeping conservative evaluation"
                Add-UniqueItem $ReviewFocus "check MIG intent manually"
            }
        }
    }

    return [pscustomobject]@{
        Verdict = $finalVerdict
        AdjustmentApplied = $adjustmentApplied
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$runDir = Join-Path $repoRoot ("runs\" + $RunId)

if (!(Test-Path -LiteralPath $runDir)) {
    throw "Run directory not found: $runDir"
}

$comparePath = Join-Path $runDir "compare.json"
$evalPath = Join-Path $runDir "eval.json"
$manifestPath = Join-Path $runDir "manifest.json"
$manifest = $null

if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    }
    catch {
        $manifest = $null
    }
}

$migName = "NO-MIG"

if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "migName") {
    if (-not [string]::IsNullOrWhiteSpace($manifest.migName)) {
        $migName = [string]$manifest.migName
    }
}

$migName = $manifest.migName

if ([string]::IsNullOrWhiteSpace($migName)) {
    $migName = "NO-MIG"
}

$explicitMigType = Get-ExplicitMigTypeFromMeta `
    -RepoRoot $repoRoot `
    -MigName $migName

if ($migName -eq "NO-MIG") {
    $migType = "none"
    $migTypeSource = "no-mig"
}
elseif (-not [string]::IsNullOrWhiteSpace($explicitMigType)) {
    $migType = $explicitMigType
    $migTypeSource = "explicit-meta"
}
else {
    $migType = Get-MigType -MigName $migName
    $migTypeSource = "name-inference"
}

$compare = Read-JsonFile -Path $comparePath

$caseId = [string](Get-OptionalPropertyValue -Object $compare -Name "caseId")
if ([string]::IsNullOrWhiteSpace($caseId)) {
    throw "caseId not found in compare.json"
}

$compareStatus = $null
if ($null -ne $compare.PSObject.Properties["compareStatus"]) {
    $value = [string]$compare.compareStatus
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        $compareStatus = $value
    }
}

$comparable = $true
if ($null -ne $compare.PSObject.Properties["comparable"]) {
    $comparable = [bool]$compare.comparable
}

if ([string]::IsNullOrWhiteSpace($compareStatus)) {
    if ($comparable -eq $false) {
        $compareStatus = "ERROR"
    }
    else {
        $compareStatus = "OK"
    }
}

if ($compareStatus -ne "OK") {
    $compare | Add-Member -NotePropertyName compareStatus -NotePropertyValue $compareStatus -Force

    $evalResult = New-NonComparableEvalResult `
        -CaseId $caseId `
        -RunId $RunId `
        -Compare $compare `
        -MigName $migName `
        -MigType $migType `
        -MigTypeSource $migTypeSource

    $evalJson = $evalResult | ConvertTo-Json -Depth 10
    Write-Utf8BomFile -Path $evalPath -Content $evalJson

    Write-Host ""
    Write-Host "===== EVAL SUMMARY ====="
    Write-Host "Case           : $caseId"
    Write-Host "Run            : $RunId"
    Write-Host "Verdict        : REVIEW"
    Write-Host "Reason         : comparison not available ($compareStatus)"
    Write-Host "Next Step      : review candidate output and promote baseline if approved"
    Write-Host ""
    Write-Host "Saved eval artifact: $evalPath"

    return
}

$omissionStrength = "none"

if ($null -ne $compare.omissionStrength -and $compare.omissionStrength -ne "") {
    $omissionStrength = [string]$compare.omissionStrength
}
elseif ($compare.possibleOmissionDetected -eq $true) {
    # backward compatibility for compare.json without omissionStrength
    $omissionStrength = "weak"
}

$possibleOmissionDetected = Get-BoolOrDefault `
    -Object $compare `
    -PropertyName "possibleOmissionDetected" `
    -Default $false

if ($null -ne $compare.possibleOmissionDetected) {
    $possibleOmissionDetected = [bool]$compare.possibleOmissionDetected
}

$formatMatch = [bool](Get-OptionalPropertyValue -Object $compare -Name "formatMatch")
$rawDiffDetected = [bool](Get-OptionalPropertyValue -Object $compare -Name "rawDiffDetected")
$normalizedDiffDetected = [bool](Get-OptionalPropertyValue -Object $compare -Name "normalizedDiffDetected")
$severityHint = [string](Get-OptionalPropertyValue -Object $compare -Name "severityHint")

$casePolicy = Get-OptionalPropertyValue -Object $compare -Name "casePolicy"
if ($null -eq $casePolicy) {
    throw "casePolicy not found in compare.json"
}

$assertionMode = [string](Get-OptionalPropertyValue -Object $casePolicy -Name "assertionMode")
$changePolicy = [string](Get-OptionalPropertyValue -Object $casePolicy -Name "changePolicy")
$priority = [string](Get-OptionalPropertyValue -Object $casePolicy -Name "priority")
$expectedFormat = [string](Get-OptionalPropertyValue -Object $casePolicy -Name "expectedFormat")

$omissionSignals = Get-OptionalPropertyValue -Object $compare -Name "omissionSignals"

$omissionByLines = Get-BoolOrDefault `
    -Object $omissionSignals `
    -PropertyName "byLines" `
    -Default $false

$omissionBySummary = Get-BoolOrDefault `
    -Object $omissionSignals `
    -PropertyName "bySummary" `
    -Default $false

$isLooseFlexibleTextCase = (
    $expectedFormat -eq "text" -and
    $assertionMode -eq "loose" -and
    $changePolicy -eq "flexible"
)

$isSoftLineOmissionCase = (
    $possibleOmissionDetected -and
    $omissionByLines -and
    (-not $omissionBySummary) -and
    $isLooseFlexibleTextCase
)

$StrongSummaryOmissionRatioThreshold = 0.5

$summarySignals = $compare.summarySignals
$missingTokenRatio = 0.0

if ($null -ne $summarySignals -and $null -ne $summarySignals.missingTokenRatio) {
    try {
        $missingTokenRatio = [double]$summarySignals.missingTokenRatio
    }
    catch {
        $missingTokenRatio = 0.0
    }
}

$isLowDrift = ($casePolicy.changePolicy -eq 'low-drift')
$isHighPriority = ($casePolicy.priority -eq 'high')

$isLooseTextFlexible = (
    $casePolicy.expectedFormat -eq 'text' -and
    $casePolicy.assertionMode -eq 'loose' -and
    $casePolicy.changePolicy -eq 'flexible'
)

$isBySummary = ($null -ne $omissionSignals -and $omissionSignals.bySummary -eq $true)
$isByLines = ($null -ne $omissionSignals -and $omissionSignals.byLines -eq $true)

$isStrongSummaryOmission = (
    $possibleOmissionDetected -and
    $isBySummary -and
    ($missingTokenRatio -ge $StrongSummaryOmissionRatioThreshold) -and
    ($isLowDrift -or $isHighPriority)
)

$isLooseLineOnlyOmission = (
    $possibleOmissionDetected -and
    $isByLines -and
    (-not $isBySummary) -and
    $isLooseTextFlexible -and
    ($missingTokenRatio -eq 0)
)

$isPartialSummaryOmission = (
    $possibleOmissionDetected -and
    $isBySummary -and
    ($missingTokenRatio -gt 0) -and
    (-not $isStrongSummaryOmission)
)

$reasons = [System.Collections.ArrayList]::new()
$reviewFocus = [System.Collections.ArrayList]::new()

$isMigRun = Test-IsMigRun -Manifest $manifest
$summaryBasedOmissionStrong = Test-SummaryBasedOmissionStrong -Compare $compare
$additionDominant = Test-AdditionDominantChange -Compare $compare
$shouldModerateToReviewForMig = Test-ShouldModerateToReviewForMig -Manifest $manifest -Compare $compare

$recommendedVerdict = "PASS"

# Omission interpretation:
# compare provides omissionStrength as evidence, eval interprets it into verdict.
# Backward compatibility:
# if omissionStrength does not exist, possibleOmissionDetected=true is treated as weak.
if ($omissionStrength -eq 'strong') {
    $recommendedVerdict = 'FAIL'

    Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "strong omission risk detected"

    if ($isStrongSummaryOmission) {
        Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "possible omission detected (summary-based)"
        Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "high missing token ratio in summary"
    }

    if ($isLowDrift) {
        Add-EvalReason -List ([ref]$reasons) -Category "POLICY" -Message "low-drift policy escalated omission risk"
    }
    elseif ($isHighPriority) {
        Add-EvalReason -List ([ref]$reasons) -Category "POLICY" -Message "high-priority case escalated omission risk"
    }

    Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether critical summary content was dropped'
    Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether required key information is missing'
}
elseif ($omissionStrength -eq 'weak') {
    if ($recommendedVerdict -ne 'FAIL') {
        $recommendedVerdict = 'REVIEW'
    }

    Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "weak omission risk detected"

    if ($isLooseLineOnlyOmission) {
        Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "possible omission detected (line-based, loose text case)"
        Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "summary omission not confirmed"

        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether meaning was preserved despite line compression'
        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether key points were retained after rephrasing'
    }
    elseif ($isPartialSummaryOmission) {
        Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "possible omission detected (summary-based)"
        Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "partial summary token loss detected"

        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether important summary content was partially dropped'
    }
    else {
        Add-EvalReason -List ([ref]$reasons) -Category "OMISSION" -Message "possible omission detected"
        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether required key information is missing'
    }
}

if (-not $formatMatch) {
    $recommendedVerdict = "FAIL"
    Add-EvalReason -List ([ref]$reasons) -Category "FORMAT" -Message "format mismatch detected"
    Add-UniqueItem -List ([ref]$reviewFocus) -Value "check output format"

    if ($expectedFormat -eq "json") {
        Add-UniqueItem -List ([ref]$reviewFocus) -Value "check whether json contract is preserved"
    }
}
elseif (-not $normalizedDiffDetected) {
    $recommendedVerdict = "PASS"

    if ($rawDiffDetected) {
        Add-UniqueItem -List ([ref]$reasons) -Value "only superficial diff detected"
        Add-UniqueItem -List ([ref]$reviewFocus) -Value "confirm formatting-only difference is acceptable"
    }
    else {
        Add-UniqueItem -List ([ref]$reasons) -Value "no meaningful diff detected"
    }
}
else {
    $recommendedVerdict = "REVIEW"
    Add-EvalReason -List ([ref]$reasons) -Category "DIFF" -Message "normalized diff detected"
    Add-UniqueItem -List ([ref]$reviewFocus) -Value "check whether behavior changed materially"

    if ($assertionMode -eq "strict") {
        $recommendedVerdict = "FAIL"
        Add-UniqueItem -List ([ref]$reasons) -Value "strict assertion mode requires exact stability"
    }

    if ($changePolicy -eq "low-drift") {

        if ($shouldModerateToReviewForMig -and $recommendedVerdict -ne "FAIL") {
            $recommendedVerdict = "REVIEW"

            Add-UniqueItem -List ([ref]$reasons) -Value "MIG-applied run: detected changes may reflect intended spec evolution"
            Add-UniqueItem -List ([ref]$reasons) -Value "REVIEW preferred over immediate FAIL under MIG context"

            Add-UniqueItem -List ([ref]$reviewFocus) -Value "verify that the MIG-intended additions are correct"
            Add-UniqueItem -List ([ref]$reviewFocus) -Value "confirm that existing important behavior was not unintentionally broken"
            Add-UniqueItem -List ([ref]$reviewFocus) -Value "review whether added changes match the intended migration scope"
        }
        else {
            $recommendedVerdict = "FAIL"
            Add-EvalReason -List ([ref]$reasons) -Category "POLICY" -Message "low-drift policy escalated normalized diff"
            Add-UniqueItem -List ([ref]$reviewFocus) -Value "check whether output drift exceeds allowed tolerance"
        }
    }
}

$migAdjustment = Apply-MigTypeAwareVerdictAdjustment `
    -RecommendedVerdict $recommendedVerdict `
    -MigType $migType `
    -SeverityHint $severityHint `
    -PossibleOmissionDetected $possibleOmissionDetected `
    -FormatMatch $formatMatch `
    -NormalizedDiffDetected $normalizedDiffDetected `
    -Reasons $reasons `
    -ReviewFocus $reviewFocus

$recommendedVerdict = $migAdjustment.Verdict
$migAwareAdjustmentApplied = [bool]$migAdjustment.AdjustmentApplied

# Final MIG-aware adjustment:
# Keep add-only MIG changes in REVIEW when omission/diff risk exists,
# because add-only changes may legitimately expand or restructure output.
$hasOmissionRisk = (
    $possibleOmissionDetected -eq $true -or
    $omissionStrength -eq 'weak' -or
    $omissionStrength -eq 'strong'
)

$hasDiffRisk = (
    $normalizedDiffDetected -eq $true -or
    $rawDiffDetected -eq $true -or
    $formatMatch -eq $false
)

if ($migType -eq 'add-only' -and ($hasOmissionRisk -or $hasDiffRisk)) {
    if ($recommendedVerdict -eq 'FAIL') {
        $recommendedVerdict = 'REVIEW'
    }

    if ($hasOmissionRisk) {
        Add-EvalReason -List ([ref]$reasons) -Category "MIG" -Message "add-only kept REVIEW because omission risk was detected"
    }
    elseif ($formatMatch -eq $false) {
        Add-EvalReason -List ([ref]$reasons) -Category "MIG" -Message "add-only kept REVIEW because output format changed"
    }
    else {
        Add-EvalReason -List ([ref]$reasons) -Category "MIG" -Message "add-only kept REVIEW for human validation of added behavior"
    }

    Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether existing behavior or required information was removed'

    $migAwareAdjustmentApplied = $true
}

$reasons = @($reasons | Select-Object -Unique)
$reviewFocus = @($reviewFocus | Select-Object -Unique)

$eval = [ordered]@{
    caseId = $caseId
    runId = $RunId
    recommendedVerdict = $recommendedVerdict
    reasons = @($reasons)
    reviewFocus = @($reviewFocus)
    evidence = [ordered]@{
        severityHint = $severityHint
        formatMatch = $formatMatch
        rawDiffDetected = $rawDiffDetected
        normalizedDiffDetected = $normalizedDiffDetected
        possibleOmissionDetected = $possibleOmissionDetected
        omissionStrength = $omissionStrength
        migName = $migName
        migType = $migType
        migTypeSource = $migTypeSource
        migAwareAdjustmentApplied = $migAwareAdjustmentApplied
    }
}

$eval |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $evalPath -Encoding UTF8

Write-Host ""
Write-Host "===== EVALUATION SUMMARY ====="
Write-Host ("Case                 : {0}" -f $caseId)
Write-Host ("Run                  : {0}" -f $RunId)
Write-Host ("Recommended Verdict  : {0}" -f $recommendedVerdict)
Write-Host ("Severity Hint        : {0}" -f $severityHint)
Write-Host ("Eval Artifact        : {0}" -f $evalPath)
Write-Host ""
