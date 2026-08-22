# Homey Work Insights

A privacy-first work activity and productivity insights platform for Homey.

## Goals

- Track work activity with configurable monitoring controls.
- Integrate endpoint/MDM data such as Scalefusion through a secure backend.
- Provide useful dashboards for admins and managers.
- Support device, user, application, event, and department-level insights.
- Maintain audit-friendly records and role-based administration.

## Repository

- `client/` — React dashboard
- `server/` — Express API and integrations
- `db/` — PostgreSQL schema
- `agent/` — native Swift macOS agent
- `packaging/` — production macOS PKG builder and Scalefusion deployment scripts
- `docs/` — product and security documentation

## macOS PKG deployment

The repository now contains a universal macOS package pipeline for `com.homey.work-insights.agent`.

```text
packaging/
├── build-pkg.sh
├── scalefusion-postinstall.sh
├── scalefusion-uninstall.sh
├── homey-screen-recording-pppc.mobileconfig.template
└── README.md
```

The PKG installs:

```text
/Applications/Homey Work Insights.app
└── Contents/MacOS/HomeyAgent
```

The agent is launched in the signed-in user's GUI session so macOS privacy controls apply to the correct user. The per-device agent token is stored in that user's Keychain rather than a world-readable plist.

### Build

On macOS:

```bash
chmod +x packaging/build-pkg.sh
VERSION=1.0.0 ./packaging/build-pkg.sh
```

For production, sign the application with a **Developer ID Application** certificate and the PKG with a **Developer ID Installer** certificate. Apple requires a package distributed by a device-management service to have a signature that the device can verify. citeturn4search5turn0search3

The GitHub Actions workflow `.github/workflows/build-macos-pkg.yml` builds the PKG on a macOS runner and publishes it as a workflow artifact; tag builds also create a GitHub release.

### Scalefusion

Scalefusion supports macOS PKG deployment through Enterprise Store and currently supports both MDM-based and Agent-based PKG installation workflows. citeturn4search0turn4search4

For the Homey deployment:

1. Create device custom properties:
   - `homey_api_url`
   - `homey_agent_token`
   - `homey_screenshot_monitoring`
   - `homey_screenshot_min_minutes`
   - `homey_screenshot_max_minutes`
   - `homey_screenshot_retention_days`
2. Upload `dist/HomeyWorkInsights-<version>.pkg` to Enterprise Store.
3. Use **Install via Agent** for the package when using the supplied dynamic post-install script.
4. Configure `packaging/scalefusion-postinstall.sh` as the Post-Install Script and enable dynamic custom-property expansion.
5. Run the post-install script as the signed-in user.
6. Use the supplied uninstall script for removal.

Scalefusion documents `%$device.property%` expansion for macOS scripts and custom properties, including PKG pre/post-install scripting. citeturn3search0turn3search4

### Screen Recording permission

The package does not bypass macOS privacy controls. If screenshot monitoring is enabled, deploy `packaging/homey-screen-recording-pppc.mobileconfig.template` through Scalefusion as a custom macOS configuration, replacing the placeholder Team ID with Homey's actual Apple Developer Team ID and verifying the final code requirement against the signed binary.

Apple's PPPC payload exposes the `ScreenCapture` service, and Screen Recording permissions are intended to be managed through device management on managed Macs. citeturn6search0turn6search5

## Privacy

Screenshot monitoring is disabled by default. Enabling it should be accompanied by Homey's employee notice, lawful-basis assessment, retention policy and appropriate access controls. The agent respects macOS Screen Recording permissions and reports `permission_required` instead of attempting to bypass them.
