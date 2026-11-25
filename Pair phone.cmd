@echo off
rem Shows the QR code again so you can pair another phone.
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ComputerRemote\ComputerRemote.ps1" -Pair
