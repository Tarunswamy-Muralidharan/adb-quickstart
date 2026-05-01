#!/usr/bin/env bash
# wadb.sh - smart one-click wireless ADB
#
# Phase 1: try last-known phone IP (cached) - no USB needed
# Phase 2: try default gateway (works on phone hotspot) - no USB needed
# Phase 3: fall back to USB-tethered setup (after phone reboot)

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

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wadb"
LAST_IP_FILE="$CACHE_DIR/last_ip"
mkdir -p "$CACHE_DIR"

echo
echo "==============================================="
echo "  Wireless ADB"
echo "==============================================="
echo

adb start-server >/dev/null 2>&1

# ---- Build candidate IP list: cached first, then default gateway ----
candidates=()
if [[ -f "$LAST_IP_FILE" ]]; then
    last_ip=$(<"$LAST_IP_FILE")
    [[ -n "$last_ip" ]] && candidates+=("$last_ip")
fi

# Default gateway (Linux/macOS variants)
gateway=""
if command -v ip >/dev/null 2>&1; then
    gateway=$(ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}')
elif command -v route >/dev/null 2>&1; then
    gateway=$(route -n get default 2>/dev/null | awk '/gateway/ {print $2; exit}')
fi

if [[ -n "$gateway" ]] && [[ ! " ${candidates[*]} " =~ " $gateway " ]]; then
    candidates+=("$gateway")
fi

# ---- Phase 1+2: Try wireless reconnect (no USB) ----
for ip in "${candidates[@]}"; do
    echo "Trying $ip:5555 ..."
    adb connect "$ip:5555" >/dev/null 2>&1 || true
    sleep 1
    if adb devices | grep -q "$ip:5555[[:space:]]\+device"; then
        echo "$ip" > "$LAST_IP_FILE"
        echo
        echo "==============================================="
        echo "  Connected at $ip:5555 (no USB needed)"
        echo "==============================================="
        echo
        adb devices
        exit 0
    fi
    adb disconnect "$ip:5555" >/dev/null 2>&1 || true
done

[[ ${#candidates[@]} -gt 0 ]] && echo "No wireless listener responded." && echo

# ---- Phase 3: USB-required setup ----
echo "Falling back to USB setup (needed after phone reboot)."
echo

PHONE_SERIAL=""
while IFS= read -r line; do
    serial=$(awk '{print $1}' <<<"$line")
    state=$(awk '{print $2}' <<<"$line")
    [[ "$state" == "device" && "$serial" != *:* ]] && { PHONE_SERIAL="$serial"; break; }
done < <(adb devices | tail -n +2)

if [[ -z "$PHONE_SERIAL" ]]; then
    echo "[ERROR] No USB-connected phone found."
    echo
    echo "  - Plug the phone in via USB cable"
    echo "  - Unlock the phone"
    echo "  - Accept the 'Allow USB debugging?' prompt"
    echo "  - Run this script again"
    exit 1
fi

echo "Phone detected on USB: $PHONE_SERIAL"
echo

PHONE_IP=$(adb -s "$PHONE_SERIAL" shell ip -o -4 addr show ap0 2>/dev/null \
    | awk '{print $4}' | cut -d/ -f1 | head -n1 | tr -d '\r')
if [[ -z "$PHONE_IP" ]]; then
    PHONE_IP=$(adb -s "$PHONE_SERIAL" shell ip -o -4 addr show wlan0 2>/dev/null \
        | awk '{print $4}' | cut -d/ -f1 | head -n1 | tr -d '\r')
fi

if [[ -z "$PHONE_IP" ]]; then
    echo "[ERROR] Could not detect phone IP."
    echo "Turn on phone hotspot or connect to WiFi, then run again."
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

adb devices
echo

if adb devices | grep -q "$PHONE_IP:5555[[:space:]]\+device"; then
    echo "$PHONE_IP" > "$LAST_IP_FILE"
    echo "==============================================="
    echo "  SUCCESS - you can unplug the USB cable now."
    echo "  Wireless ADB lives until the phone reboots."
    echo "==============================================="
else
    echo "[WARN] Wireless connection not confirmed. Try running again."
fi
