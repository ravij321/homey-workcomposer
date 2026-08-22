export function requireAdmin(req, res, next) {
  // Replace with signed session/JWT verification in the production auth provider.
  const role = req.header('x-homey-role');
  if (role !== 'admin') return res.status(403).json({ error: 'Admin access required' });
  next();
}
