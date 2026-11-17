@echo off
setlocal
cd /d "%~dp0"
call flutter pub get
if errorlevel 1 goto failed
call flutter run %*
if errorlevel 1 goto failed
exit /b 0
:failed
echo Flutter could not complete the command. Review the error above.
pause
exit /b 1
