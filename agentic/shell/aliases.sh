# ralph-loop: run the SDD skill's unattended plan -> execute loop script.
# Sourced from ~/.bashrc / ~/.zshrc (bash and zsh safe). All args are passed
# through; see `ralph-loop --help`.
ralph-loop() {
  local script="$HOME/.ai/skills/gl-lnx-spec-driven-development/scripts/ralph-loop.py"
  local py
  if [ ! -f "$script" ]; then
    echo "ralph-loop: script not found: $script" >&2
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    py=python3
  elif command -v python >/dev/null 2>&1; then
    py=python
  else
    echo "ralph-loop: python3/python not found on PATH" >&2
    return 1
  fi
  "$py" "$script" "$@"
}

alias rloop=ralph-loop
