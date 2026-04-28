param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId
)

$caseDir = Join-Path "tests/cases" $CaseId
$inputPath = Join-Path $caseDir "case.md"
$outputPath = Join-Path $caseDir "case.en.md"

if (-not (Test-Path $inputPath)) {
    throw "case.md not found: $inputPath"
}

$content = Get-Content $inputPath -Raw -Encoding UTF8

$prompt = @"
You are a professional technical translator.

Translate the following Japanese prompt specification into natural, professional English.

Rules:
- Keep structure (headings, lists)
- Do NOT change meaning
- Do NOT add or remove content
- Preserve code blocks exactly
- Keep formatting identical

--- INPUT ---
$content
--- OUTPUT ---
"@

Write-Host "=== Translating $CaseId ==="

$output = $prompt  # Normally, the LLM call goes here

Set-Content -Path $outputPath -Value $output -Encoding UTF8

Write-Host "Generated: $outputPath"
