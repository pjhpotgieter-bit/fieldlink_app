#!/usr/bin/env node
// Set a Render service env var. Usage:
//   RENDER_API_KEY=... RENDER_SERVICE_ID=... node scripts/set_render_env.js ENABLE_PAYMENTS false
// Note: requires Render API key with permissions.

const https = require('https');

const [,, key, value] = process.argv;
const RENDER_API_KEY = process.env.RENDER_API_KEY;
const SERVICE_ID = process.env.RENDER_SERVICE_ID;

if (!key || typeof value === 'undefined') {
  console.error('Usage: node scripts/set_render_env.js KEY VALUE');
  process.exit(2);
}
if (!RENDER_API_KEY || !SERVICE_ID) {
  console.error('Please set RENDER_API_KEY and RENDER_SERVICE_ID in the environment');
  process.exit(2);
}

const payload = JSON.stringify({
  key,
  value: String(value),
  secure: false
});

const opts = {
  hostname: 'api.render.com',
  port: 443,
  path: `/v1/services/${SERVICE_ID}/env-vars`,
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${RENDER_API_KEY}`,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  },
};

const req = https.request(opts, (res) => {
  let body = '';
  res.on('data', (c) => body += c);
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    try { console.log('Response:', JSON.parse(body)); } catch { console.log('Response body:', body); }
  });
});
req.on('error', (e) => { console.error('Request error:', e); process.exit(1); });
req.write(payload);
req.end();
