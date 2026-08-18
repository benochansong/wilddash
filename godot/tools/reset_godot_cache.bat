@echo off
setlocal
title WILD DASH - Reset Godot Project Cache

echo [WILD DASH] Godot project cache reset
echo.

tasklist | findstr /I "Godot" >nul
if %errorlevel%==0 (
  echo Godot is currently running.
  echo Close every Godot editor/game window, then run this file again.
  echo.
  pause
  exit /b 2
)

set "CACHE_DIR=%~dp0..\.godot"

if exist "%CACHE_DIR%" (
  echo Removing cache only:
  echo %CACHE_DIR%
  rmdir /s /q "%CACHE_DIR%"
  if exist "%CACHE_DIR%" (
    echo.
    echo FAILED: the cache folder could not be removed.
    echo Check file permissions and make sure Godot is fully closed.
    pause
    exit /b 3
  )
  echo.
  echo Cache removed successfully.
) else (
  echo No .godot cache folder exists. Nothing needed removal.
)

echo.
echo Source files, assets and saves were not touched.
echo Reopen godot\project.godot and let Godot re-import the project.
echo Then open Character Select and press START once.
echo.
pause
exit /b 0
