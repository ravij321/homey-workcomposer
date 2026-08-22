# Homey Work Insights macOS Agent — Screenshot Capture

This agent is designed for managed Homey-owned Mac endpoints. Screenshot capture must be enabled by an administrator through an explicit monitoring policy and disclosed to users.

## Behaviour

- Runs locally on macOS.
- Captures screenshots at randomized intervals inside an administrator-defined window.
- Default policy: disabled until explicitly enabled.
- Default interval window: 20–40 minutes.
- Does not capture before the user has an active graphical session.
- Adds device ID, timestamp and policy ID metadata.
- Uploads only over HTTPS to the Homey API.
- Queues failed uploads locally and retries with backoff.
- Applies server-provided retention/deletion instructions.

## Privacy and controls

The agent should never be configured to operate covertly. The dashboard must show whether screenshot monitoring is enabled, the configured interval range, retention period and policy version. Administrators should document the lawful basis/employee notice required for their jurisdiction before enabling collection.

## Configuration

Environment/config values:

- `HOMEY_API_URL`
- `HOMEY_DEVICE_ID`
- `SCREENSHOT_MONITORING_ENABLED`
- `SCREENSHOT_MIN_INTERVAL_MINUTES`
- `SCREENSHOT_MAX_INTERVAL_MINUTES`
- `SCREENSHOT_RETENTION_DAYS`

The agent should use macOS Screen Recording permission. If permission is missing, it reports `permission_required` to the API instead of attempting to bypass the operating system permission model.
