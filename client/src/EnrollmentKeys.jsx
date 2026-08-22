import React, { useEffect, useState } from 'react';

const API = import.meta.env.VITE_API_URL || 'http://localhost:4000';

export default function EnrollmentKeys({ token }) {
  const [keys, setKeys] = useState([]);
  const [newKey, setNewKey] = useState('');
  const [expiresHours, setExpiresHours] = useState(24);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const headers = token ? { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } : { 'Content-Type': 'application/json' };

  async function load() {
    setLoading(true); setError('');
    try {
      const r = await fetch(`${API}/api/enrollment-keys`, { headers });
      const data = await r.json();
      if (!r.ok) throw new Error(data.error || `API returned ${r.status}`);
      setKeys(data.keys || []);
    } catch (e) { setError(e.message); } finally { setLoading(false); }
  }
  useEffect(() => { load(); }, [token]);

  async function generate() {
    setBusy(true); setError(''); setNewKey('');
    try {
      const r = await fetch(`${API}/api/enrollment-keys`, { method: 'POST', headers, body: JSON.stringify({ expiresHours }) });
      const data = await r.json();
      if (!r.ok) throw new Error(data.error || 'Unable to generate key');
      setNewKey(data.key); await load();
    } catch (e) { setError(e.message); } finally { setBusy(false); }
  }

  async function revoke(id) {
    if (!window.confirm('Revoke this enrollment key?')) return;
    try {
      const r = await fetch(`${API}/api/enrollment-keys/${id}/revoke`, { method: 'POST', headers });
      const data = await r.json();
      if (!r.ok) throw new Error(data.error || 'Unable to revoke key');
      await load();
    } catch (e) { setError(e.message); }
  }

  return <div className="panel" style={{ marginTop: 8 }}>
    <div className="panelHead">
      <div><h2>Enrollment Keys</h2><p>Generate controlled keys for Homey macOS agent enrollment.</p></div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        <select value={expiresHours} onChange={e => setExpiresHours(Number(e.target.value))} className="filter">
          <option value={1}>1 hour</option><option value={24}>24 hours</option><option value={72}>72 hours</option><option value={168}>7 days</option>
        </select>
        <button className="export" onClick={generate} disabled={busy}>{busy ? 'Generating…' : '+ Generate Key'}</button>
      </div>
    </div>
    {newKey && <div className="banner" style={{ margin: '16px 0' }}><b>New key — copy it now:</b><div style={{ display: 'flex', gap: 8, marginTop: 8 }}><code style={{ flex: 1, padding: 10, overflow: 'auto' }}>{newKey}</code><button className="export" onClick={() => navigator.clipboard.writeText(newKey)}>Copy</button></div><small>The plaintext key is shown once and is not stored by the server.</small></div>}
    {error && <div className="banner" style={{ margin: '16px 0' }}>{error}</div>}
    {loading ? <p className="muted">Loading enrollment keys…</p> : <div className="table">
      <div className="thead"><span>KEY</span><span>CREATED</span><span>EXPIRES</span><span>STATUS</span><span>ACTION</span></div>
      {keys.length === 0 && <div className="trow"><span>No enrollment keys yet.</span></div>}
      {keys.map(k => <div className="trow" key={k.id}>
        <span><code>{k.key_hint}</code></span><span>{new Date(k.created_at).toLocaleString()}</span><span>{new Date(k.expires_at).toLocaleString()}</span>
        <span><i className={`statusPill ${k.status === 'active' ? 'active' : 'idle'}`}>{k.status}</i></span>
        <span>{k.status === 'active' && <button className="linkBtn" onClick={() => revoke(k.id)}>Revoke</button>}</span>
      </div>)}
    </div>}
  </div>;
}
