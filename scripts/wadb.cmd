@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  Wireless ADB - one-click setup
REM
REM  Plug your Android phone via USB, double-click this file,
REM  unplug when it says "SUCCESS." Wireless ADB will be live
REM  until the phone reboots.
REM ============================================================

REM ---- Locate adb on PATH (winget link, manual install, etc.) ----
set "ADB="
for /f "delims=" %%i in ('where adb 2^>nul') do (
    if not defined ADB set "ADB=%%i"
)

if not defined ADB (
    echo [ERROR] adb is not installed or not on PATH.
    echo.
    echo Install Android platform-tools first:
    echo   winget install Google.PlatformTools
    echo Then close this window, open a new terminal, and run again.
    echo.
    pause
    exit /b 1
)

echo.
echo ===============================================
echo   Wireless ADB Setup
echo ===============================================
echo.

"%ADB%" start-server >nul 2>nul

REM ---- Find a USB-connected phone (serial NOT in IP:port form) ----
set "PHONE_SERIAL="
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices') do (
    if "%%b"=="device" (
        echo %%a | findstr /c:":" >nul
        if errorlevel 1 set "PHONE_SERIAL=%%a"
    )
)

if not defined PHONE_SERIAL (
    echo [ERROR] No USB-connected phone found.
    echo.
    echo  - Plug the phone in with the USB cable.
    echo  - Unlock the phone.
    echo  - Accept the "Allow USB debugging?" prompt.
    echo  - Run this script again.
    echo.
    pause
    exit /b 1
)

echo Phone detected on USB: %PHONE_SERIAL%
echo.

REM ---- Read phone IP: try ap0 (hotspot) first, then wlan0 (WiFi) ----
set "PHONE_IP="
for /f "tokens=4" %%i in ('"%ADB%" -s %PHONE_SERIAL% shell ip -o -4 addr show ap0 2^>nul') do (
    if not defined PHONE_IP set "PHONE_IP=%%i"
)
for /f "tokens=1 delims=/" %%i in ("%PHONE_IP%") do set "PHONE_IP=%%i"

if not defined PHONE_IP (
    for /f "tokens=4" %%i in ('"%ADB%" -s %PHONE_SERIAL% shell ip -o -4 addr show wlan0 2^>nul') do (
        if not defined PHONE_IP set "PHONE_IP=%%i"
    )
    for /f "tokens=1 delims=/" %%i in ("%PHONE_IP%") do set "PHONE_IP=%%i"
)

if not defined PHONE_IP (
    echo [ERROR] Could not detect phone IP.
    echo  - Turn on phone hotspot, OR
    echo  - Connect phone to a WiFi network,
    echo  then run this script again.
    echo.
    pause
    exit /b 1
)

echo Phone IP: %PHONE_IP%
echo.

REM ---- Flip adbd to TCP/IP mode on port 5555 ----
echo Switching phone adbd to TCP/IP mode (port 5555)...
"%ADB%" -s %PHONE_SERIAL% tcpip 5555
timeout /t 2 /nobreak >nul

echo Connecting to %PHONE_IP%:5555 ...
"%ADB%" connect %PHONE_IP%:5555
echo.

echo Current ADB devices:
"%ADB%" devices
echo.

"%ADB%" devices | findstr /c:"%PHONE_IP%:5555" | findstr /c:"device" >nul
if errorlevel 1 (
    echo [WARN] Wireless connection not confirmed. Try running this script again.
) else (
    echo ===============================================
    echo   SUCCESS - you can unplug the USB cable now.
    echo   Wireless ADB lives until the phone reboots.
    echo ===============================================
)

echo.
pause
endlocal
