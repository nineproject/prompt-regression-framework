param(
    [Parameter(Mandatory = $true)]
    [string]$Title
)

$migDir = "prompts/mig"
$metaDir = "prompts/mig-meta"

New-Item -ItemType Directory -Path $migDir -Force | Out-Null
New-Item -ItemType Directory -Path $metaDir -Force | Out-Null

$existing = Get-ChildItem $migDir -Filter "*.md" | Select-Object -ExpandProperty BaseName
$nums = @()

foreach ($name in $existing) {
    if ($name -match '^(\d{4})') {
        $nums += [int]$matches[1]
    }
}

$next = if ($nums.Count -eq 0) { 1 } else { ($nums | Measure-Object -Maximum).Maximum + 1 }
$num = "{0:D4}" -f $next
$slug = $Title.ToLower() -replace '[^a-z0-9]+','-' -replace '^-|-$',''

$migPath = Join-Path $migDir "$num-$slug.md"
$metaPath = Join-Path $metaDir "MIG-$num.md"

@"
# $num-$slug

## Intent
...

## Delta
- ...

## Notes
- ...
"@ | Set-Content -Path $migPath -Encoding utf8

@"
# MIG-$num

- Title: $Title
- Status: Proposed
- Related File:
  - prompts/mig/$num-$slug.md

## Rationale
...

## Expected Impact
...
"@ | Set-Content -Path $metaPath -Encoding utf8

Write-Host "Created:"
Write-Host " - $migPath"
Write-Host " - $metaPath"
