import { Router } from 'express';
import { login } from '../auth.js';

const router = Router();
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Email and password are required' });
    const result = await login(email, password);
    if (!result) return res.status(401).json({ error: 'Invalid credentials' });
    res.json(result);
  } catch (error) { res.status(500).json({ error: 'Authentication service unavailable' }); }
});
export default router;
