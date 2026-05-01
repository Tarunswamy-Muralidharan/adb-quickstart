@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  Wireless ADB - smart one-click
REM
REM  Behavior:
REM    Phase 1: Try last-known phone IP (cached). No USB needed.
REM    Phase 2: Try default gateway (phone hotspot). No USB needed.
REM    Phase 3: Fall back to USB-tethered setup (after phone reboot).
REM
REM  Re-points to a fresh wireless connection in 1-2s if the phone
REM  is still listening; only requires USB after a phone reboot.
REM ============================================================

REM ---- Locate adb on PATH ----
set "ADB="
for /f "delims=" %%i in ('where adb 2^>nul') do (
    if not defined ADB set "ADB=%%i"
)

if not defined ADB (
    echo [ERROR] adb not found on PATH.
    echo Install Android platform-tools first:
    echo   winget install Google.PlatformTools
    echo Then close this window and reopen your terminal.
    pause
    exit /b 1
)

set "CACHE_DIR=%LOCALAPPDATA%\wadb"
set "LAST_IP_FILE=%CACHE_DIR%\last_ip.txt"
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>&1

echo.
echo ===============================================
echo   Wireless ADB
echo ===============================================
echo.

"%ADB%" start-server >nul 2>nul

REM ---- Build candidate IP list: cached first, then default gateway ----
set "CANDIDATES="
if exist "%LAST_IP_FILE%" (
    for /f "usebackq" %%i in ("%LAST_IP_FILE%") do (
        if not defined CANDIDATES set "CANDIDATES=%%i"
    )
)

set "GW="
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop"') do (
    set "GW=%%i"
)

if defined GW (
    if not "!GW!"=="!CANDIDATES!" (
        if defined CANDIDATES (
            set "CANDIDATES=!CANDIDATES! !GW!"
        ) else (
            set "CANDIDATES=!GW!"
        )
    )
)

REM ---- Phase 1+2: Try wireless reconnect (no USB) ----
if defined CANDIDATES (
    for %%c in (!CANDIDATES!) do (
        echo Trying %%c:5555 ...
        "%ADB%" connect %%c:5555 >nul 2>&1
        ping 127.0.0.1 -n 2 >nul
        "%ADB%" devices | findstr /c:"%%c:5555" | findstr /c:"device" >nul
        if not errorlevel 1 (
            echo %%c> "%LAST_IP_FILE%"
            echo.
            echo ===============================================
            echo   Connected at %%c:5555 ^(no USB needed^)
            echo ===============================================
            echo.
            "%ADB%" devices
            echo.
            pause
            exit /b 0
        )
        "%ADB%" disconnect %%c:5555 >nul 2>&1
    )
    echo No wireless listener responded.
    echo.
)

REM ---- Phase 3: USB-required setup ----
echo Falling back to USB setup ^(needed after phone reboot^).
echo.

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
    echo  - Plug the phone in with the USB cable
    echo  - Unlock the phone
    echo  - Accept the "Allow USB debugging?" prompt
    echo  - Run this script again
    echo.
    pause
    exit /b 1
)

echo Phone detected on USB: %PHONE_SERIAL%
echo.

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
    echo Turn on phone hotspot or connect to WiFi, then run again.
    pause
    exit /b 1
)

echo Phone IP: %PHONE_IP%
echo.
echo Switching phone adbd to TCP/IP mode (port 5555)...
"%ADB%" -s %PHONE_SERIAL% tcpip 5555
ping 127.0.0.1 -n 3 >nul

echo Connecting to %PHONE_IP%:5555 ...
"%ADB%" connect %PHONE_IP%:5555
echo.

"%ADB%" devices
echo.

"%ADB%" devices | findstr /c:"%PHONE_IP%:5555" | findstr /c:"device" >nul
if errorlevel 1 (
    echo [WARN] Wireless connection not confirmed. Try running this script again.
) else (
    echo %PHONE_IP%> "%LAST_IP_FILE%"
    echo ===============================================
    echo   SUCCESS - you can unplug the USB cable now.
    echo   Wireless ADB lives until the phone reboots.
    echo ===============================================
)

echo.
pause
endlocal
