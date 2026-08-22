# Architecture

## Product layers

### Client

React-style single-page dashboard with:

- Overview
- Activity
- Devices
- Users
- Departments
- Applications
- MDM health
- Administrators
- Audit logs
- Settings

### Server

REST API responsible for authentication, authorization, activity ingestion, reporting, invitations, audit logging, and third-party integrations.

### Integration layer

External integrations are isolated from the UI. Scalefusion is treated as an integration source for device and management data. Secrets must remain server-side.

### Data model

Core entities:

- User
- Department
- Device
- ActivityEvent
- Application
- MDMDevice
- Admin
- Invitation
- AuditEvent

## Security requirements

- Role-based access control
- Secure password/session handling
- MFA-ready authentication design
- Server-side API credentials
- Audit logging for administrative actions
- Least-privilege integration credentials
- Input validation and rate limiting
- No screenshot collection by default

## Reporting

Activity reports should be derived from event metadata and aggregated into daily and weekly metrics. Raw events should have explicit retention rules and access controls.
