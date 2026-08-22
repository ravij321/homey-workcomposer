# Homey Work Insights macOS PKG

This directory contains the production packaging pipeline for deploying the Homey macOS agent through Scalefusion.

## Package

- Bundle ID: `com.homey.work-insights.agent`
- Install path: `/Applications/Homey Work Insights.app`
- Minimum macOS: 13
- Architecture: arm64 + x86_64
- PKG identifier: `com.homey.work-insights.agent`

Scalefusion can deploy PKGs through its Enterprise Store. For the current Scalefusion workflow, use the Agent installation method when using the supplied post-install configuration script. citeturn4search0turn4search7

## Build on a Mac

```bash
./packaging/build-pkg.sh
```

For a signed release:

```bash
DEVELOPER_ID_APPLICATION='Developer ID Application: Homey Technology Ltd (TEAMID)' \
DEVELOPER_ID_INSTALLER='Developer ID Installer: Homey Technology Ltd (TEAMID)' \
./packaging/build-pkg.sh
```

Apple requires packages distributed through device-management services to have a device-verifiable signature; Apple also recommends signing the nested code before signing the installer package. citeturn4search5turn0search3

## Scalefusion configuration

The package deliberately contains no tenant-wide secret. Configure the supplied `scalefusion-postinstall.sh` as the PKG post-install script and enable dynamic custom-property expansion.

Create these device custom properties:

- `homey_api_url` — Homey API base URL
- `homey_agent_token` — per-device agent token
- `homey_screenshot_monitoring` — `true` or `false`
- `homey_screenshot_min_minutes` — normally `20`
- `homey_screenshot_max_minutes` — normally `40`
- `homey_screenshot_retention_days` — normally `30`

The script uses Scalefusion's `%$device.property%` dynamic substitution. Scalefusion documents this mechanism for macOS shell scripts and PKG pre/post-install scripts. citeturn3search0turn3search4

The token is stored in the signed-in user's macOS Keychain rather than a world-readable configuration file.

## Screen Recording

Installing the PKG does not bypass macOS privacy controls. If Homey enables automatic screenshots, deploy a Privacy Preferences Policy Control (PPPC) configuration that explicitly allows the signed Homey agent to use Screen Recording. Apple exposes Screen Recording as a PPPC-managed privacy service. citeturn1search12

Test the agent and PPPC profile on a small pilot group before broad deployment.
