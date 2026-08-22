import React, { useEffect, useState } from 'react';

const API = import.meta.env.VITE_API_URL || '';

function Card({ label, value, note }) {
  return <div className="card"><div className="muted">{label}</div><div className="value">{value}</div><div className="note">{note}</div></div>;
}

export default function App() {
  const [dashboard, setDashboard] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch(`${API}/api/dashboard`, { credentials: 'include' })
      .then(async r => { if (!r.ok) throw new Error(`API returned ${r.status}`); return r.json(); })
      .then(setDashboard)
      .catch(e => setError(e.message));
  }, []);

  const k = dashboard?.kpis || {};
  return <div className="app">
    <header><div><div className="eyebrow">HOMEY</div><h1>Work Insights</h1><p>Endpoint activity, productivity and compliance overview</p></div><div className="status">● Live</div></header>
    <main>
      {error && <div className="banner">Dashboard API is not authenticated yet. Connect the dashboard to the Homey API to load live metrics.</div>}
      <section className="grid">
        <Card label="Active users" value={k.users ?? '—'} note="Currently enabled" />
        <Card label="Managed devices" value={k.devices ?? '—'} note="macOS endpoints" />
        <Card label="Compliant devices" value={k.activeDevices ?? '—'} note="Current compliance" />
        <Card label="Activity hours" value={k.activityHours ?? '—'} note="Last 7 days" />
      </section>
      <section className="panel"><div className="panel-title"><div><h2>Work activity</h2><p>Homey endpoint insights</p></div><span className="pill">macOS fleet</span></div><div className="chart"><div className="bars">{[48,72,55,83,64,91,70,78,60,88,74,96].map((h,i)=><span key={i} style={{height:`${h}%`}} />)}</div><div className="days"><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span></div></div></section>
      <section className="two"><div className="panel"><h2>Endpoint health</h2><div className="health"><b>{k.compliance ?? '—'}%</b><span>Compliance</span></div><p className="muted">Use the Devices view to investigate individual Macs.</p></div><div className="panel"><h2>Deployment</h2><div className="item"><span>Homey Agent</span><strong>Ready</strong></div><div className="item"><span>MDM integration</span><strong>Scalefusion</strong></div><div className="item"><span>Screenshot monitoring</span><strong>Policy controlled</strong></div></div></section>
    </main>
  </div>;
}
