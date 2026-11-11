#Requires -Version 5.1
# Windows environment setup for the agentic (Claude/Codex) tooling.
# Idempotent: only changes things that differ.
#  - ensures PowerShell 7 (pwsh) via winget (skipped if winget is missing)
#  - sets user-scope CLAUDE_CODE_USE_POWERSHELL_TOOL=1
#  - ensures <UserProfile>\.claude\bin is on the user PATH
param(
    [string]$UserProfile = $env:USERPROFILE
)
$ErrorActionPreference = 'Stop'

# 1. PowerShell 7
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Write-Host "unchanged  PowerShell 7: $((Get-Command pwsh).Source)" -ForegroundColor DarkGray
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host 'Installing PowerShell 7 via winget...'
    winget install --id Microsoft.PowerShell --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget install Microsoft.PowerShell failed ($LASTEXITCODE)" }
} else {
    Write-Warning 'pwsh not found and winget unavailable; skipping PowerShell 7 install.'
}

# 2. User env var
$name = 'CLAUDE_CODE_USE_POWERSHELL_TOOL'
$value = '1'
if ([Environment]::GetEnvironmentVariable($name, 'User') -eq $value) {
    Write-Host "unchanged  $name=$value" -ForegroundColor DarkGray
} else {
    [Environment]::SetEnvironmentVariable($name, $value, 'User')
    Write-Host "set        $name=$value" -ForegroundColor Green
}
Set-Item -Path "Env:$name" -Value $value

# 3. User PATH
$binDir = Join-Path $UserProfile '.claude\bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries = @()
if ($userPath) { $entries = $userPath -split ';' | Where-Object { $_ -ne '' } }
$norm = $binDir.TrimEnd('\')
$present = $entries | Where-Object { $_.TrimEnd('\') -ieq $norm }
if ($present) {
    Write-Host "unchanged  PATH contains $binDir" -ForegroundColor DarkGray
} else {
    $new = (@($entries) + $binDir) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
    Write-Host "set        PATH += $binDir" -ForegroundColor Green
}
if (($env:Path -split ';' | ForEach-Object { $_.TrimEnd('\') }) -inotcontains $norm) {
    $env:Path = "$env:Path;$binDir"
}
Write-Host 'Open a new terminal for environment changes to take effect.' -ForegroundColor Yellow
