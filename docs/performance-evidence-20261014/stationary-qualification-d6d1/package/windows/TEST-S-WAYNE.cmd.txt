@echo off
cd /d "%~dp0"
start "H.E.X. movement test" "%~dp0hex.exe" -- --fullbody-art --pixel-cast --champion=s_wayne %*
