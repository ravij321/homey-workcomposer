import { Router } from 'express';
import { requireAuth } from '../auth.js';
import { query } from '../db.js';

const router = Router();

router.get('/', requireAuth, async (req, res) => {
  try {
    const result = await query(`SELECT s.id, s.device_id, d.name AS device_name, d.serial_number, u.name AS user_name, s.image_url, s.captured_at, s.admin_name, s.source FROM screenshots s LEFT JOIN devices d ON d.id=s.device_id LEFT JOIN users u ON u.id=d.user_id WHERE s.deleted_at IS NULL ORDER BY s.captured_at DESC LIMIT 100`);
    res.json({ screenshots: result.rows });
  } catch (e) { res.status(500).json({ error: 'Unable to load screenshots' }); }
});

router.post('/capture-request', requireAuth, async (req, res) => {
  const { device_id } = req.body || {};
  if (!device_id) return res.status(400).json({ error: 'device_id is required' });
  try {
    const result = await query(`INSERT INTO screenshot_requests (device_id, requested_by, status, reason) VALUES ($1,$2,'pending',$3) RETURNING id, device_id, status, created_at`, [device_id, req.auth.sub, 'Authorized screenshot request']);
    await query(`INSERT INTO audit_events (actor_id, action, resource_type, resource_id, metadata) VALUES ($1,'screenshot.requested','device',$2,$3)`, [req.auth.sub, device_id, JSON.stringify({ authorization: 'approved', source: 'Homey' })]);
    res.status(202).json({ request: result.rows[0], message: 'Authorized capture request created. A supported Scalefusion Remote Cast workflow must perform the actual capture.' });
  } catch (e) { res.status(500).json({ error: 'Unable to create screenshot request' }); }
});

export default router;
