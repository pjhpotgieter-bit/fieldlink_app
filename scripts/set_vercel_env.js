#!/usr/bin/env node
// Set a Vercel project environment variable via Vercel API.
// Usage:
//   VERCEL_TOKEN=... VERCEL_PROJECT_ID=... node scripts/set_vercel_env.js KEY VALUE

const https = require('https');

const [,, key, value] = process.argv;
const TOKEN = process.env.VERCEL_TOKEN;
const PROJECT_ID = process.env.VERCEL_PROJECT_ID;

if (!key || typeof value === 'undefined') {
  console.error('Usage: node scripts/set_vercel_env.js KEY VALUE');
  process.exit(2);
}
if (!TOKEN || !PROJECT_ID) {
  console.error('Please set VERCEL_TOKEN and VERCEL_PROJECT_ID in the environment');
  process.exit(2);
}

const payload = JSON.stringify({
  key,
  value: String(value),
  target: ['production','preview','development'],
  type: 'encrypted'
});

const opts = {
  hostname: 'api.vercel.com',
  port: 443,
  path: `/v9/projects/${PROJECT_ID}/env`,
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${TOKEN}`,
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
