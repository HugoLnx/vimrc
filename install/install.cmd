@echo off
rem Pass PowerShell-style arguments through, e.g. -Labels agentic -Skip vim-plugins -DryRun.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
exit /b %ERRORLEVEL%
