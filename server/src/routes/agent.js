import { Router } from 'express';
import crypto from 'node:crypto';
import { query } from '../db.js';

const router = Router();

function authorized(req) {
  const token = req.header('X-Homey-Agent-Token');
  const expected = process.env.HOMEY_AGENT_TOKEN;
  return Boolean(token && expected && token.length === expected.length && crypto.timingSafeEqual(Buffer.from(token), Buffer.from(expected)));
}

async function resolveDevice(deviceId) {
  const result = await query('SELECT id, user_id FROM devices WHERE external_id=$1 OR serial_number=$1 LIMIT 1', [deviceId]);
  return result.rows[0] || null;
}

router.post('/status', async (req, res) => {
  if (!authorized(req)) return res.status(401).json({ error: 'Unauthorized agent' });
  const deviceId = req.header('X-Homey-Device-ID');
  if (!deviceId) return res.status(400).json({ error: 'X-Homey-Device-ID is required' });
  try {
    const result = await query(`UPDATE devices SET last_seen_at=now(), updated_at=now() WHERE external_id=$1 OR serial_number=$1`, [deviceId]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Unknown device' });
    res.json({ ok: true });
  } catch { res.status(500).json({ error: 'Unable to update agent status' }); }
});

// Agent activity telemetry. The agent sends one minute-sized event at a time.
// Active/idle state is decided on-device; the server stores only the resulting duration.
router.post('/events', async (req, res) => {
  if (!authorized(req)) return res.status(401).json({ error: 'Unauthorized agent' });
  const deviceId = req.header('X-Homey-Device-ID');
  if (!deviceId) return res.status(400).json({ error: 'X-Homey-Device-ID is required' });

  const { type, timestamp, durationMinutes, application, metadata } = req.body || {};
  if (!type || !timestamp) return res.status(400).json({ error: 'type and timestamp are required' });

  try {
    const device = await resolveDevice(deviceId);
    if (!device) return res.status(404).json({ error: 'Unknown device' });

    const minutes = Math.max(0, Math.min(60, Number(durationMinutes) || 0));
    await query(
      `INSERT INTO activity_events (user_id, device_id, application, event_type, started_at, ended_at, duration_minutes, source, metadata)
       VALUES ($1,$2,$3,$4,$5::timestamptz,($5::timestamptz + ($6 || ' minutes')::interval),$6,'agent',$7::jsonb)`,
      [device.user_id, device.id, application || null, type, timestamp, minutes, JSON.stringify(metadata || {})]
    );
    await query('UPDATE devices SET last_seen_at=now(), updated_at=now() WHERE id=$1', [device.id]);
    res.status(201).json({ ok: true, recordedMinutes: minutes });
  } catch (error) {
    console.error('agent event error', error);
    res.status(500).json({ error: 'Unable to record activity event' });
  }
});

export default router;
