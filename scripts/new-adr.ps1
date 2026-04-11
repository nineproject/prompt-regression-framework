param(
    [Parameter(Mandatory = $true)]
    [string]$Title
)

$adrDir = "prompts/spec/ADR"
if (!(Test-Path $adrDir)) {
    New-Item -ItemType Directory -Path $adrDir -Force | Out-Null
}

$existing = Get-ChildItem $adrDir -Filter "ADR-*.md" | Select-Object -ExpandProperty Name
$nums = @()

foreach ($name in $existing) {
    if ($name -match '^ADR-(\d{4})') {
        $nums += [int]$matches[1]
    }
}

$next = if ($nums.Count -eq 0) { 1 } else { ($nums | Measure-Object -Maximum).Maximum + 1 }
$id = ("ADR-{0:D4}" -f $next)
$slug = $Title.ToLower() -replace '[^a-z0-9]+','-' -replace '^-|-$',''
$path = Join-Path $adrDir "$id-$slug.md"

@"
# $id $slug

## Status
Proposed

## Context
...

## Decision
...

## Alternatives Considered
...

## Consequences
...
"@ | Set-Content -Path $path -Encoding utf8

Write-Host "Created: $path"
