#!/usr/bin/env node
// Set a Vercel project environment variable via Vercel API.
// Usage:
//   VERCEL_TOKEN=... VERCEL_PROJECT_ID=... node scripts/set_vercel_env.js KEY VALUE

const https = require('https');

#!/usr/bin/env node
// Set a Vercel project environment variable via Vercel API.
// Usage:
//   VERCEL_TOKEN=... VERCEL_PROJECT_ID=... node scripts/set_vercel_env.js KEY VALUE

const https = require('https');

const [, , key, value] = process.argv;
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

function requestJson(method, path, body, attempts = 0) {
  const maxAttempts = 4;
  const payload = body ? JSON.stringify(body) : null;
  const opts = {
    hostname: 'api.vercel.com',
    port: 443,
    path,
    method,
    headers: {
      'Authorization': `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  };
  if (payload) opts.headers['Content-Length'] = Buffer.byteLength(payload);

  return new Promise((resolve, reject) => {
    const req = https.request(opts, (res) => {
      let body = '';
      res.on('data', (c) => body += c);
      res.on('end', () => {
        const status = res.statusCode || 0;
        let parsed = null;
        try { parsed = body ? JSON.parse(body) : null; } catch (e) { /* ignore */ }
        if (status >= 200 && status < 300) return resolve({ status, body: parsed });
        if ((status === 429 || (status >= 500 && status < 600)) && attempts < maxAttempts) {
          const wait = 200 * Math.pow(2, attempts);
          console.warn(`Request to ${path} returned ${status}. Retrying in ${wait}ms (attempt ${attempts+1})`);
          return setTimeout(() => {
            requestJson(method, path, body, attempts + 1).then(resolve).catch(reject);
          }, wait);
        }
        const err = new Error(`HTTP ${status} ${body}`);
        err.status = status;
        return reject(err);
      });
    });
    req.on('error', (e) => {
      if (attempts < maxAttempts) {
        const wait = 200 * Math.pow(2, attempts);
        console.warn(`Network error, retrying in ${wait}ms:`, e.message);
        return setTimeout(() => {
          requestJson(method, path, body, attempts + 1).then(resolve).catch(reject);
        }, wait);
      }
      reject(e);
    });
    if (payload) req.write(payload);
    req.end();
  });
}

async function ensureEnvVar(k, v) {
  const listPath = `/v9/projects/${PROJECT_ID}/env`;
  const list = await requestJson('GET', listPath, null).then(r => r.body).catch((e) => { throw new Error('Failed to list env vars: ' + e.message); });
  const found = Array.isArray(list) ? list.find((item) => item.key === k) : null;
  const payload = { value: String(v), target: ['production','preview','development'], type: 'encrypted' };
  if (found && found.id) {
    const updatePath = `/v9/projects/${PROJECT_ID}/env/${found.id}`;
    return requestJson('PATCH', updatePath, payload).then(r => r.body);
  } else {
    const createPath = `/v9/projects/${PROJECT_ID}/env`;
    const body = Object.assign({ key: k }, payload);
    return requestJson('POST', createPath, body).then(r => r.body);
  }
}

(async () => {
  try {
    console.log(`Setting Vercel env ${key} for project ${PROJECT_ID}`);
    const res = await ensureEnvVar(key, value);
    console.log('OK:', res);
  } catch (e) {
    console.error('Failed to set env var:', e && e.message ? e.message : e);
    process.exit(1);
  }
})();
  async function ensureEnvVar(key, value) {
    // List existing env vars
    const listPath = `/v9/projects/${PROJECT_ID}/env`;
    const list = await requestJson('GET', listPath, null).then(r => r.body).catch((e) => { throw new Error('Failed to list env vars: ' + e.message); });

    const found = Array.isArray(list) ? list.find((v) => v.key === key) : null;
    const payload = { value: String(value), target: ['production','preview','development'], type: 'encrypted' };

    if (found && found.id) {
      // Update existing
      const updatePath = `/v9/projects/${PROJECT_ID}/env/${found.id}`;
      return requestJson('PATCH', updatePath, payload).then(r => r.body);
    } else {
      // Create new
      const createPath = `/v9/projects/${PROJECT_ID}/env`;
      const body = Object.assign({ key }, payload);
      return requestJson('POST', createPath, body).then(r => r.body);
    }
  }

  (async () => {
    try {
      console.log(`Setting Vercel env ${key} for project ${PROJECT_ID}`);
      const res = await ensureEnvVar(key, value);
      console.log('OK:', res);
    } catch (e) {
      console.error('Failed to set env var:', e && e.message ? e.message : e);
      process.exit(1);
    }
  })();
