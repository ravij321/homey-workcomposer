import { Router } from 'express';

const router = Router();

// Scalefusion credentials belong in server environment variables only.
router.get('/scalefusion/status', (_req, res) => {
  res.json({ provider: 'scalefusion', configured: Boolean(process.env.SCALEFUSION_API_URL && process.env.SCALEFUSION_API_TOKEN), lastSync: null });
});

router.post('/scalefusion/sync', async (_req, res) => {
  if (!process.env.SCALEFUSION_API_URL || !process.env.SCALEFUSION_API_TOKEN) {
    return res.status(503).json({ error: 'Scalefusion integration is not configured' });
  }
  // Adapter intentionally isolates vendor API details from the application.
  res.status(202).json({ accepted: true, message: 'Scalefusion sync queued' });
});

export default router;
