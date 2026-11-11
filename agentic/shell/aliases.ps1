# ralph-loop: run the SDD skill's unattended plan -> execute loop script.
# All args are passed through; see `ralph-loop --help`.
function ralph-loop {
    $script = Join-Path $HOME '.ai\skills\gl-lnx-spec-driven-development\scripts\ralph-loop.py'
    if (-not (Test-Path $script)) { Write-Error "ralph-loop: script not found: $script"; return }
    python $script @args
    $global:LASTEXITCODE = $LASTEXITCODE
}

Set-Alias -Name rloop -Value ralph-loop
