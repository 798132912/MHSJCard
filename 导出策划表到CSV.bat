@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\export_excel_to_csv.ps1"
if errorlevel 1 (
  echo.
  echo Export failed. Check the error messages above.
  pause
  exit /b 1
)
echo.
echo Export completed.
pause
