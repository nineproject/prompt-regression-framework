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

function Read-TextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (!(Test-Path -LiteralPath $Path)) {
        throw "Text file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Get-StringOrDefault {
    param(
        [Parameter(Mandatory = $false)]
        $Value,

        [Parameter(Mandatory = $true)]
        [string]$Default
    )

    if ($null -eq $Value) {
        return $Default
    }

    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) {
        return $Default
    }

    return $s
}

function Normalize-Content {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ""
    }

    $normalized = $Text

    $normalized = $normalized -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"

    $normalized = [System.Text.RegularExpressions.Regex]::Replace(
        $normalized,
        '[\t ]+$',
        '',
        [System.Text.RegularExpressions.RegexOptions]::Multiline
    )

    $normalized = [System.Text.RegularExpressions.Regex]::Replace(
        $normalized,
        "(`n){3,}",
        "`n`n"
    )

    $normalized = $normalized.Trim()

    return $normalized
}

function New-CasePolicy {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Meta
    )

    $tags = @()
    $tagsProp = $Meta.PSObject.Properties["tags"]
    if ($null -ne $tagsProp -and $null -ne $tagsProp.Value) {
        $tags = @($tagsProp.Value | ForEach-Object { [string]$_ })
    }

    $expectedFormatProp = $Meta.PSObject.Properties["expectedFormat"]
    $assertionModeProp  = $Meta.PSObject.Properties["assertionMode"]
    $priorityProp       = $Meta.PSObject.Properties["priority"]
    $changePolicyProp   = $Meta.PSObject.Properties["changePolicy"]

    return [ordered]@{
        expectedFormat = Get-StringOrDefault -Value $(if ($null -ne $expectedFormatProp) { $expectedFormatProp.Value } else { $null }) -Default "text"
        assertionMode  = Get-StringOrDefault -Value $(if ($null -ne $assertionModeProp)  { $assertionModeProp.Value }  else { $null }) -Default "normal"
        priority       = Get-StringOrDefault -Value $(if ($null -ne $priorityProp)       { $priorityProp.Value }       else { $null }) -Default "normal"
        changePolicy   = Get-StringOrDefault -Value $(if ($null -ne $changePolicyProp)   { $changePolicyProp.Value }   else { $null }) -Default "normal"
        tags           = $tags
    }
}

function Test-FormatMatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedFormat,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    switch ($ExpectedFormat.ToLowerInvariant()) {
        "json" {
            if ([string]::IsNullOrWhiteSpace($Content)) {
                return $false
            }

            try {
                $null = $Content | ConvertFrom-Json
                return $true
            }
            catch {
                return $false
            }
        }

        default {
            return $true
        }
    }
}

function Get-SeverityHint {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$FormatMatch,

        [Parameter(Mandatory = $true)]
        [bool]$RawDiffDetected,

        [Parameter(Mandatory = $true)]
        [bool]$NormalizedDiffDetected,

        [Parameter(Mandatory = $true)]
        [hashtable]$CasePolicy
    )

    if (-not $FormatMatch) {
        return "HIGH"
    }

    if ((-not $RawDiffDetected) -and (-not $NormalizedDiffDetected)) {
        return "NONE"
    }

    if ($RawDiffDetected -and (-not $NormalizedDiffDetected)) {
        return "LOW"
    }

    if ($NormalizedDiffDetected) {
        $assertionMode = [string]$CasePolicy.assertionMode
        $priority = [string]$CasePolicy.priority
        $changePolicy = [string]$CasePolicy.changePolicy

        if ($assertionMode -eq "strict") {
            return "HIGH"
        }

        if ($changePolicy -eq "low-drift") {
            return "HIGH"
        }

        if ($priority -eq "high") {
            return "MEDIUM"
        }

        return "MEDIUM"
    }

    return "LOW"
}

function Get-CaseIdFromManifest {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Manifest
    )

    if ($null -ne $Manifest.caseId -and -not [string]::IsNullOrWhiteSpace([string]$Manifest.caseId)) {
        return [string]$Manifest.caseId
    }

    throw "caseId not found in manifest.json"
}

function Get-BaselineRunId {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$BaselineInfo,

        [Parameter(Mandatory = $true)]
        [string]$BaselinePath
    )

    $candidateKeys = @(
        "baselineRunId",
        "runId",
        "approvedRunId",
        "promotedRunId",
        "latestRunId"
    )

    foreach ($key in $candidateKeys) {
        $prop = $BaselineInfo.PSObject.Properties[$key]
        if ($null -ne $prop) {
            $value = [string]$prop.Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
    }

    return $null
}

function Get-JsonSummarySafe {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    try {
        $obj = $Text | ConvertFrom-Json -ErrorAction Stop

        if ($null -eq $obj) {
            return $null
        }

        if ($obj.PSObject.Properties.Name -contains 'summary') {
            $value = [string]$obj.summary
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }

        return $null
    }
    catch {
        return $null
    }
}

function Get-KeywordTokens {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $stopWords = @(
        "the","and","for","with","this","that","will","from","into","only",
        "until","due","are","was","were","been","being","have","has","had",
        "must","not","but","can","could","should","would","may","might",
        "then","than","when","what","where","which","while","still","after",
        "before","about","because","there","their","them","they","team"
    )

    $matches = [regex]::Matches($Text.ToLowerInvariant(), "[a-z0-9]{3,}")
    $tokens = @()

    foreach ($m in $matches) {
        $word = [string]$m.Value
        if ($stopWords -notcontains $word) {
            $tokens += $word
        }
    }

    return [string[]]@($tokens | Sort-Object -Unique)
}

function Test-PossibleSummaryOmission {
    param(
        [AllowNull()]
        [string]$BaselineText,

        [AllowNull()]
        [string]$CandidateText
    )

    try {
        $signals = Get-SummaryOmissionSignals -BaselineText $BaselineText -CandidateText $CandidateText

        if (-not $signals.baselineSummaryExists) {
            return $false
        }

        if (-not $signals.candidateSummaryExists) {
            return $false
        }

        return ($signals.missingTokenCount -gt 0)
    }
    catch {
        return $false
    }
}

function Get-SummaryOmissionSignals {
    param(
        [AllowNull()]
        [string]$BaselineText,

        [AllowNull()]
        [string]$CandidateText
    )

    $baselineSummary = $null
    $candidateSummary = $null

    if (-not [string]::IsNullOrWhiteSpace($BaselineText)) {
        try {
            $baselineSummary = Get-JsonSummarySafe -Text $BaselineText
        }
        catch {
            $baselineSummary = $null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($CandidateText)) {
        try {
            $candidateSummary = Get-JsonSummarySafe -Text $CandidateText
        }
        catch {
            $candidateSummary = $null
        }
    }

    $baselineSummaryExists = -not [string]::IsNullOrWhiteSpace($baselineSummary)
    $candidateSummaryExists = -not [string]::IsNullOrWhiteSpace($candidateSummary)

    $baselineTokens = @()
    $candidateTokens = @()

    if ($baselineSummaryExists) {
        try {
            $baselineTokens = @(Get-KeywordTokens -Text $baselineSummary)
        }
        catch {
            $baselineTokens = @()
        }
    }

    if ($candidateSummaryExists) {
        try {
            $candidateTokens = @(Get-KeywordTokens -Text $candidateSummary)
        }
        catch {
            $candidateTokens = @()
        }
    }

    $missingTokens = @()

    if ((Get-ItemCountSafe $baselineTokens) -gt 0) {
        $candidateTokenSet = @{}
        foreach ($token in $candidateTokens) {
            if (-not [string]::IsNullOrWhiteSpace($token)) {
                $candidateTokenSet[$token] = $true
            }
        }

        foreach ($token in $baselineTokens) {
            if (-not [string]::IsNullOrWhiteSpace($token) -and -not $candidateTokenSet.ContainsKey($token)) {
                $missingTokens += $token
            }
        }
    }

    $baselineTokenCount = Get-ItemCountSafe $baselineTokens;
    $candidateTokenCount = Get-ItemCountSafe $candidateTokens;
    $missingTokenCount = Get-ItemCountSafe $missingTokens

    $missingTokensPreview = @()
    if ($missingTokenCount -gt 0) {
        $missingTokensPreview = @($missingTokens | Select-Object -First 10)
    }

    $missingTokenRatio = 0.0
    if ($baselineTokenCount -gt 0) {
        $missingTokenRatio = [math]::Round(($missingTokenCount / $baselineTokenCount), 4)
    }

    return [pscustomobject]@{
        baselineSummaryExists = $baselineSummaryExists
        candidateSummaryExists = $candidateSummaryExists
        baselineTokenCount    = $baselineTokenCount
        candidateTokenCount   = $candidateTokenCount
        missingTokenCount     = $missingTokenCount
        missingTokensPreview  = @($missingTokensPreview)
        missingTokenRatio     = $missingTokenRatio
    }
}

function Get-NormalizedLines {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return [string[]]@()
    }

    $lines = $Text -split "`r?`n"

    $normalized = foreach ($line in $lines) {
        $x = $line.Trim()
        $x = [regex]::Replace($x, '\s+', ' ')
        if (-not [string]::IsNullOrWhiteSpace($x)) {
            [string]$x
        }
    }

    return [string[]]@($normalized)
}

function Get-LineDiffSignals {
    param(
        [string[]]$BaselineLines,
        [string[]]$CandidateLines
    )

    $BaselineLines = [string[]]@($BaselineLines)
    $CandidateLines = [string[]]@($CandidateLines)

    $baselineSet = New-Object 'System.Collections.Generic.HashSet[string]'
    $candidateSet = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($line in @($BaselineLines)) {
        [void]$baselineSet.Add([string]$line)
    }

    foreach ($line in @($CandidateLines)) {
        [void]$candidateSet.Add([string]$line)
    }

    $missing = @()
    foreach ($line in @($BaselineLines)) {
        if (-not $candidateSet.Contains([string]$line)) {
            $missing += [string]$line
        }
    }

    $added = @()
    foreach ($line in @($CandidateLines)) {
        if (-not $baselineSet.Contains([string]$line)) {
            $added += [string]$line
        }
    }

    $sharedCount = 0
    foreach ($line in @($BaselineLines)) {
        if ($candidateSet.Contains([string]$line)) {
            $sharedCount++
        }
    }

    $baselineLineCount = Get-ItemCountSafe -Items $BaselineLines

    $sharedLineRatio =
        if ($baselineLineCount -gt 0) {
            [math]::Round(($sharedCount / $baselineLineCount), 4)
        }
        else {
            1.0
        }

    $missingArray = [string[]]@($missing)
    $addedArray = [string[]]@($added)

    return [pscustomobject]@{
        MissingNormalizedLines     = $missingArray
        MissingNormalizedLineCount = Get-ItemCountSafe -Items $missingArray
        AddedNormalizedLines       = $addedArray
        AddedNormalizedLineCount   = Get-ItemCountSafe -Items $addedArray
        SharedLineRatio            = $sharedLineRatio
    }
}

function Get-LengthSignals {
    param(
        [string]$BaselineText,
        [string]$CandidateText,
        [string[]]$BaselineLines,
        [string[]]$CandidateLines
    )

    $BaselineLines = [string[]]@($BaselineLines)
    $CandidateLines = [string[]]@($CandidateLines)

    $baselineCharCount =
        if ($null -ne $BaselineText) { $BaselineText.Length } else { 0 }

    $candidateCharCount =
        if ($null -ne $CandidateText) { $CandidateText.Length } else { 0 }

    $lengthRatio =
        if ($baselineCharCount -gt 0) {
            [math]::Round(($candidateCharCount / $baselineCharCount), 4)
        }
        else {
            1.0
        }

    return [pscustomobject]@{
        BaselineLineCount  = Get-ItemCountSafe -Items $BaselineLines
        CandidateLineCount = Get-ItemCountSafe -Items $CandidateLines
        BaselineCharCount  = $baselineCharCount
        CandidateCharCount = $candidateCharCount
        LengthRatio        = $lengthRatio
    }
}

function Test-PossibleOmission {
    param(
        [double]$LengthRatio,
        [int]$MissingNormalizedLineCount,
        [double]$OmissionLengthRatioThreshold = 0.80,
        [int]$OmissionMissingLineThreshold = 2
    )

    if ($LengthRatio -lt $OmissionLengthRatioThreshold) {
        return $true
    }

    if ($MissingNormalizedLineCount -ge $OmissionMissingLineThreshold) {
        return $true
    }

    return $false
}

function Get-ItemCountSafe {
    param(
        $Items
    )

    if ($null -eq $Items) {
        return 0
    }

    $count = 0

    foreach ($item in @($Items)) {
        $count++
    }

    return $count
}

function Get-OmissionStrength {
    param(
        [object]$DiffSignals,
        [object]$SummarySignals,
        [bool]$PossibleOmissionDetected
    )

    $missingTokenRatio = 0.0
    $sharedLineRatio = 1.0
    $missingLineCount = 0

    if ($null -ne $SummarySignals -and $null -ne $SummarySignals.missingTokenRatio) {
        $missingTokenRatio = [double]$SummarySignals.missingTokenRatio
    }

    if ($null -ne $DiffSignals -and $null -ne $DiffSignals.sharedLineRatio) {
        $sharedLineRatio = [double]$DiffSignals.sharedLineRatio
    }

    if ($null -ne $DiffSignals -and $null -ne $DiffSignals.missingNormalizedLines) {
        $missingLineCount = @($DiffSignals.missingNormalizedLines).Count
    }

    if (
        $missingTokenRatio -ge 0.35 -or
        $sharedLineRatio -le 0.50 -or
        $missingLineCount -ge 3
    ) {
        return "strong"
    }

    if (
        $PossibleOmissionDetected -or
        $missingTokenRatio -ge 0.15 -or
        $sharedLineRatio -le 0.75 -or
        $missingLineCount -ge 1
    ) {
        return "weak"
    }

    return "none"
}

function New-NotComparableCompareResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaseId,

        [Parameter(Mandatory = $true)]
        [string]$CandidateRunId,

        [AllowNull()]
        $BaselineRunId,

        [Parameter(Mandatory = $true)]
        [string]$CompareStatus,

        [Parameter(Mandatory = $true)]
        [string]$Reason,

        [AllowNull()]
        $CasePolicy
    )

    return [ordered]@{
        caseId                   = $CaseId
        baselineRunId            = $BaselineRunId
        candidateRunId           = $CandidateRunId

        compareStatus            = $CompareStatus
        comparable               = $false
        notComparableReason      = $Reason

        formatMatch              = $null
        rawDiffDetected          = $null
        normalizedDiffDetected   = $null
        severityHint             = "N/A"

        casePolicy               = $CasePolicy

        possibleOmissionDetected = $null
        diffSignals              = $null
        omissionSignals          = $null
        summarySignals           = $null

        reviewHints              = @(
            "comparison could not be performed",
            "review candidate output manually",
            "promote as baseline if approved"
        )
    }
}

function Save-CompareResultAndReturn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunDir,

        [Parameter(Mandatory = $true)]
        $CompareResult
    )

    $comparePath = Join-Path $RunDir "compare.json"
    $compareJson = $CompareResult | ConvertTo-Json -Depth 10
    Write-Utf8BomFile -Path $comparePath -Content $compareJson

    Write-Host ""
    Write-Host "===== COMPARE SUMMARY ====="
    Write-Host "Case           : $($CompareResult.caseId)"

    $baselineRunLabel = if ($null -ne $CompareResult.baselineRunId -and $CompareResult.baselineRunId -ne "") {
        $CompareResult.baselineRunId
    }
    else {
        "(none)"
    }

    Write-Host "Baseline Run   : $baselineRunLabel"

    Write-Host "Candidate Run  : $($CompareResult.candidateRunId)"
    Write-Host "Comparable     : $($CompareResult.comparable)"
    Write-Host "Status         : $($CompareResult.compareStatus)"
    if ($CompareResult.comparable -eq $false) {
        Write-Host "Reason         : $($CompareResult.notComparableReason)"
        Write-Host "Next Step      : review candidate output and promote baseline if approved"
    }
    Write-Host ""
    Write-Host "Saved compare artifact: $comparePath"
}

function New-CompareResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaseId,

        [AllowNull()]
        [string]$BaselineRunId,

        [Parameter(Mandatory = $true)]
        [string]$CandidateRunId,

        [Parameter(Mandatory = $true)]
        [string]$CompareStatus,

        [Parameter(Mandatory = $true)]
        [bool]$Comparable,

        [AllowNull()]
        $FormatMatch = $null,

        [AllowNull()]
        $RawDiffDetected = $null,

        [AllowNull()]
        $NormalizedDiffDetected = $null,

        [string]$SeverityHint = "N/A",

        [AllowNull()]
        $CasePolicy = $null,

        [AllowNull()]
        $PossibleOmissionDetected = $null,

        [AllowNull()]
        $OmissionStrength = $null,

        [AllowNull()]
        $DiffSignals = $null,

        [AllowNull()]
        $OmissionSignals = $null,

        [AllowNull()]
        $SummarySignals = $null
    )

    return [ordered]@{
        caseId                   = $CaseId
        baselineRunId            = $BaselineRunId
        candidateRunId           = $CandidateRunId
        compareStatus            = $CompareStatus
        comparable               = $Comparable
        formatMatch              = $FormatMatch
        rawDiffDetected          = $RawDiffDetected
        normalizedDiffDetected   = $NormalizedDiffDetected
        severityHint             = $SeverityHint
        casePolicy               = $CasePolicy
        possibleOmissionDetected = $PossibleOmissionDetected
        omissionStrength         = $OmissionStrength
        diffSignals              = $DiffSignals
        omissionSignals          = $OmissionSignals
        summarySignals           = $SummarySignals
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot

$candidateRunId = $RunId
$candidateRunDir = Join-Path $repoRoot ("runs\" + $candidateRunId)
$runDir = $candidateRunDir

if (!(Test-Path -LiteralPath $candidateRunDir)) {
    throw "Candidate run directory not found: $candidateRunDir"
}

$candidateManifestPath = Join-Path $candidateRunDir "manifest.json"
$candidateResponsePath = Join-Path $candidateRunDir "response.txt"
$candidateMetaPath = Join-Path $candidateRunDir "meta.json"
$comparePath = Join-Path $candidateRunDir "compare.json"

$candidateManifest = Read-JsonFile -Path $candidateManifestPath
$candidateResponse = Read-TextFile -Path $candidateResponsePath
$candidateMeta = Read-JsonFile -Path $candidateMetaPath

$caseId = Get-CaseIdFromManifest -Manifest $candidateManifest

$casePolicy = New-CasePolicy -Meta $candidateMeta

$baselinePath = Join-Path (Join-Path $repoRoot "tests\baselines") ("{0}.json" -f $caseId)

if (!(Test-Path $baselinePath)) {
    $compareResult = New-NotComparableCompareResult `
        -CaseId $caseId `
        -CandidateRunId $RunId `
        -BaselineRunId $null `
        -CompareStatus "BASELINE_MISSING" `
        -Reason "baseline definition not found: $baselinePath" `
        -CasePolicy $casePolicy

    Save-CompareResultAndReturn -RunDir $runDir -CompareResult $compareResult
    return
}

$baselineInfo = Read-JsonFile -Path $baselinePath
$baselineRunId = Get-BaselineRunId -BaselineInfo $baselineInfo -BaselinePath $baselinePath

if ([string]::IsNullOrWhiteSpace($baselineRunId)) {
    $compareResult = New-NotComparableCompareResult `
        -CaseId $caseId `
        -CandidateRunId $RunId `
        -BaselineRunId $null `
        -CompareStatus "BASELINE_UNREADABLE" `
        -Reason "baseline run id missing or empty in baseline file: $baselinePath" `
        -CasePolicy $casePolicy

    Save-CompareResultAndReturn -RunDir $runDir -CompareResult $compareResult
    return
}

$baselineRunDir = Join-Path $repoRoot ("runs\" + $baselineRunId)

if (!(Test-Path $baselineRunDir)) {
    $compareResult = New-NotComparableCompareResult `
        -CaseId $caseId `
        -CandidateRunId $RunId `
        -BaselineRunId $baselineRunId `
        -CompareStatus "BASELINE_UNREADABLE" `
        -Reason "baseline run directory not found: $baselineRunDir" `
        -CasePolicy $casePolicy

    Save-CompareResultAndReturn -RunDir $runDir -CompareResult $compareResult
    return
}

$baselineResponsePath = Join-Path $baselineRunDir "response.txt"
$baselineResponse = Read-TextFile -Path $baselineResponsePath

$rawDiffDetected = ($baselineResponse -ne $candidateResponse)

$possibleOmissionDetected = $false

$normalizedBaseline = Normalize-Content -Text $baselineResponse
$normalizedCandidate = Normalize-Content -Text $candidateResponse
$normalizedDiffDetected = ($normalizedBaseline -ne $normalizedCandidate)

$baselineLinesNormalized = Get-NormalizedLines -Text $baselineResponse
$candidateLinesNormalized = Get-NormalizedLines -Text $candidateResponse

$lineSignals = Get-LineDiffSignals `
    -BaselineLines $baselineLinesNormalized `
    -CandidateLines $candidateLinesNormalized

$lengthSignals = Get-LengthSignals `
    -BaselineText $baselineResponse `
    -CandidateText $candidateResponse `
    -BaselineLines $baselineLinesNormalized `
    -CandidateLines $candidateLinesNormalized

$possibleOmissionByLines = Test-PossibleOmission `
    -LengthRatio $lengthSignals.LengthRatio `
    -MissingNormalizedLineCount $lineSignals.MissingNormalizedLineCount

$formatMatch = Test-FormatMatch `
    -ExpectedFormat ([string]$casePolicy.expectedFormat) `
    -Content $candidateResponse

$severityHint = Get-SeverityHint `
    -FormatMatch $formatMatch `
    -RawDiffDetected $rawDiffDetected `
    -NormalizedDiffDetected $normalizedDiffDetected `
    -CasePolicy $casePolicy

$possibleOmissionBySummary = $false
$baselineSummary = $null
$candidateSummary = $null

if (
    $casePolicy.expectedFormat -eq "json" -and
    $formatMatch -and
    $normalizedDiffDetected
) {
    $baselineSummary = Get-JsonSummarySafe -Text $baselineResponse
    $candidateSummary = Get-JsonSummarySafe -Text $candidateResponse

    if (
        -not [string]::IsNullOrWhiteSpace($baselineSummary) -and
        -not [string]::IsNullOrWhiteSpace($candidateSummary)
    ) {
        $possibleOmissionBySummary = Test-PossibleSummaryOmission `
            -BaselineSummary $baselineSummary `
            -CandidateSummary $candidateSummary
    }
}

$summaryOmissionSignals = [pscustomobject]@{
    baselineSummaryExists = $false
    candidateSummaryExists = $false
    baselineTokenCount    = 0
    candidateTokenCount   = 0
    missingTokenCount     = 0
    missingTokensPreview  = @()
    missingTokenRatio     = 0.0
}

$possibleOmissionBySummary = $false

if ($casePolicy.expectedFormat -eq 'json' -and $formatMatch -and $normalizedDiffDetected) {
    $summaryOmissionSignals = Get-SummaryOmissionSignals -BaselineText $baselineResponse -CandidateText $candidateResponse
    $possibleOmissionBySummary = ($summaryOmissionSignals.missingTokenCount -gt 0)
}

$possibleOmissionDetected = ($possibleOmissionByLines -or $possibleOmissionBySummary)

$diffSignals = [pscustomobject]@{
    baselineLineCount = $lengthSignals.BaselineLineCount
    candidateLineCount = $lengthSignals.CandidateLineCount
    baselineCharCount = $lengthSignals.BaselineCharCount
    candidateCharCount = $lengthSignals.CandidateCharCount
    lengthRatio = $lengthSignals.LengthRatio
    missingNormalizedLines = $lineSignals.MissingNormalizedLineCount
    addedNormalizedLines = $lineSignals.AddedNormalizedLineCount
    sharedLineRatio = $lineSignals.SharedLineRatio
}

$omissionSignals = [pscustomobject]@{
    byLines = $possibleOmissionByLines
    bySummary = $possibleOmissionBySummary
}

$omissionStrength = Get-OmissionStrength `
    -DiffSignals $diffSignals `
    -SummarySignals $summaryOmissionSignals `
    -PossibleOmissionDetected $possibleOmissionDetected

$compare = New-CompareResult `
    -CaseId $caseId `
    -BaselineRunId $baselineRunId `
    -CandidateRunId $RunId `
    -CompareStatus "OK" `
    -Comparable $true `
    -FormatMatch $formatMatch `
    -RawDiffDetected $rawDiffDetected `
    -NormalizedDiffDetected $normalizedDiffDetected `
    -SeverityHint $severityHint `
    -CasePolicy $casePolicy `
    -PossibleOmissionDetected $possibleOmissionDetected `
    -OmissionStrength $omissionStrength `
    -DiffSignals $diffSignals `
    -OmissionSignals $omissionSignals `
    -SummarySignals $summaryOmissionSignals

$compare |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $comparePath -Encoding UTF8

Write-Host ""
Write-Host "===== COMPARE SUMMARY ====="
Write-Host ("Case                 : {0}" -f $caseId)
Write-Host ("Baseline Run         : {0}" -f $baselineRunId)
Write-Host ("Candidate Run        : {0}" -f $candidateRunId)
Write-Host ("Format Match         : {0}" -f $formatMatch)
Write-Host ("Raw Diff Detected    : {0}" -f $rawDiffDetected)
Write-Host ("Normalized Diff      : {0}" -f $normalizedDiffDetected)
Write-Host ("Severity Hint        : {0}" -f $severityHint)
Write-Host ("Compare Artifact     : {0}" -f $comparePath)
Write-Host ("Length Ratio         : {0}" -f $lengthSignals.LengthRatio)
Write-Host ("Missing Norm Lines   : {0}" -f $lineSignals.MissingNormalizedLineCount)
Write-Host ("Possible Omission    : {0}" -f $possibleOmissionDetected)
Write-Host ""
