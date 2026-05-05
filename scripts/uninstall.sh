#!/usr/bin/env bash
# Stop and remove the Local Task Tracker LaunchAgent.
# Data (DB + screenshots) is preserved in ~/Library/Application Support/LocalTaskTracker.
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.localtracker.agent.plist"

if [[ -f "$PLIST" ]]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm "$PLIST"
    echo "✓ LaunchAgent removed. Tracker will no longer start at login."
else
    echo "LaunchAgent plist not found — nothing to remove."
fi

echo ""
echo "Your data is still at:"
echo "  ~/Library/Application Support/LocalTaskTracker/"
echo "Delete that directory manually if you no longer need it."
