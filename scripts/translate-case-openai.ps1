param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [Parameter(Mandatory = $false)]
    [string]$Model = "gpt-5.1-mini"
)

$caseDir = Join-Path "tests/cases" $CaseId
$inputPath = Join-Path $caseDir "case.md"
$outputPath = Join-Path $caseDir "case.en.md"

if (-not (Test-Path $inputPath)) {
    throw "case.md not found: $inputPath"
}

if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
    throw "OPENAI_API_KEY is not set."
}

$content = Get-Content $inputPath -Raw -Encoding UTF8

$instructions = @"
You are a professional technical translator.

Translate the user's Japanese prompt specification into natural, professional English.

Rules:
- Keep the same Markdown structure.
- Do not change meaning.
- Do not add or remove requirements.
- Preserve code blocks exactly.
- Preserve file paths, case IDs, commands, JSON keys, and technical identifiers.
- Output only the translated Markdown.
"@

$body = @{
    model = $Model
    instructions = $instructions
    input = $content
} | ConvertTo-Json -Depth 20

$response = Invoke-RestMethod `
    -Uri "https://api.openai.com/v1/responses" `
    -Method Post `
    -Headers @{
        "Authorization" = "Bearer $env:OPENAI_API_KEY"
        "Content-Type"  = "application/json"
    } `
    -Body $body

# Responses API text extraction
$outputText = $response.output_text

if ([string]::IsNullOrWhiteSpace($outputText)) {
    throw "No output_text returned from OpenAI API."
}

Set-Content -Path $outputPath -Value $outputText -Encoding UTF8

Write-Host "Generated: $outputPath"
