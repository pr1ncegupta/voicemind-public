#!/bin/bash
# VoiceMind Launch Script — kills stale servers, detects IP, starts fresh
# Usage: ./run.sh [ios|web|android|macos]   (or run with no args for interactive menu)

set -e
cd "$(dirname "$0")"

# Colors
G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' B='\033[1;34m' NC='\033[0m'

# ── 0. Interactive target selection (when no arg given) ──────────────
if [ -z "$1" ]; then
  echo -e "${B}╔══════════════════════════════╗${NC}"
  echo -e "${B}║     VoiceMind Launcher       ║${NC}"
  echo -e "${B}╚══════════════════════════════╝${NC}"
  echo ""
  echo "  1) 📱  Phone (iOS — wired iPhone)"
  echo "  2) 🌐  Web   (Chrome)"
  echo "  3) 🤖  Android"
  echo "  4) 🖥️  macOS  (Desktop)"
  echo ""
  read -p "Choose target [1/2/3/4]: " target_choice
  case "$target_choice" in
    2) TARGET="web" ;;
    3) TARGET="android" ;;
    4) TARGET="macos" ;;
    *) TARGET="ios" ;;
  esac
else
  TARGET="${1}"
fi

# ── 1. Kill previous servers ────────────────────────────────────────
echo -e "${C}🔄 Cleaning up previous processes...${NC}"

# Kill any backend running on port 8000
if lsof -ti:8000 >/dev/null 2>&1; then
  echo -e "${Y}   Stopping old backend on port 8000${NC}"
  lsof -ti:8000 | xargs kill -9 2>/dev/null || true
  sleep 1
fi

# Kill any Flutter dev server (typically on 8080 or random ports)
if lsof -ti:8080 >/dev/null 2>&1; then
  echo -e "${Y}   Stopping old web server on port 8080${NC}"
  lsof -ti:8080 | xargs kill -9 2>/dev/null || true
  sleep 1
fi

echo -e "${G}✅ Previous servers cleaned${NC}"

# ── 2. Detect local IP and update Flutter code ──────────────────────
if [ "$TARGET" = "web" ]; then
  IP="localhost"
else
  # macOS
  if command -v ipconfig &>/dev/null && [[ "$(uname)" == "Darwin" ]]; then
    IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "localhost")
  # Linux
  elif command -v hostname &>/dev/null; then
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$IP" ] && IP="localhost"
  else
    IP="localhost"
  fi
fi

# Removed sed patching, now using --dart-define
echo -e "${G}✅ Will use backend URL: http://${IP}:8000${NC}"

# ── 3. Start backend ────────────────────────────────────────────────
echo -e "${C}🚀 Starting backend...${NC}"
cd backend

# Find the python executable (venv or system)
if [ -f ./venv/bin/python ]; then
  PYTHON=./venv/bin/python
elif [ -f ./venv/Scripts/python.exe ]; then
  PYTHON=./venv/Scripts/python.exe
else
  PYTHON=python3
fi

$PYTHON main.py &
BACKEND_PID=$!
cd ..

for i in {1..15}; do
  if curl -s http://localhost:8000/ >/dev/null 2>&1; then
    echo -e "${G}✅ Backend ready (PID $BACKEND_PID) → http://localhost:8000${NC}"
    break
  fi
  sleep 1
done

if ! curl -s http://localhost:8000/ >/dev/null 2>&1; then
  echo -e "${R}❌ Backend failed to start${NC}"
  exit 1
fi

# ── 4. Launch Flutter on the chosen target ───────────────────────────
case "$TARGET" in
  web)
    echo -e "${C}🌐 Launching Flutter on Chrome (web)...${NC}"
    flutter run -d chrome --dart-define=BACKEND_URL="http://${IP}:8000"
    ;;
  android)
    echo -e "${C}🤖 Looking for Android device...${NC}"
    DEVICE_ID=$(flutter devices 2>/dev/null | grep -i android | head -1 | awk '{print $NF}')
    if [ -z "$DEVICE_ID" ]; then
      echo -e "${R}❌ No Android device found.${NC}"
      flutter devices
      exit 1
    fi
    echo -e "${G}✅ Found Android: $DEVICE_ID${NC}"
    flutter run -d "$DEVICE_ID" --dart-define=BACKEND_URL="http://${IP}:8000"
    ;;
  macos)
    echo -e "${C}🖥️  Launching Flutter on macOS (Desktop)...${NC}"
    flutter run -d macos --dart-define=BACKEND_URL="http://${IP}:8000"
    ;;
  ios|*)
    echo -e "${C}📱 iOS Device Selection${NC}"
    echo "1) Wired iPhone (auto-detect)"
    echo "2) Wireless iPhone (set IOS_DEVICE_ID env var with your device UDID)"
    read -p "Select option [1/2]: " ios_choice

    if [ "$ios_choice" = "2" ]; then
      echo -e "${C}📱 Looking for wireless iOS device...${NC}"
      if [ -z "$IOS_DEVICE_ID" ]; then
        echo -e "${R}❌ Set IOS_DEVICE_ID to your iPhone's UDID first:${NC}"
        echo -e "${Y}   IOS_DEVICE_ID=00008140-XXXXXXXXXXX ./run.sh ios${NC}"
        flutter devices
        exit 1
      fi
      DEVICE_ID="$IOS_DEVICE_ID"
    else
      echo -e "${C}📱 Looking for wired iOS device...${NC}"
      DEVICE_ID=$(flutter devices 2>/dev/null | grep -i iphone | head -1 | grep -oE '[A-Fa-f0-9-]{20,}' || true)
      if [ -z "$DEVICE_ID" ]; then
        echo -e "${R}❌ No iPhone found. Connect your device and trust this computer.${NC}"
        echo -e "${Y}   Available devices:${NC}"
        flutter devices
        exit 1
      fi
    fi
    echo -e "${G}✅ Launching on iOS device: $DEVICE_ID${NC}"
    flutter run -d "$DEVICE_ID" --dart-define=BACKEND_URL="http://${IP}:8000"
    ;;
esac
