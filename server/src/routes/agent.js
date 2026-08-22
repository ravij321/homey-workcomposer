import { Router } from 'express';
import crypto from 'node:crypto';
import { query } from '../db.js';

const router = Router();

function authorized(req) {
  const token=req.header('X-Homey-Agent-Token');
  const expected=process.env.HOMEY_AGENT_TOKEN;
  return Boolean(token && expected && token.length===expected.length && crypto.timingSafeEqual(Buffer.from(token),Buffer.from(expected)));
}

router.post('/status', async (req,res)=>{
  if(!authorized(req)) return res.status(401).json({error:'Unauthorized agent'});
  const deviceId=req.header('X-Homey-Device-ID');
  if(!deviceId) return res.status(400).json({error:'X-Homey-Device-ID is required'});
  try {
    const result=await query(`UPDATE devices SET last_seen_at=now(), updated_at=now() WHERE external_id=$1 OR serial_number=$1`,[deviceId]);
    if(result.rowCount===0) return res.status(404).json({error:'Unknown device'});
    res.json({ok:true});
  } catch { res.status(500).json({error:'Unable to update agent status'}); }
});

export default router;
