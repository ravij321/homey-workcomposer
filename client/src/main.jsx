import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const API = import.meta.env.VITE_API_URL || 'http://localhost:4000';

function App() {
  const [data, setData] = useState(null);
  useEffect(() => { fetch(`${API}/api/dashboard`).then(r => r.json()).then(setData).catch(() => setData(null)); }, []);
  const k = data?.kpis;
  return <div className="app">
    <aside><div className="brand">HOMEY<span>•</span></div><div className="subtitle">WORK INSIGHTS</div>{['Overview','Activity','Devices','Users','Departments','Applications','MDM Health','Audit Logs','Settings'].map((x,i)=><div className={`nav ${i===0?'active':''}`} key={x}>{x}</div>)}</aside>
    <main><header><div><p className="eyebrow">WORKFORCE INTELLIGENCE</p><h1>Overview</h1><p className="muted">Real-time operational insight across Homey endpoints.</p></div><button>Export report</button></header>
    <section className="cards">{[['Active Users',k?.users ?? '—','people'],['Managed Devices',k?.devices ?? '—','endpoints'],['Activity Hours',k?.activityHours ?? '—','this week'],['Compliance',k?.compliance ? `${k.compliance}%` : '—','MDM health']].map(([a,b,c])=><div className="card" key={a}><div className="label">{a}</div><strong>{b}</strong><span>{c}</span></div>)}</section>
    <section className="grid"><div className="panel wide"><h2>Work activity</h2><div className="bars">{data?.activity?.map(x=><div className="bar" key={x.day}><div style={{height:`${x.hours*2}px`}}></div><span>{x.day}</span></div>)}</div></div><div className="panel"><h2>Departments</h2>{data?.departments?.map(x=><div className="row" key={x.name}><span>{x.name}</span><b>{x.hours}h</b></div>)}</div></section>
    <section className="grid"><div className="panel"><h2>Top applications</h2>{data?.applications?.map(x=><div className="row" key={x.name}><span>{x.name}</span><b>{Math.round(x.minutes/60)}h</b></div>)}</div><div className="panel"><h2>MDM status</h2><div className="status"><i></i><div><b>Scalefusion connected</b><small>Device inventory sync enabled</small></div></div><div className="status"><i></i><div><b>{k?.activeDevices ?? '—'} active devices</b><small>Healthy management state</small></div></div></div></section>
    </main></div>
}
createRoot(document.getElementById('root')).render(<App />);
