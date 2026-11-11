#Requires -Version 5.1
param(
    [string[]]$Labels = @(),
    [string[]]$Skip = @(),
    [switch]$DryRun,
    [switch]$Check,
    [switch]$List
)

$ErrorActionPreference = 'Stop'

$repoDir = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoDir 'config.yml'

if (-not (Test-Path $configPath)) {
    Write-Host '== Creating config.yml from _config.sample.yml =='
    @"
homes:
  - os: windows
    path: "~"
"@ | Set-Content -Path $configPath
    Write-Host "Edit $configPath to customize labels or your current OS home."
}

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) {
    Write-Error 'python is required. Install it (e.g. from python.org or the Microsoft Store) and re-run this script.'
    exit 1
}

& $python.Source -c 'import yaml'
if ($LASTEXITCODE -ne 0) {
    Write-Error 'PyYAML is required. Install it with: python -m pip install PyYAML'
    exit 1
}

$argv = @()
$argv += $Labels
if ($Skip.Count -gt 0) { $argv += '--skip'; $argv += $Skip }
if ($DryRun) { $argv += '--dry-run' }
if ($Check) { $argv += '--check' }
if ($List) { $argv += '--list' }

& $python.Source (Join-Path $repoDir 'install\enforce.py') @argv
exit $LASTEXITCODE
