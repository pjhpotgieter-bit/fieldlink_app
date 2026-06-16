#!/usr/bin/env node
// Posts a sample invoice to the backend. Usage:
//    node scripts/post_sample_invoice.js [url]
// or set BACKEND_URL env var.

const https = require('https');
const http = require('http');
const { URL } = require('url');

const target = process.argv[2] || process.env.BACKEND_URL || 'http://127.0.0.1:3000/send-invoice';
console.log('Posting sample invoice to', target);

const sample = {
  toEmail: 'buyer@example.com',
  invoiceNumber: 'SAMPLE-001',
  pdfBase64: Buffer.from('Hello PDF').toString('base64'),
};

(async () => {
  try {
    const url = new URL(target);
    const payload = JSON.stringify(sample);
    const opts = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + (url.search || ''),
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const lib = url.protocol === 'https:' ? https : http;

    const res = await new Promise((resolve, reject) => {
      const req = lib.request(opts, (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => resolve({ status: res.statusCode, body }));
      });
      req.on('error', reject);
      req.write(payload);
      req.end();
    });

    console.log('Status:', res.status);
    console.log('Body:', res.body);
  } catch (e) {
    console.error('Error posting sample invoice:', e);
    process.exit(1);
  }
})();
