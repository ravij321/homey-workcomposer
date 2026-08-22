import express from 'express';
import cors from 'cors';
import auth from './routes/auth.js';
import integrations from './routes/integrations.js';
import screenshots from './routes/screenshots.js';
import agent from './routes/agent.js';
import audit from './routes/audit.js';
import health from './routes/health.js';
import analytics from './routes/analytics.js';
import { requireAuth } from './auth.js';
import { query } from './db.js';

const app = express();
const port = process.env.PORT || 4000;

app.disable('x-powered-by');
app.use(cors({ origin: process.env.CORS_ORIGIN || true }));
app.use('/api/screenshots/agent-upload', express.raw({ type: 'application/octet-stream', limit: '20mb' }));
app.use(express.json({ limit: '1mb' }));

// Public service endpoints.
app.get('/', (_req, res) => {
  res.json({
    name: 'Homey Work Insights API',
    status: 'online',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      dashboard: '/api/dashboard',
      devices: '/api/devices'
    }
  });
});

app.get('/favicon.ico', (_req, res) => res.status(204).end());

app.use('/api/auth', auth);
app.use('/api/integrations', integrations);
app.use('/api/screenshots', screenshots);
app.use('/api/agent', agent);
app.use('/api/audit', audit);
app.use('/api/health', health);
app.use('/api/analytics', analytics);

app.get('/api/dashboard', requireAuth, async (_req, res) => {
  try {
    const [u, d, a, h, c] = await Promise.all([
      query('SELECT count(*)::int value FROM users WHERE active=true'),
      query('SELECT count(*)::int value FROM devices'),
      query("SELECT count(*)::int value FROM devices WHERE status='compliant'"),
      query("SELECT COALESCE(round(sum(duration_minutes)/60.0,1),0) value FROM activity_events WHERE started_at>=now()-interval '7 days'"),
      query("SELECT COALESCE(round(100.0*count(*) FILTER(WHERE status='compliant')/NULLIF(count(*),0),1),0) value FROM devices")
    ]);
    res.json({ kpis: {
      users: u.rows[0].value,
      devices: d.rows[0].value,
      activeDevices: a.rows[0].value,
      activityHours: Number(h.rows[0].value),
      compliance: Number(c.rows[0].value)
    }});
  } catch {
    res.status(503).json({ error: 'Database unavailable' });
  }
});

app.get('/api/devices', requireAuth, async (_req, res) => {
  try {
    const x = await query(`SELECT d.id,d.external_id,d.serial_number,d.name,d.os,d.os_version,d.status,d.mdm_source,d.last_seen_at,u.name user_name FROM devices d LEFT JOIN users u ON u.id=d.user_id ORDER BY d.updated_at DESC`);
    res.json({ devices: x.rows });
  } catch {
    res.status(503).json({ error: 'Database unavailable' });
  }
});

app.use((_req, res) => res.status(404).json({ error: 'Not found' }));

app.listen(port, () => console.log(`Homey Work Insights API listening on ${port}`));
