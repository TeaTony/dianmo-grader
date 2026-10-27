@echo off
setlocal EnableExtensions

cd /d "%~dp0"
set "APP_DIR=%~dp0"
set "NODE_EXE=%APP_DIR%runtime\node\node.exe"
set "SERVER_JS=%APP_DIR%server.js"
set "LOG=%APP_DIR%startup-log.txt"

> "%LOG%" echo Dianmo startup log
>> "%LOG%" echo Time: %DATE% %TIME%
>> "%LOG%" echo Folder: %APP_DIR%
>> "%LOG%" echo Architecture: %PROCESSOR_ARCHITECTURE% / %PROCESSOR_ARCHITEW6432%

echo.
echo ================================================
echo   Dianmo Essay Grader
echo ================================================
echo.

if /I "%PROCESSOR_ARCHITECTURE%"=="x86" if not defined PROCESSOR_ARCHITEW6432 (
  echo ERROR: This package requires 64-bit Windows.
  >> "%LOG%" echo ERROR: 32-bit Windows is not supported by the bundled runtime.
  goto failed
)

if not exist "%NODE_EXE%" (
  echo ERROR: Missing runtime\node\node.exe
  >> "%LOG%" echo ERROR: Missing runtime\node\node.exe
  goto failed
)

if not exist "%SERVER_JS%" (
  echo ERROR: Missing server.js
  >> "%LOG%" echo ERROR: Missing server.js
  goto failed
)

if not exist "%APP_DIR%data" mkdir "%APP_DIR%data" 2>nul
echo test> "%APP_DIR%data\.write_test" 2>nul
if not exist "%APP_DIR%data\.write_test" (
  echo ERROR: The data folder is not writable.
  echo Move this folder to Desktop or Documents and try again.
  >> "%LOG%" echo ERROR: The data folder is not writable.
  goto failed
)
del "%APP_DIR%data\.write_test" >nul 2>nul

"%NODE_EXE%" --version > "%APP_DIR%node-version.tmp" 2>> "%LOG%"
if errorlevel 1 (
  echo ERROR: The bundled Node.js runtime cannot run on this PC.
  echo This may be caused by antivirus blocking node.exe or an unsupported Windows version.
  >> "%LOG%" echo ERROR: node.exe failed to start.
  goto failed
)
set /p NODE_VERSION=<"%APP_DIR%node-version.tmp"
del "%APP_DIR%node-version.tmp" >nul 2>nul
>> "%LOG%" echo Node.js: %NODE_VERSION%

echo Starting Dianmo...
echo Browser: http://127.0.0.1:8787
echo Keep this window open while using Dianmo.
echo Press Ctrl+C to stop.
echo.
>> "%LOG%" echo Starting server...
start "" /b powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Milliseconds 1800; Start-Process 'http://127.0.0.1:8787'"
"%NODE_EXE%" "%SERVER_JS%" >> "%LOG%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"
>> "%LOG%" echo Server exited with code %EXIT_CODE%.

echo.
echo Dianmo has stopped. Exit code: %EXIT_CODE%
if not "%EXIT_CODE%"=="0" (
  echo.
  echo Startup details:
  type "%LOG%"
)
echo.
pause
exit /b %EXIT_CODE%

:failed
echo.
echo Startup failed. Details were written to:
echo %LOG%
echo.
type "%LOG%"
echo.
pause
exit /b 1
