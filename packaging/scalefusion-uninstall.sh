#!/bin/bash
set -euo pipefail
SERVICE='com.homey.work-insights.agent'
APP='/Applications/Homey Work Insights.app'
KEYCHAIN_SERVICE='com.homey.work-insights.agent.token'
USER_NAME="${USER:-$(id -un)}"
USER_ID="$(id -u)"
HOME_DIR="${HOME:-$(dscl . -read /Users/$USER_NAME NFSHomeDirectory | awk '{print $2}')}"
PLIST="$HOME_DIR/Library/LaunchAgents/${SERVICE}.plist"

launchctl bootout "gui/${USER_ID}/${SERVICE}" >/dev/null 2>&1 || true
rm -f "$PLIST"
rm -rf "$HOME_DIR/Library/Application Support/Homey Work Insights"
security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$USER_NAME" >/dev/null 2>&1 || true
rm -rf "$APP"

echo "Homey Work Insights removed for ${USER_NAME}."
