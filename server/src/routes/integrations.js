import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../auth.js';
import { listScalefusionDevices } from '../scalefusion.js';

const router = Router();

router.get('/scalefusion/status', requireAuth, async (_req, res) => {
  try {
    const result = await query("SELECT provider, enabled, last_sync_at FROM integrations WHERE provider='scalefusion' LIMIT 1");
    res.json({ provider: 'scalefusion', configured: Boolean(process.env.SCALEFUSION_API_TOKEN), ...(result.rows[0] || { enabled: false, last_sync_at: null }) });
  } catch (error) { res.status(500).json({ error: error.message }); }
});

router.post('/scalefusion/sync', requireAuth, async (_req, res) => {
  try {
    const firstPage = await listScalefusionDevices();
    const devices = firstPage.devices || firstPage.data || firstPage.results || [];
    for (const device of devices) {
      const externalId = String(device.id ?? device.device_id ?? '');
      if (!externalId) continue;
      await query(`
        INSERT INTO devices (external_id, serial_number, name, os, os_version, status, mdm_source, last_seen_at, updated_at)
        VALUES ($1,$2,$3,$4,$5,$6,'scalefusion',$7,now())
        ON CONFLICT (external_id) DO UPDATE SET serial_number=EXCLUDED.serial_number,name=EXCLUDED.name,
          os=EXCLUDED.os,os_version=EXCLUDED.os_version,status=EXCLUDED.status,mdm_source='scalefusion',
          last_seen_at=EXCLUDED.last_seen_at,updated_at=now()
      `, [externalId, device.serial_number ?? device.serial ?? null, device.name ?? device.device_name ?? `Scalefusion ${externalId}`,
        device.os ?? device.platform ?? 'macOS', device.os_version ?? device.osVersion ?? null,
        device.status ?? device.device_status ?? 'unknown', device.last_seen_at ?? device.last_seen ?? null]);
    }
    await query(`INSERT INTO integrations (provider, enabled, last_sync_at) VALUES ('scalefusion',true,now()) ON CONFLICT (provider) DO UPDATE SET enabled=true,last_sync_at=now()`);
    res.json({ synced: devices.length, nextCursor: firstPage.next_cursor ?? firstPage.nextCursor ?? null });
  } catch (error) { res.status(502).json({ error: 'Scalefusion synchronization failed', detail: error.message }); }
});

export default router;
