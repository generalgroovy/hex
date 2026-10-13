@echo off
cd /d "%~dp0"
start "H.E.X." "%~dp0hex.exe" -- --fullbody-art --pixel-cast %*
