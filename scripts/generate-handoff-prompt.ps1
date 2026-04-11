param(
    [string]$OutFile = "",

    [string]$CurrentTask = "",

    [string]$Notes = ""
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
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Get-RepoRoot {
    if ($PSScriptRoot) {
        return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }
    
    return (Get-Location).Path
}

function Read-JsonSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-NextActionLines {
    param(
        [string]$RunDir
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Next Action Summary:")

    if ([string]::IsNullOrWhiteSpace($RunDir) -or -not (Test-Path $RunDir)) {
        $lines.Add("- latest run not found")
        $lines.Add("- next recommended step: run a case or suite first")
        return $lines
    }

    $responsePath = Join-Path $RunDir "response.txt"
    $comparePath  = Join-Path $RunDir "compare.json"
    $evalPath     = Join-Path $RunDir "eval.json"
    $manifestPath = Join-Path $RunDir "manifest.json"

    $manifest = Read-JsonSafe -Path $manifestPath
    $eval = Read-JsonSafe -Path $evalPath

    $runName = Split-Path $RunDir -Leaf
    $runId = if ($manifest -and $manifest.runId) { [string]$manifest.runId } else { $runName }

    $hasCompare = Test-Path $comparePath
    $hasEval = Test-Path $evalPath

    $responseExists = Test-Path $responsePath
    $responseText = if ($responseExists) {
        Get-Content -Path $responsePath -Raw -Encoding UTF8
    }
    else {
        ""
    }

    $responseEmpty = [string]::IsNullOrWhiteSpace($responseText)

    if ($responseEmpty -and -not $hasCompare -and -not $hasEval) {
        $lines.Add("- response.txt is empty or pending")
        $lines.Add("- compare has not been executed")
        $lines.Add("- eval has not been executed")
        $lines.Add("- next recommended step: fill response.txt and run compare/eval")
        $lines.Add(("- suggested commands: ./scripts/compare-run.ps1 -RunId {0} / ./scripts/eval-run.ps1 -RunId {0}" -f $runId))
        return $lines
    }

    if (-not $responseEmpty -and -not $hasCompare -and -not $hasEval) {
        $lines.Add("- response.txt exists")
        $lines.Add("- compare has not been executed")
        $lines.Add("- eval has not been executed")
        $lines.Add(("- next recommended step: run compare-run.ps1 -RunId {0}" -f $runId))
        return $lines
    }

    if ($hasCompare -and -not $hasEval) {
        $lines.Add("- compare completed")
        $lines.Add("- eval has not been executed")
        $lines.Add(("- next recommended step: run eval-run.ps1 -RunId {0}" -f $runId))
        return $lines
    }

    if ($hasCompare -and $hasEval) {
        $verdict = if ($eval -and $eval.recommendedVerdict) {
            [string]$eval.recommendedVerdict
        }
        else {
            "UNKNOWN"
        }

        $lines.Add("- compare completed")
        $lines.Add("- eval completed")
        $lines.Add(("- recommendedVerdict={0}" -f $verdict))
        $lines.Add("- next recommended step: review eval result and decide whether to promote baseline")
        return $lines
    }

    $lines.Add("- latest run state is partially detected")
    $lines.Add("- next recommended step: inspect run artifacts manually")
    return $lines
}

function Get-LatestRunDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunsRoot
    )

    if (-not (Test-Path $RunsRoot)) {
        return $null
    }

    $dirs = Get-ChildItem -Path $RunsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "RUN_*" } |
        Sort-Object Name -Descending

    if ($dirs -and $dirs.Count -gt 0) {
        return $dirs[0].FullName
    }

    return $null
}

function Get-LatestRunDetails {
    param(
        [string]$RunDir
    )

    if ([string]::IsNullOrWhiteSpace($RunDir)) {
        return @("LatestRun: (none)")
    }

    $runName = Split-Path $RunDir -Leaf
    $manifest = Read-JsonSafe -Path (Join-Path $RunDir "manifest.json")
    $eval     = Read-JsonSafe -Path (Join-Path $RunDir "eval.json")
    $compare  = Read-JsonSafe -Path (Join-Path $RunDir "compare.json")

    $caseId   = if ($manifest -and $manifest.caseId) { [string]$manifest.caseId } else { "(unknown)" }
    $verdict  = if ($eval -and $eval.recommendedVerdict) { [string]$eval.recommendedVerdict } else { "SKIPPED_OR_PENDING" }
    $severity = if ($eval -and $eval.evidence -and $eval.evidence.severityHint) { [string]$eval.evidence.severityHint } else { "N/A" }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(("LatestRun: {0} | Verdict={1} | Severity={2} | Run={3}" -f $caseId, $verdict, $severity, $runName))

    if ($compare) {
        $lines.Add("LatestCompare:")
        if ($null -ne $compare.formatMatch) {
            $lines.Add(("- formatMatch={0}" -f $compare.formatMatch))
        }
        if ($null -ne $compare.rawDiffDetected) {
            $lines.Add(("- rawDiffDetected={0}" -f $compare.rawDiffDetected))
        }
        if ($null -ne $compare.normalizedDiffDetected) {
            $lines.Add(("- normalizedDiffDetected={0}" -f $compare.normalizedDiffDetected))
        }
        if ($null -ne $compare.possibleOmissionDetected) {
            $lines.Add(("- possibleOmissionDetected={0}" -f $compare.possibleOmissionDetected))
        }
        if ($compare.severityHint) {
            $lines.Add(("- severityHint={0}" -f $compare.severityHint))
        }
    }

    if ($eval -and $eval.reasons) {
        $lines.Add("LatestEvalReasons:")
        foreach ($reason in $eval.reasons) {
            $lines.Add(("- " + [string]$reason))
        }
    }

    if ($eval -and $eval.reviewFocus) {
        $lines.Add("LatestReviewFocus:")
        foreach ($focus in $eval.reviewFocus) {
            $lines.Add(("- " + [string]$focus))
        }
    }

    return $lines
}

function Get-SuiteDetails {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuitesRoot
    )

    $lines = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path $SuitesRoot)) {
        $lines.Add("(no suites)")
        return $lines
    }

    $files = Get-ChildItem -Path $SuitesRoot -Recurse -Filter "suite.json" -ErrorAction SilentlyContinue |
        Sort-Object FullName

    if (-not $files -or $files.Count -eq 0) {
        $lines.Add("(no suite data)")
        return $lines
    }

    foreach ($file in $files) {
        $json = Read-JsonSafe -Path $file.FullName
        if ($json) {
            $suiteId = if ($json.id) { [string]$json.id } else { (Split-Path $file.DirectoryName -Leaf) }
            $caseIds = if ($json.caseIds) { ([string[]]$json.caseIds) -join ", " } else { "(none)" }

            $lines.Add(("Suite: {0}" -f $suiteId))
            $lines.Add(("Cases: {0}" -f $caseIds))
        }
    }

    if ($lines.Count -eq 0) {
        $lines.Add("(no suite data)")
    }

    return $lines
}

function Get-FrameworkDesignSnippet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DocsRoot
    )

    $path = Join-Path $DocsRoot "framework-design.md"

    if (-not (Test-Path $path)) {
        return @("(framework-design.md not found)")
    }

    $rawLines = Get-Content -Path $path -Encoding UTF8

    $cleanLines = $rawLines |
        ForEach-Object { $_.TrimEnd() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if (-not $cleanLines -or $cleanLines.Count -eq 0) {
        return @("(framework-design.md is empty)")
    }

    $maxLines = 40
    $selected = $cleanLines | Select-Object -First $maxLines

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("FrameworkDesignSnippet:")
    foreach ($line in $selected) {
        $lines.Add($line)
    }

    if ($cleanLines.Count -gt $maxLines) {
        $lines.Add("... (truncated)")
    }

    return $lines
}

function Add-StringLines {
    param(
        [Parameter(Mandatory = $false)]
        $Source
    )

    if ($null -eq $Source) {
        return
    }

    foreach ($item in @($Source)) {
        if ($null -eq $item) {
            continue
        }

        $script:lines.Add([string]$item)
    }
}

function Get-MarkdownSectionBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$HeadingCandidates,

        [int]$MaxLines = 12,

        [int]$MaxChars = 1200
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $lines = Get-Content -Path $Path -Encoding UTF8
    if (-not $lines -or $lines.Count -eq 0) {
        return $null
    }

    $startIndex = -1
    $startLevel = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()

        if ($line -match '^(#{1,6})\s+(.+?)\s*$') {
            $level = $matches[1].Length
            $title = $matches[2].Trim()

            foreach ($candidate in $HeadingCandidates) {
                if ($title -ieq $candidate) {
                    $startIndex = $i
                    $startLevel = $level
                    break
                }
            }

            if ($startIndex -ge 0) {
                break
            }
        }
    }

    if ($startIndex -lt 0) {
        return $null
    }

    $collected = New-Object System.Collections.Generic.List[string]

    for ($j = $startIndex; $j -lt $lines.Count; $j++) {
        $current = $lines[$j]

        if ($j -gt $startIndex) {
            $trimmed = $current.Trim()
            if ($trimmed -match '^(#{1,6})\s+(.+?)\s*$') {
                $nextLevel = $matches[1].Length
                if ($nextLevel -le $startLevel) {
                    break
                }
            }
        }

        $collected.Add($current)

        if ($MaxLines -gt 0 -and $collected.Count -ge $MaxLines) {
            break
        }
    }

    $text = ($collected -join [Environment]::NewLine).Trim()

    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    if ($MaxChars -gt 0 -and $text.Length -gt $MaxChars) {
        $text = $text.Substring(0, $MaxChars).TrimEnd() + [Environment]::NewLine + "..."
    }

    return @($text -split "(`r`n|`n|`r)")
}

function Get-FrameworkDesignSections {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DocsRoot
    )

    $path = Join-Path $DocsRoot "framework-design.md"

    if (-not (Test-Path $path)) {
        return [pscustomobject]@{
            ExecutionFlow = @("## Execution Flow", "build -> run -> response -> compare -> eval -> review -> promote")
            CompareEval   = @("## Compare / Eval", "- compare = evidence", "- eval = interpretation", "- human makes final decision")
            Metadata      = @("## Metadata", "- expectedFormat", "- assertionMode", "- priority", "- changePolicy", "- tags")
            StatusLines   = @("(framework-design.md not found)")
        }
    }

    $executionFlow = Get-MarkdownSectionBlock `
        -Path $path `
        -HeadingCandidates @(
            "Execution Flow",
            "Workflow",
            "Run Flow",
            "Execution"
        ) `
        -MaxLines 10 `
        -MaxChars 800

    $compareEval = Get-MarkdownSectionBlock `
        -Path $path `
        -HeadingCandidates @(
            "Compare / Eval",
            "Compare/Eval",
            "Comparison and Evaluation",
            "Evidence vs Interpretation"
        ) `
        -MaxLines 14 `
        -MaxChars 1000

    $metadata = Get-MarkdownSectionBlock `
        -Path $path `
        -HeadingCandidates @(
            "Metadata",
            "Case Metadata",
            "Policy Metadata"
        ) `
        -MaxLines 14 `
        -MaxChars 1000

    if (-not $executionFlow) {
        $executionFlow = @(
            "## Execution Flow",
            "build -> run -> response -> compare -> eval -> review -> promote"
        )
    }

    if (-not $compareEval) {
        $compareEval = @(
            "## Compare / Eval",
            "- compare = evidence",
            "- eval = interpretation",
            "- human makes final decision"
        )
    }

    if (-not $metadata) {
        $metadata = @(
            "## Metadata",
            "- expectedFormat",
            "- assertionMode",
            "- priority",
            "- changePolicy",
            "- tags"
        )
    }

    $statusLines = New-Object System.Collections.Generic.List[string]
    $statusLines.Add("FrameworkDesignSections:")
    $statusLines.Add(("- Execution Flow: {0}" -f $(if ($executionFlow) { "OK_OR_FALLBACK" } else { "MISSING" })))
    $statusLines.Add(("- Compare / Eval: {0}" -f $(if ($compareEval) { "OK_OR_FALLBACK" } else { "MISSING" })))
    $statusLines.Add(("- Metadata: {0}" -f $(if ($metadata) { "OK_OR_FALLBACK" } else { "MISSING" })))

    return [pscustomobject]@{
        ExecutionFlow = $executionFlow
        CompareEval   = $compareEval
        Metadata      = $metadata
        StatusLines   = $statusLines
    }
}

$repoRoot = Get-RepoRoot

$paths = @{
    runsRoot = Join-Path $repoRoot "runs"
    suitesRoot = Join-Path $repoRoot "tests\suites"
    docsRoot = Join-Path $repoRoot "docs"
}

$latestRunDir = Get-LatestRunDir -RunsRoot $paths.runsRoot
$latestRunLines = Get-LatestRunDetails -RunDir $latestRunDir
$nextActionLines = Get-NextActionLines -RunDir $latestRunDir
$suiteLines = Get-SuiteDetails -SuitesRoot $paths.suitesRoot
$frameworkSections = Get-FrameworkDesignSections -DocsRoot $paths.docsRoot

$taskLine = if ([string]::IsNullOrWhiteSpace($CurrentTask)) {
    "<<ここに今やりたいことを書く>>"
}
else {
    $CurrentTask.Trim()
}

$notesLine = if ([string]::IsNullOrWhiteSpace($Notes)) {
    "(none)"
}
else {
    $Notes.Trim()
}

$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("HANDOFF PROMPT")
$lines.Add("")
$lines.Add("Context:")
$lines.Add("Local prompt regression framework (PowerShell)")
$lines.Add("")
$lines.Add("Goal:")
$lines.Add("Safely evolve prompts without breaking behavior")
$lines.Add("")
$lines.Add("Core Rules:")
$lines.Add("- compare = evidence")
$lines.Add("- eval = interpretation")
$lines.Add("- human makes final decision")
$lines.Add("- backward compatibility preferred")
$lines.Add("- minimal-change updates preferred")
$lines.Add("")
$lines.Add("Prompt Composition:")
$lines.Add("BASE -> SPEC_BASE -> SPEC -> MIGS -> TEST_CASE")
$lines.Add("")
Add-StringLines -Source $frameworkSections.ExecutionFlow

$lines.Add("")

Add-StringLines -Source $frameworkSections.CompareEval

$lines.Add("")

Add-StringLines -Source $frameworkSections.Metadata

$lines.Add("")

Add-StringLines -Source $latestRunLines

$lines.Add("")

Add-StringLines -Source $nextActionLines

$lines.Add("")
$lines.Add("Suites:")

Add-StringLines -Source $suiteLines

$lines.Add("")
$lines.Add("Current Task:")
$lines.Add($taskLine)
$lines.Add("")
$lines.Add("Notes:")
$lines.Add($notesLine)
$lines.Add("")

$content = $lines -join [Environment]::NewLine

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    Write-Output $content
}
else {
    $targetPath = $OutFile

    if (-not [System.IO.Path]::IsPathRooted($targetPath)) {
        $targetPath = Join-Path $repoRoot $targetPath
    }

    Write-Utf8BomFile -Path $targetPath -Content $content
    Write-Output ("Generated: " + $targetPath)
}
