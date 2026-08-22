import express from 'express';
import cors from 'cors';
import auth from './routes/auth.js';
import integrations from './routes/integrations.js';
import { requireAuth } from './auth.js';
import { query } from './db.js';

const app = express();
const port = process.env.PORT || 4000;
app.use(cors());
app.use(express.json());
app.use('/api/auth', auth);
app.use('/api/integrations', integrations);

app.get('/api/health', (_req, res) => res.json({ ok: true, service: 'homey-work-insights-api' }));

app.get('/api/dashboard', requireAuth, async (_req, res) => {
  try {
    const [users, devices, activeDevices, hours, compliant] = await Promise.all([
      query('SELECT count(*)::int AS value FROM users WHERE active=true'),
      query('SELECT count(*)::int AS value FROM devices'),
      query("SELECT count(*)::int AS value FROM devices WHERE status='compliant'"),
      query("SELECT COALESCE(round(sum(duration_minutes)/60.0,1),0) AS value FROM activity_events WHERE started_at >= now()-interval '7 days'"),
      query("SELECT COALESCE(round(100.0*count(*) FILTER (WHERE status='compliant')/NULLIF(count(*),0),1),0) AS value FROM devices")
    ]);
    res.json({ kpis: { users: users.rows[0].value, devices: devices.rows[0].value, activeDevices: activeDevices.rows[0].value, activityHours: Number(hours.rows[0].value), compliance: Number(compliant.rows[0].value) } });
  } catch (error) { res.status(503).json({ error: 'Database unavailable' }); }
});

app.get('/api/devices', requireAuth, async (_req, res) => {
  try {
    const result = await query(`SELECT d.id,d.external_id,d.serial_number,d.name,d.os,d.os_version,d.status,d.mdm_source,d.last_seen_at,u.name AS user_name FROM devices d LEFT JOIN users u ON u.id=d.user_id ORDER BY d.updated_at DESC`);
    res.json({ devices: result.rows });
  } catch { res.status(503).json({ error: 'Database unavailable' }); }
});

app.listen(port, () => console.log(`Homey Work Insights API listening on ${port}`));
