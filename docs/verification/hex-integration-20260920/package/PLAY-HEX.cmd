@echo off
cd /d "%~dp0"
start "HEX" "%~dp0hex.exe" -- %*
