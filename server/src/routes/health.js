import { Router } from 'express';
import { query } from '../db.js';

const router = Router();

// Railway liveness endpoint: returns 200 when the Node process is running.
router.get('/', (_req, res) => {
  res.status(200).json({
    ok: true,
    service: 'homey-work-insights-api',
    status: 'online',
    timestamp: new Date().toISOString()
  });
});

// Database readiness check for diagnostics.
router.get('/ready', async (_req, res) => {
  const checks = {
    api: true,
    database: false,
    scalefusion: Boolean(process.env.SCALEFUSION_API_TOKEN)
  };
  try {
    await query('SELECT 1');
    checks.database = true;
  } catch {}
  res.status(checks.database ? 200 : 503).json({
    ok: checks.database,
    ...checks,
    timestamp: new Date().toISOString()
  });
});

export default router;
