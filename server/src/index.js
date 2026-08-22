import express from 'express';
import cors from 'cors';
import integrations from './routes/integrations.js';

const app = express();
const port = process.env.PORT || 4000;
app.use(cors());
app.use(express.json());
app.use('/api/integrations', integrations);

const state = { users: 42, devices: 70, activeDevices: 68, activityHours: 284, compliance: 97 };

app.get('/api/health', (_req, res) => res.json({ ok: true, service: 'homey-work-insights-api' }));
app.get('/api/dashboard', (_req, res) => res.json({
  kpis: state,
  activity: [{day:'Mon',hours:38},{day:'Tue',hours:44},{day:'Wed',hours:41},{day:'Thu',hours:47},{day:'Fri',hours:43}],
  departments: [{name:'Technology',hours:126},{name:'Operations',hours:82},{name:'Sales',hours:51},{name:'Management',hours:25}],
  applications: [{name:'VS Code',minutes:4820},{name:'Google Chrome',minutes:4310},{name:'Slack',minutes:2940},{name:'Terminal',minutes:2180}]
}));
app.get('/api/devices', (_req, res) => res.json({ devices: [
  {id:'MAC-001',name:'Homey-MBP-001',user:'Technology User',os:'macOS',status:'Compliant'},
  {id:'MAC-002',name:'Homey-MBP-002',user:'Operations User',os:'macOS',status:'Compliant'},
  {id:'MAC-003',name:'Homey-MBP-003',user:'Sales User',os:'macOS',status:'At Risk'}
]}));

app.listen(port, () => console.log(`Homey Work Insights API listening on ${port}`));
