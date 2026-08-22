#!/bin/bash
set -euo pipefail

BASE="/Library/Application Support/HomeyWorkInsights"
LOG_DIR="/Library/Logs/HomeyWorkInsights"
PLIST="/Library/LaunchDaemons/com.homey.workinsights.agent.plist"

install -d -m 0755 "$BASE" "$LOG_DIR"
install -m 0755 "HomeyAgent" "$BASE/HomeyAgent"
install -m 0644 "config.json" "$BASE/config.json"
install -m 0644 "com.homey.workinsights.agent.plist" "$PLIST"

chown root:wheel "$BASE/HomeyAgent" "$BASE/config.json" "$PLIST"
chmod 0600 "$BASE/config.json"

launchctl bootout system "$PLIST" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
launchctl enable system/com.homey.workinsights.agent

printf '%s\n' "Homey Work Insights Agent installed successfully."
