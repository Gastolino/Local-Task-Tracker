#!/usr/bin/env bash
# Install Local Task Tracker as a macOS LaunchAgent so it starts at login.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_TEMPLATE="$REPO_DIR/com.localtracker.agent.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/com.localtracker.agent.plist"
DATA_DIR="$HOME/Library/Application Support/LocalTaskTracker"

# ── Python ────────────────────────────────────────────────────────────────────
PYTHON_PATH="$(command -v python3 2>/dev/null || true)"
if [[ -z "$PYTHON_PATH" ]]; then
    echo "ERROR: python3 not found. Install it via Homebrew: brew install python" >&2
    exit 1
fi

PYTHON_VERSION="$("$PYTHON_PATH" -c 'import sys; print(sys.version_info[:2])')"
echo "Using Python: $PYTHON_PATH  ($PYTHON_VERSION)"

# ── Plist ─────────────────────────────────────────────────────────────────────
mkdir -p "$LAUNCH_AGENTS_DIR"
mkdir -p "$DATA_DIR"

sed \
    -e "s|__PYTHON_PATH__|$PYTHON_PATH|g" \
    -e "s|__REPO_DIR__|$REPO_DIR|g" \
    -e "s|__DATA_DIR__|$DATA_DIR|g" \
    "$PLIST_TEMPLATE" > "$PLIST_DEST"

echo "Installed plist → $PLIST_DEST"

# ── Load ──────────────────────────────────────────────────────────────────────
# Unload first in case it was already loaded (idempotent re-install).
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load   "$PLIST_DEST"

echo ""
echo "✓ Local Task Tracker is now running and will start at every login."
echo ""
echo "Logs   : $DATA_DIR/tracker.log"
echo "Data   : $DATA_DIR/tracker.db"
echo "Report : python3 \"$REPO_DIR/main.py\" report"
echo ""
echo "IMPORTANT — grant these permissions to Terminal (or your Python binary)"
echo "in System Settings → Privacy & Security, or the tracker will not work:"
echo "  • Accessibility     (to read the active app)"
echo "  • Screen Recording  (to capture screenshots)"
