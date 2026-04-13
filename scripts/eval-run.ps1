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

function New-NonComparableEvalResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaseId,

        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [Parameter(Mandatory = $true)]
        $Compare
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
        }
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$runDir = Join-Path $repoRoot ("runs\" + $RunId)

if (!(Test-Path -LiteralPath $runDir)) {
    throw "Run directory not found: $runDir"
}

$comparePath = Join-Path $runDir "compare.json"
$evalPath = Join-Path $runDir "eval.json"

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
        -Compare $compare

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

$recommendedVerdict = "PASS"

# Omission interpretation:
# compare provides evidence, eval interprets severity based on policy and summary loss strength.
if ($possibleOmissionDetected) {

    # Strong summary omission:
    # summary-based omission confirmed, large token loss, and strict policy context.
    if ($isStrongSummaryOmission) {
        $recommendedVerdict = 'FAIL'

        Add-UniqueItem -List ([ref]$reasons) -Value 'possible omission detected (summary-based)'
        Add-UniqueItem -List ([ref]$reasons) -Value 'high missing token ratio in summary'

        if ($isLowDrift) {
            Add-UniqueItem -List ([ref]$reasons) -Value 'low-drift policy escalated omission risk'
        }
        elseif ($isHighPriority) {
            Add-UniqueItem -List ([ref]$reasons) -Value 'high-priority case escalated omission risk'
        }

        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether critical summary content was dropped'
        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether required key information is missing'
    }

    # Loose text line-based suspicion:
    # keep as REVIEW when summary-based omission is not confirmed.
    elseif ($isLooseLineOnlyOmission) {
        if ($recommendedVerdict -ne 'FAIL') {
            $recommendedVerdict = 'REVIEW'
        }

        Add-UniqueItem -List ([ref]$reasons) -Value 'possible omission detected (line-based, loose text case)'
        Add-UniqueItem -List ([ref]$reasons) -Value 'summary omission not confirmed'

        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether meaning was preserved despite line compression'
        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether key points were retained after rephrasing'
    }

    # Partial summary omission:
    # summary-based signal exists, but not strong enough for strong-omission escalation.
    elseif ($isPartialSummaryOmission) {
        if ($recommendedVerdict -ne 'FAIL') {
            $recommendedVerdict = 'REVIEW'
        }

        Add-UniqueItem -List ([ref]$reasons) -Value 'possible omission detected (summary-based)'
        Add-UniqueItem -List ([ref]$reasons) -Value 'partial summary token loss detected'

        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether important summary content was partially dropped'
    }

    # Fallback omission handling:
    # omission evidence exists, but does not match a more specific interpretation rule.
    else {
        if ($recommendedVerdict -ne 'FAIL') {
            $recommendedVerdict = 'REVIEW'
        }

        Add-UniqueItem -List ([ref]$reasons) -Value 'possible omission detected'
        Add-UniqueItem -List ([ref]$reviewFocus) -Value 'check whether required key information is missing'
    }
}

if (-not $formatMatch) {
    $recommendedVerdict = "FAIL"
    Add-UniqueItem -List ([ref]$reasons) -Value "format mismatch detected"
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
    Add-UniqueItem -List ([ref]$reasons) -Value "normalized diff detected"
    Add-UniqueItem -List ([ref]$reviewFocus) -Value "check whether behavior changed materially"

    if ($assertionMode -eq "strict") {
        $recommendedVerdict = "FAIL"
        Add-UniqueItem -List ([ref]$reasons) -Value "strict assertion mode requires exact stability"
    }

    if ($changePolicy -eq "low-drift") {
        $recommendedVerdict = "FAIL"
        Add-UniqueItem -List ([ref]$reasons) -Value "low-drift policy escalated normalized diff"
        Add-UniqueItem -List ([ref]$reviewFocus) -Value "check whether output drift exceeds allowed tolerance"
    }
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
