#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$repoDir = Split-Path -Parent $PSScriptRoot
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'

function Backup-Path($target) {
    if (Test-Path $target) {
        $dest = "$target`_$timestamp.bkp"
        Write-Host "Backing up $target -> $dest"
        Move-Item -Path $target -Destination $dest -Force
    }
}

function Link-Or-Copy($source, $dest, [switch]$IsDirectory) {
    Backup-Path $dest
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    try {
        $itemType = if ($IsDirectory) { 'SymbolicLink' } else { 'SymbolicLink' }
        New-Item -ItemType $itemType -Path $dest -Target $source -ErrorAction Stop | Out-Null
        Write-Host "Symlinked $dest -> $source"
    } catch {
        Write-Warning "Could not create symlink for $dest (need admin rights or Developer Mode). Falling back to copy."
        Write-Warning "You'll need to re-run this script after 'git pull' to pick up changes."
        if ($IsDirectory) {
            Copy-Item -Path $source -Destination $dest -Recurse -Force
        } else {
            Copy-Item -Path $source -Destination $dest -Force
        }
    }
}

Write-Host '== Classic Vim (vimfiles) =='
New-Item -ItemType Directory -Force -Path "$HOME\vimfiles\backup" | Out-Null
New-Item -ItemType Directory -Force -Path "$HOME\vimfiles\tmp" | Out-Null
Link-Or-Copy "$repoDir\vim\vimrc" "$HOME\_vimrc"
Link-Or-Copy "$repoDir\vim\syntax\html" "$HOME\vimfiles\syntax\html" -IsDirectory

Write-Host '== vim-plug =='
New-Item -ItemType Directory -Force -Path "$HOME\vimfiles\autoload" | Out-Null
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' `
    -OutFile "$HOME\vimfiles\autoload\plug.vim"

Write-Host '== Neovim =='
Link-Or-Copy "$repoDir\nvim" "$env:LOCALAPPDATA\nvim" -IsDirectory

Write-Host '== git =='
Backup-Path "$HOME\.gitconfig"
Copy-Item -Path "$repoDir\gitconfig" -Destination "$HOME\.gitconfig" -Force

if (Get-Command vim -ErrorAction SilentlyContinue) {
    Write-Host '== Installing classic Vim plugins =='
    vim +PlugInstall +qall
}

if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Write-Host '== Installing Neovim plugins =='
    nvim --headless "+Lazy! sync" +qa
}

Write-Host 'Done.'
