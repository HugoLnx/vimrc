#Requires -Version 5.1
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
    Write-Host "Edit $configPath if you want to sync other homes (e.g. a WSL Linux home)."
}

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) {
    Write-Error 'python is required. Install it (e.g. from python.org or the Microsoft Store) and re-run this script.'
    exit 1
}

Write-Host '== Symlinking config =='
& $python.Source (Join-Path $repoDir 'install\symlink.py')

Write-Host '== vim-plug =='
New-Item -ItemType Directory -Force -Path "$HOME\vimfiles\autoload" | Out-Null
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' `
    -OutFile "$HOME\vimfiles\autoload\plug.vim"

if (Get-Command vim -ErrorAction SilentlyContinue) {
    Write-Host '== Installing classic Vim plugins =='
    vim +PlugInstall +qall
}

if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Write-Host '== Installing Neovim plugins =='
    nvim --headless "+Lazy! sync" +qa
}

Write-Host 'Done.'
