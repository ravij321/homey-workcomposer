import { Router } from 'express';
import { requireAuth } from '../auth.js';
import { requireRole } from '../roles.js';
import { query } from '../db.js';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

const router = Router();
const screenshotDir = process.env.SCREENSHOT_STORAGE_PATH || path.resolve('data/screenshots');

router.get('/', requireAuth, requireRole('admin','manager'), async (_req,res)=>{
  try {
    const r=await query(`SELECT s.id,s.device_id,d.name AS device_name,d.serial_number,u.name AS user_name,s.image_url,s.captured_at,s.admin_name,s.source FROM screenshots s LEFT JOIN devices d ON d.id=s.device_id LEFT JOIN users u ON u.id=d.user_id WHERE s.deleted_at IS NULL ORDER BY s.captured_at DESC LIMIT 100`);
    res.json({screenshots:r.rows});
  } catch { res.status(500).json({error:'Unable to load screenshots'}); }
});

router.post('/capture-request', requireAuth, requireRole('admin'), async(req,res)=>{
  const{device_id,reason}=req.body||{};
  if(!device_id)return res.status(400).json({error:'device_id is required'});
  try {
    const r=await query(`INSERT INTO screenshot_requests (device_id,requested_by,status,reason) VALUES ($1,$2,'pending',$3) RETURNING id,device_id,status,created_at`,[device_id,req.auth.sub,reason||'Authorized screenshot request']);
    await query(`INSERT INTO audit_events (actor_user_id,action,resource_type,resource_id,metadata) VALUES ($1,'screenshot.requested','device',$2,$3)`,[req.auth.sub,device_id,JSON.stringify({authorization:'approved',source:'Homey'})]);
    res.status(202).json({request:r.rows[0],message:'Authorized capture request created.'});
  } catch { res.status(500).json({error:'Unable to create screenshot request'}); }
});

router.post('/agent-upload', async(req,res)=>{
  const deviceId=req.header('X-Homey-Device-ID');
  const token=req.header('X-Homey-Agent-Token');
  const expected=process.env.HOMEY_AGENT_TOKEN;
  if(!deviceId || !token || !expected || token.length!==expected.length || !crypto.timingSafeEqual(Buffer.from(token),Buffer.from(expected))) return res.status(401).json({error:'Unauthorized agent'});
  try {
    const device=await query(`SELECT id FROM devices WHERE external_id=$1 OR serial_number=$1 LIMIT 1`,[deviceId]);
    if(!device.rows[0]) return res.status(404).json({error:'Unknown device'});
    const body=req.body;
    if(!Buffer.isBuffer(body) || body.length===0 || body.length>20*1024*1024) return res.status(400).json({error:'Invalid screenshot payload'});
    await fs.mkdir(screenshotDir,{recursive:true});
    const filename=`${device.rows[0].id}-${Date.now()}-${crypto.randomUUID()}.png`;
    await fs.writeFile(path.join(screenshotDir,filename),body,{flag:'wx'});
    const saved=await query(`INSERT INTO screenshots (device_id,image_url,captured_at,source) VALUES ($1,$2,now(),'agent') RETURNING id,captured_at`,[device.rows[0].id,`/screenshots/${filename}`]);
    res.status(201).json({screenshot:saved.rows[0]});
  } catch { res.status(500).json({error:'Unable to store screenshot'}); }
});

export default router;
