[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Try-ReadJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return @{
                Success = $false
                Error = "JSON file is empty."
                Data = $null
            }
        }

        $json = $raw | ConvertFrom-Json
        return @{
            Success = $true
            Error = $null
            Data = $json
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Data = $null
        }
    }
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Type,
        [string]$Path,
        [string]$Message
    )

    $Issues.Add([pscustomobject]@{
        Type = $Type
        Path = $Path
        Message = $Message
    })
}

function Get-SuiteFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuitesRoot
    )

    $files = New-Object System.Collections.Generic.List[string]

    if (!(Test-Path $SuitesRoot)) {
        return $files
    }

    $rootJsonFiles = Get-ChildItem -LiteralPath $SuitesRoot -File -Filter *.json -ErrorAction SilentlyContinue
    foreach ($file in $rootJsonFiles) {
        $files.Add($file.FullName)
    }

    $suiteJsonFiles = Get-ChildItem -LiteralPath $SuitesRoot -Recurse -File -Filter suite.json -ErrorAction SilentlyContinue
    foreach ($file in $suiteJsonFiles) {
        $files.Add($file.FullName)
    }

    return $files | Select-Object -Unique
}

$repoRoot = Get-RepoRoot
$testsRoot = Join-Path $repoRoot "tests"
$casesRoot = Join-Path $testsRoot "cases"
$baselinesRoot = Join-Path $testsRoot "baselines"
$suitesRoot = Join-Path $testsRoot "suites"

$issues = New-Object System.Collections.Generic.List[object]

Write-Host ""
Write-Host "===== VALIDATE REPO START ====="

# --------------------------------------------------
# 1. Validate cases
# --------------------------------------------------
if (!(Test-Path $casesRoot)) {
    Add-Issue -Issues $issues -Type "ERROR" -Path $casesRoot -Message "tests/cases directory not found."
}
else {
    $caseDirs = Get-ChildItem -LiteralPath $casesRoot -Directory | Where-Object { $_.Name -match '^TC-\d{4}$' }

    foreach ($caseDir in $caseDirs) {
        $caseMd = Join-Path $caseDir.FullName "case.md"
        $metaJson = Join-Path $caseDir.FullName "meta.json"

        if (!(Test-Path $caseMd)) {
            Add-Issue -Issues $issues -Type "ERROR" -Path $caseMd -Message "case.md is missing."
        }

        if (!(Test-Path $metaJson)) {
            Add-Issue -Issues $issues -Type "ERROR" -Path $metaJson -Message "meta.json is missing."
        }
        else {
            $metaResult = Try-ReadJsonFile -Path $metaJson
            if (-not $metaResult.Success) {
                Add-Issue -Issues $issues -Type "ERROR" -Path $metaJson -Message ("Invalid JSON: " + $metaResult.Error)
            }
            else {
                $meta = $metaResult.Data

                if ([string]::IsNullOrWhiteSpace($meta.title)) {
                    Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message "title is missing or empty."
                }

                if (-not [string]::IsNullOrWhiteSpace($meta.expectedFormat)) {
                    $allowedFormats = @("text", "json", "markdown", "none")
                    if ($allowedFormats -notcontains $meta.expectedFormat) {
                        Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message ("unexpected expectedFormat: " + $meta.expectedFormat)
                    }
                }

                if (-not [string]::IsNullOrWhiteSpace($meta.assertionMode)) {
                    $allowedAssertionModes = @("strict", "flexible")
                    if ($allowedAssertionModes -notcontains $meta.assertionMode) {
                        Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message ("unexpected assertionMode: " + $meta.assertionMode)
                    }
                }
                else {
                    Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message "assertionMode is missing or empty."
                }

                if (-not [string]::IsNullOrWhiteSpace($meta.priority)) {
                    $allowedPriorities = @("high", "medium", "low")
                    if ($allowedPriorities -notcontains $meta.priority) {
                        Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message ("unexpected priority: " + $meta.priority)
                    }
                }
                else {
                    Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message "priority is missing or empty."
                }

                if (-not [string]::IsNullOrWhiteSpace($meta.changePolicy)) {
                    $allowedChangePolicies = @("low-drift", "moderate-drift", "high-drift")
                    if ($allowedChangePolicies -notcontains $meta.changePolicy) {
                        Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message ("unexpected changePolicy: " + $meta.changePolicy)
                    }
                }
                else {
                    Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message "changePolicy is missing or empty."
                }

                if ($null -eq $meta.tags) {
                    Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message "tags is missing."
                }
                elseif ($meta.tags -isnot [System.Array]) {
                    Add-Issue -Issues $issues -Type "ERROR" -Path $metaJson -Message "tags must be an array."
                }
                elseif (@($meta.tags).Count -eq 0) {
                    Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message "tags is empty."
                }

                if ($null -ne $meta.relatedMigs) {
                    foreach ($mig in @($meta.relatedMigs)) {
                        if ($mig -notmatch '^MIG-\d{4}$') {
                            Add-Issue -Issues $issues -Type "WARN" -Path $metaJson -Message ("invalid relatedMigs entry: " + $mig)
                        }
                    }
                }
            }
        }
    }
}

# --------------------------------------------------
# 2. Validate baselines
# --------------------------------------------------
if (Test-Path $baselinesRoot) {
    $baselineFiles = Get-ChildItem -LiteralPath $baselinesRoot -File -Filter *.json

    foreach ($baselineFile in $baselineFiles) {
        $baselineResult = Try-ReadJsonFile -Path $baselineFile.FullName
        if (-not $baselineResult.Success) {
            Add-Issue -Issues $issues -Type "ERROR" -Path $baselineFile.FullName -Message ("Invalid JSON: " + $baselineResult.Error)
            continue
        }

        $baseline = $baselineResult.Data

        if ([string]::IsNullOrWhiteSpace($baseline.caseId)) {
            Add-Issue -Issues $issues -Type "ERROR" -Path $baselineFile.FullName -Message "caseId is missing."
        }
        else {
            $casePath = Join-Path $casesRoot $baseline.caseId
            if (!(Test-Path $casePath)) {
                Add-Issue -Issues $issues -Type "ERROR" -Path $baselineFile.FullName -Message ("referenced case directory not found: " + $baseline.caseId)
            }
        }

        if ([string]::IsNullOrWhiteSpace($baseline.baselineRunId)) {
            Add-Issue -Issues $issues -Type "ERROR" -Path $baselineFile.FullName -Message "baselineRunId is missing."
        }
        else {
            $runPath = Join-Path $repoRoot ("runs/" + $baseline.baselineRunId)
            if (!(Test-Path $runPath)) {
                Add-Issue -Issues $issues -Type "ERROR" -Path $baselineFile.FullName -Message ("referenced run directory not found: " + $baseline.baselineRunId)
            }
        }
    }
}
else {
    Write-Host "INFO: tests/baselines not found. Skipping baseline validation."
}

# --------------------------------------------------
# 3. Validate suites
# --------------------------------------------------
if (Test-Path $suitesRoot) {
    $suiteFiles = Get-SuiteFiles -SuitesRoot $suitesRoot

    foreach ($suiteFile in $suiteFiles) {
        $suiteResult = Try-ReadJsonFile -Path $suiteFile
        if (-not $suiteResult.Success) {
            Add-Issue -Issues $issues -Type "ERROR" -Path $suiteFile -Message ("Invalid JSON: " + $suiteResult.Error)
            continue
        }

        $suite = $suiteResult.Data

        if ([string]::IsNullOrWhiteSpace($suite.id)) {
            Add-Issue -Issues $issues -Type "WARN" -Path $suiteFile -Message "suite id is missing."
        }

        if ($null -eq $suite.caseIds -or @($suite.caseIds).Count -eq 0) {
            Add-Issue -Issues $issues -Type "WARN" -Path $suiteFile -Message "caseIds is missing or empty."
            continue
        }

        foreach ($caseId in @($suite.caseIds)) {
            if ($caseId -notmatch '^TC-\d{4}$') {
                Add-Issue -Issues $issues -Type "WARN" -Path $suiteFile -Message ("invalid caseIds entry: " + $caseId)
                continue
            }

            $casePath = Join-Path $casesRoot $caseId
            if (!(Test-Path $casePath)) {
                Add-Issue -Issues $issues -Type "ERROR" -Path $suiteFile -Message ("referenced case directory not found: " + $caseId)
            }
        }
    }
}
else {
    Write-Host "INFO: tests/suites not found. Skipping suite validation."
}

# --------------------------------------------------
# 4. Summary
# --------------------------------------------------
$errors = @($issues | Where-Object { $_.Type -eq "ERROR" })
$warnings = @($issues | Where-Object { $_.Type -eq "WARN" })

Write-Host ""
Write-Host "===== VALIDATE REPO SUMMARY ====="
Write-Host ("Errors   : {0}" -f $errors.Count)
Write-Host ("Warnings : {0}" -f $warnings.Count)
Write-Host ""

foreach ($issue in $issues) {
    Write-Host ("[{0}] {1}" -f $issue.Type, $issue.Message)
    Write-Host ("       {0}" -f $issue.Path)
}

Write-Host ""

if ($errors.Count -gt 0) {
    throw "Repository validation failed."
}
else {
    Write-Host "Repository validation passed."
}
