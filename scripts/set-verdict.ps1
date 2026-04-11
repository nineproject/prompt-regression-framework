param(
    [Parameter(Mandatory = $true)]
    [string]$RunDate,

    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("PASS", "FAIL", "PENDING")]
    [string]$Result
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$scriptDir = $PSScriptRoot
$repoRoot  = Split-Path $scriptDir -Parent

$evalDateDir = Join-Path $repoRoot "evals\$RunDate"
if (!(Test-Path $evalDateDir)) {
    Write-Error "Eval date directory not found: $evalDateDir"
    exit 1
}

$evalPath = Join-Path $evalDateDir "$CaseId.md"
if (!(Test-Path $evalPath)) {
    Write-Error "Eval file not found: $evalPath"
    exit 1
}

$content = Get-Content $evalPath -Raw -Encoding UTF8

if ($content -match '(?m)^- Verdict:\s*(PASS|FAIL|PENDING)\s*$') {
    $updated = [System.Text.RegularExpressions.Regex]::Replace(
        $content,
        '(?m)^- Verdict:\s*(PASS|FAIL|PENDING)\s*$',
        "- Verdict: $Result"
    )
}
else {
    Write-Error "Verdict line not found in eval file: $evalPath"
    exit 1
}

Set-Content -Path $evalPath -Value $updated -Encoding UTF8

Write-Host "Verdict updated:"
Write-Host $evalPath
Write-Host "Result: $Result"

exit 0
