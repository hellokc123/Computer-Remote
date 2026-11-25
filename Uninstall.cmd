@echo off
rem Stops Computer Remote and removes it from startup. Your files in the folder stay until you delete them.
echo Stopping Computer Remote...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*ComputerRemote.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Computer Remote.lnk" 2>nul
echo Removed from startup. You can now delete the folder %LOCALAPPDATA%\ComputerRemote
pause
