# Homey Work Insights — Production Build

## Modules

- Dashboard and reporting
- Scalefusion Mac inventory and synchronization
- Users and departments
- Activity events and work-hour reporting
- Application insights
- JWT authentication and role-based authorization
- Screenshot request workflow with explicit authorization
- Screenshot gallery and audit history
- Administrative audit logging

## Production rules

1. Never commit Scalefusion API tokens, JWT secrets, database passwords, or storage credentials.
2. Keep all third-party credentials server-side.
3. Screenshot capture must be initiated through an authorized workflow and recorded in the audit log.
4. Store screenshot objects in private object storage; the database stores metadata and a non-public object reference.
5. Apply retention and deletion policies to screenshots and raw activity events.
6. Use HTTPS, secure cookies or short-lived bearer tokens, rate limiting, input validation, and least-privilege database credentials.
7. Restrict screenshot and audit endpoints to authorized administrator roles.

## Remaining external integration boundary

The public Scalefusion Developer API can be used for supported inventory/management operations. The actual macOS screenshot is completed through Scalefusion's supported Remote Cast workflow; Homey must not invent an undocumented screenshot API endpoint.

## Deployment configuration

Required environment variables:

- `DATABASE_URL`
- `JWT_SECRET`
- `SCALEFUSION_API_TOKEN`
- `SCALEFUSION_API_URL`
- `APP_URL`
- `CORS_ORIGIN`
- `OBJECT_STORAGE_BUCKET`
- `OBJECT_STORAGE_ENDPOINT`
- `OBJECT_STORAGE_ACCESS_KEY`
- `OBJECT_STORAGE_SECRET_KEY`
