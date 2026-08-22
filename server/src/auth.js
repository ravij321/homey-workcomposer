import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { query } from './db.js';

const secret = process.env.JWT_SECRET || 'change-this-in-production';

export async function login(email, password) {
  const result = await query('SELECT id, email, name, password_hash, role, active FROM users WHERE lower(email)=lower($1) LIMIT 1', [email]);
  const user = result.rows[0];
  if (!user || !user.active || !(await bcrypt.compare(password, user.password_hash))) return null;
  const token = jwt.sign({ sub: user.id, role: user.role, email: user.email }, secret, { expiresIn: '8h' });
  return { token, user: { id: user.id, email: user.email, name: user.name, role: user.role } };
}

export function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) return res.status(401).json({ error: 'Authentication required' });
  try { req.auth = jwt.verify(header.slice(7), secret); next(); }
  catch { res.status(401).json({ error: 'Invalid or expired token' }); }
}
