# MVP Scope

## Dashboard

- Total active users
- Managed devices
- Active devices
- Work activity hours
- Top applications
- Activity by department
- Activity trend by day
- MDM compliance summary

## Activity events

Each event should support:

- Device name
- Serial number
- User name
- Department
- Event type
- Event start time
- Event end time
- Duration in minutes
- Source

## Administration

Admins can:

- Invite administrators
- Assign roles
- Disable administrators
- Review audit events
- Manage departments
- Configure integrations

## Scalefusion integration

The integration should support a server-side sync process that imports permitted device metadata and management status. API credentials must never be exposed to the browser.

## UX

The interface should be modern, responsive, accessible, and easy to understand. Use cards, charts, filters, search, pagination, and clear status indicators rather than dense tables alone.
