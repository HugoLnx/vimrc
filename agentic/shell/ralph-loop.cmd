@echo off
set "RL_SCRIPT=%USERPROFILE%\.ai\skills\gl-lnx-spec-driven-development\scripts\ralph-loop.py"
if not exist "%RL_SCRIPT%" (
  echo ralph-loop: script not found: %RL_SCRIPT% 1>&2
  exit /b 1
)
python "%RL_SCRIPT%" %*
exit /b %ERRORLEVEL%
