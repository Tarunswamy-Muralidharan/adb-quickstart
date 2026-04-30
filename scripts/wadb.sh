#!/usr/bin/env bash
# wadb.sh - one-click wireless ADB setup
#
# Plug your Android phone via USB, run this script, unplug when it
# says "SUCCESS". Wireless ADB will be live until the phone reboots.

set -uo pipefail

if ! command -v adb >/dev/null 2>&1; then
    echo "[ERROR] adb is not installed or not on PATH."
    echo
    echo "Install Android platform-tools first:"
    echo "  macOS:    brew install android-platform-tools"
    echo "  Ubuntu:   sudo apt install adb"
    echo "  Arch:     sudo pacman -S android-tools"
    exit 1
fi

echo
echo "==============================================="
echo "  Wireless ADB Setup"
echo "==============================================="
echo

adb start-server >/dev/null 2>&1

# Find a USB-connected phone (serial NOT in IP:port form)
PHONE_SERIAL=""
while IFS= read -r line; do
    serial=$(awk '{print $1}' <<<"$line")
    state=$(awk '{print $2}' <<<"$line")
    [[ "$state" == "device" && "$serial" != *:* ]] && { PHONE_SERIAL="$serial"; break; }
done < <(adb devices | tail -n +2)

if [[ -z "$PHONE_SERIAL" ]]; then
    echo "[ERROR] No USB-connected phone found."
    echo
    echo "  - Plug the phone in with the USB cable."
    echo "  - Unlock the phone."
    echo "  - Accept the 'Allow USB debugging?' prompt."
    echo "  - Run this script again."
    exit 1
fi

echo "Phone detected on USB: $PHONE_SERIAL"
echo

# Read phone IP - try ap0 (hotspot) first, then wlan0 (WiFi client)
PHONE_IP=$(adb -s "$PHONE_SERIAL" shell ip -o -4 addr show ap0 2>/dev/null \
    | awk '{print $4}' | cut -d/ -f1 | head -n1 | tr -d '\r')
if [[ -z "$PHONE_IP" ]]; then
    PHONE_IP=$(adb -s "$PHONE_SERIAL" shell ip -o -4 addr show wlan0 2>/dev/null \
        | awk '{print $4}' | cut -d/ -f1 | head -n1 | tr -d '\r')
fi

if [[ -z "$PHONE_IP" ]]; then
    echo "[ERROR] Could not detect phone IP."
    echo "  - Turn on phone hotspot, OR"
    echo "  - Connect phone to a WiFi network,"
    echo "  then run this script again."
    exit 1
fi

echo "Phone IP: $PHONE_IP"
echo

echo "Switching phone adbd to TCP/IP mode (port 5555)..."
adb -s "$PHONE_SERIAL" tcpip 5555
sleep 2

echo "Connecting to $PHONE_IP:5555 ..."
adb connect "$PHONE_IP:5555"
echo

echo "Current ADB devices:"
adb devices
echo

if adb devices | grep -q "$PHONE_IP:5555\s*device"; then
    echo "==============================================="
    echo "  SUCCESS - you can unplug the USB cable now."
    echo "  Wireless ADB lives until the phone reboots."
    echo "==============================================="
else
    echo "[WARN] Wireless connection not confirmed. Try running again."
fi
