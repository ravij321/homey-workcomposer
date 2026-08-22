#!/bin/bash
set -euo pipefail

# Scalefusion Enterprise Store post-install script.
# Configure this as the PKG Post-Install Script and enable dynamic custom-property expansion.
# Scalefusion replaces %$device.*% placeholders at execution time.

API_URL='%$device.homey_api_url%'
AGENT_TOKEN='%$device.homey_agent_token%'
ENABLED='%$device.homey_screenshot_monitoring%'
MIN_MINUTES='%$device.homey_screenshot_min_minutes%'
MAX_MINUTES='%$device.homey_screenshot_max_minutes%'
RETENTION_DAYS='%$device.homey_screenshot_retention_days%'

APP='/Applications/Homey Work Insights.app'
BINARY="$APP/Contents/MacOS/HomeyAgent"
SERVICE='com.homey.work-insights.agent'
KEYCHAIN_SERVICE='com.homey.work-insights.agent.token'

[[ -x "$BINARY" ]] || { echo "Homey Agent binary not found: $BINARY" >&2; exit 1; }
[[ "$API_URL" == https://* ]] || { echo 'homey_api_url must use HTTPS' >&2; exit 1; }
[[ "$AGENT_TOKEN" != '%$device.homey_agent_token%' && -n "$AGENT_TOKEN" ]] || { echo 'homey_agent_token custom property is missing' >&2; exit 1; }

# This script is intended to run as the signed-in user in Scalefusion.
USER_NAME="${USER:-$(id -un)}"
USER_ID="$(id -u)"
HOME_DIR="${HOME:-$(dscl . -read /Users/$USER_NAME NFSHomeDirectory | awk '{print $2}')}"

mkdir -p "$HOME_DIR/Library/Application Support/Homey Work Insights"
chmod 700 "$HOME_DIR/Library/Application Support/Homey Work Insights"

# Store the device token in the user's login keychain. The agent retrieves it at runtime.
security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$USER_NAME" >/dev/null 2>&1 || true
security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$USER_NAME" -w "$AGENT_TOKEN" -T "$BINARY" >/dev/null

cat > "$HOME_DIR/Library/Application Support/Homey Work Insights/config.json" <<JSON
{
  "apiURL": "${API_URL}",
  "deviceID": "$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1); exit}')",
  "enabled": ${ENABLED:-false},
  "minIntervalMinutes": ${MIN_MINUTES:-20},
  "maxIntervalMinutes": ${MAX_MINUTES:-40},
  "retentionDays": ${RETENTION_DAYS:-30}
}
JSON
chmod 600 "$HOME_DIR/Library/Application Support/Homey Work Insights/config.json"

mkdir -p "$HOME_DIR/Library/LaunchAgents"
cat > "$HOME_DIR/Library/LaunchAgents/${SERVICE}.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>${SERVICE}</string>
<key>ProgramArguments</key><array><string>${BINARY}</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ProcessType</key><string>Background</string>
<key>EnvironmentVariables</key><dict>
<key>HOMEY_CONFIG_PATH</key><string>$HOME_DIR/Library/Application Support/Homey Work Insights/config.json</string>
</dict>
</dict></plist>
PLIST
chmod 644 "$HOME_DIR/Library/LaunchAgents/${SERVICE}.plist"

launchctl bootout "gui/${USER_ID}/${SERVICE}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${USER_ID}" "$HOME_DIR/Library/LaunchAgents/${SERVICE}.plist"
launchctl enable "gui/${USER_ID}/${SERVICE}"
launchctl kickstart -k "gui/${USER_ID}/${SERVICE}"

# Emit a useful status for Scalefusion's script result panel.
echo "Homey Work Insights installed and launched for ${USER_NAME}."
echo "Device ID: $(ioreg -rd1 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1); exit}')"
echo "Screenshot monitoring: ${ENABLED:-false}"
