$today = Get-Date -Format "yyyy-MM-dd"
$runsDir = "runs"

New-Item -ItemType Directory -Path $runsDir -Force | Out-Null

$existing = Get-ChildItem $runsDir -Filter "${today}_run*.md" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty BaseName

$nums = @()

foreach ($name in $existing) {
    if ($name -match '_run(\d{2})$') {
        $nums += [int]$matches[1]
    }
}

if ($nums.Count -eq 0) {
    $next = 1
}
else {
    $next = ([int](($nums | Measure-Object -Maximum).Maximum)) + 1
}

$runNo = "{0:D2}" -f ([int]$next)
$runId = "${today}_run$runNo"

$path = Join-Path $runsDir "$runId.md"

@"
# Run: $runId

## Metadata
- Date: $today
- RunId: $runId
- Base: BASE_v2
- Migrations:

## Cases

## Outputs

## Notes
"@ | Set-Content -Path $path -Encoding utf8

Write-Host $runId
Write-Host "Created: $path"
