import { Router } from 'express';
import crypto from 'node:crypto';
import { query } from '../db.js';
import { requireAuth } from '../auth.js';

const router = Router();

async function ensureTable() {
  await query(`
    CREATE TABLE IF NOT EXISTS enrollment_keys (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      key_hash TEXT NOT NULL UNIQUE,
      key_hint TEXT NOT NULL,
      created_by UUID REFERENCES users(id),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL,
      used_at TIMESTAMPTZ,
      revoked_at TIMESTAMPTZ
    )
  `);
  await query('CREATE INDEX IF NOT EXISTS idx_enrollment_keys_active ON enrollment_keys(expires_at, revoked_at, used_at)');
}

function adminOnly(req, res, next) {
  if (req.auth?.role !== 'admin') return res.status(403).json({ error: 'Admin access required' });
  next();
}

router.use(requireAuth, adminOnly);

router.get('/', async (_req, res) => {
  try {
    await ensureTable();
    const result = await query(`
      SELECT id, key_hint, created_at, expires_at, used_at, revoked_at,
             CASE
               WHEN revoked_at IS NOT NULL THEN 'revoked'
               WHEN used_at IS NOT NULL THEN 'used'
               WHEN expires_at <= now() THEN 'expired'
               ELSE 'active'
             END AS status
      FROM enrollment_keys
      ORDER BY created_at DESC
      LIMIT 50
    `);
    res.json({ keys: result.rows });
  } catch (error) {
    console.error('enrollment key list error', error);
    res.status(500).json({ error: 'Unable to list enrollment keys' });
  }
});

router.post('/', async (req, res) => {
  try {
    await ensureTable();
    const ttlHours = Math.max(1, Math.min(168, Number(req.body?.expiresHours) || 24));
    const rawKey = `HWI-${crypto.randomBytes(32).toString('hex')}`;
    const hash = crypto.createHash('sha256').update(rawKey).digest('hex');
    const hint = `${rawKey.slice(0, 8)}…${rawKey.slice(-4)}`;
    const result = await query(
      `INSERT INTO enrollment_keys (key_hash,key_hint,created_by,expires_at)
       VALUES ($1,$2,$3,now()+($4 || ' hours')::interval)
       RETURNING id,key_hint,created_at,expires_at`,
      [hash, hint, req.auth.sub, ttlHours]
    );
    await query(
      `INSERT INTO audit_events (actor_user_id,action,resource_type,resource_id,metadata)
       VALUES ($1,'ENROLLMENT_KEY_CREATED','enrollment_key',$2,$3::jsonb)`,
      [req.auth.sub, result.rows[0].id, JSON.stringify({ expiresHours: ttlHours, keyHint: hint })]
    );
    res.status(201).json({ key: rawKey, ...result.rows[0], warning: 'Copy this key now. The plaintext key is not stored and cannot be recovered later.' });
  } catch (error) {
    console.error('enrollment key create error', error);
    res.status(500).json({ error: 'Unable to generate enrollment key' });
  }
});

router.post('/:id/revoke', async (req, res) => {
  try {
    await ensureTable();
    const result = await query(
      `UPDATE enrollment_keys SET revoked_at=now()
       WHERE id=$1 AND used_at IS NULL AND revoked_at IS NULL AND expires_at>now()
       RETURNING id,key_hint,revoked_at`,
      [req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Active enrollment key not found' });
    await query(
      `INSERT INTO audit_events (actor_user_id,action,resource_type,resource_id)
       VALUES ($1,'ENROLLMENT_KEY_REVOKED','enrollment_key',$2)`,
      [req.auth.sub, req.params.id]
    );
    res.json({ ok: true, key: result.rows[0] });
  } catch (error) {
    console.error('enrollment key revoke error', error);
    res.status(500).json({ error: 'Unable to revoke enrollment key' });
  }
});

export default router;
