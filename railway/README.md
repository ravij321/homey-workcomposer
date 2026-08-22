# Railway deployment

Create one Railway project with three services:

1. **homey-api** — deploy from the repository with Root Directory `server`.
2. **homey-web** — deploy from the repository with Root Directory `client`.
3. **PostgreSQL** — add Railway PostgreSQL and connect `DATABASE_URL` to the API.

## API

Root Directory: `server`

Build: Railpack detects `server/package.json`.
Start: `npm start`
Health: `/api/health`

Required variables:

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
JWT_SECRET=<strong-random-secret>
HOMEY_AGENT_TOKEN=<strong-random-agent-token>
CORS_ORIGIN=https://<web-domain>
SCALEFUSION_API_URL=https://api.scalefusion.com
SCALEFUSION_API_TOKEN=<server-secret>
SCREENSHOT_STORAGE_PATH=/data/screenshots
```

## Web

Root Directory: `client`

Build: `npm install && npm run build`
Start: `npm run preview -- --host 0.0.0.0`

Variable:

```text
VITE_API_URL=https://<api-domain>
```

## Important

Do not deploy the repository root as the API service. The repository contains the macOS Swift agent and PKG packaging code and should be split into the API and web Railway services.

After creating the services, generate Railway public domains and set the two URLs above. Redeploy the API after changing `CORS_ORIGIN`, then redeploy the web service after setting `VITE_API_URL`.
