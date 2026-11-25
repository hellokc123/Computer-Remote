@echo off
rem Computer Remote installer - no admin needed. Installs only for your Windows account.
setlocal
set "DEST=%LOCALAPPDATA%\ComputerRemote"
echo Installing Computer Remote to %DEST% ...
if not exist "%DEST%" mkdir "%DEST%"
copy /y "%~dp0ComputerRemote.ps1" "%DEST%\" >nul || goto :fail
if not exist "%DEST%\config.json" copy /y "%~dp0config.json" "%DEST%\" >nul
copy /y "%~dp0Pair phone.cmd" "%DEST%\" >nul
copy /y "%~dp0Uninstall.cmd" "%DEST%\" >nul

rem Start automatically when you log in (your own Startup folder, not system-wide)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Startup')+'\Computer Remote.lnk');" ^
  "$s.TargetPath='powershell.exe';" ^
  "$s.Arguments='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%DEST%\ComputerRemote.ps1\"';" ^
  "$s.WindowStyle=7; $s.Description='Computer Remote helper'; $s.Save()" || goto :fail

rem Start it now (hidden)
start "" powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%DEST%\ComputerRemote.ps1"

echo.
echo Found these on your PC:
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\ComputerRemote.ps1" -ListOnly
echo.
echo Done! Opening the pairing page - scan the QR code with your phone camera.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\ComputerRemote.ps1" -Pair
pause
exit /b 0
:fail
echo Something went wrong. Nothing needs admin - try running Install.cmd again.
pause
exit /b 1
