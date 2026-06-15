const dotenv = require('dotenv');
dotenv.config();
// Safe debug: indicate whether BREVO key was loaded (do not print the key)
console.log('BREVO_API_KEY present:', !!process.env.BREVO_API_KEY, 'length:', process.env.BREVO_API_KEY ? process.env.BREVO_API_KEY.length : 0);
// Import fetch with compatibility for node-fetch v2 (function) and v3 (ESM default).
let fetch = undefined;
try {
  const nf = require('node-fetch');
  fetch = typeof nf === 'function' ? nf : nf && nf.default ? nf.default : undefined;
} catch (e) {
  // node-fetch not installed or require failed; fall back to global fetch if available
  fetch = typeof globalThis.fetch === 'function' ? globalThis.fetch : undefined;
}

if (!fetch) {
  // Provide a helpful startup error rather than failing later in a request
  console.error('fetch is not available. Install node-fetch or run on Node 18+ with global fetch.');
}
const express = require('express');
const cors = require('cors');
const app = express();
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ limit: '20mb', extended: true }));
app.use(cors());

// Helper: quick base64-ish check (not exhaustive)
function looksLikeBase64(s) {
  return typeof s === 'string' && /^[A-Za-z0-9+/=\r\n]+$/.test(s) && s.length % 4 === 0;
}

app.post('/send-invoice', async (req, res) => {
  const { toEmail, invoiceNumber, pdfBase64 } = req.body;

  console.log('POST /send-invoice body:', { toEmail, invoiceNumber, hasPdf: !!pdfBase64 });

  if (!toEmail || !invoiceNumber || !pdfBase64) {
    return res.status(400).json({ error: 'Missing required fields: toEmail, invoiceNumber, pdfBase64' });
  }

  if (!looksLikeBase64(pdfBase64)) {
    return res.status(400).json({ error: 'pdfBase64 does not look like valid base64' });
  }

  try {
    const targetRecipient = process.env.BREVO_SENDER_EMAIL || 'fieldlink.farmerapp@gmail.com';
    console.log('Sending invoice email to recipient:', targetRecipient, 'replyTo(buyer):', toEmail);

    const brevoResponse = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'api-key': process.env.BREVO_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        sender: { name: 'FieldLink', email: targetRecipient },
        to: [{ email: targetRecipient }],
        replyTo: { email: toEmail },
        subject: `Invoice #${invoiceNumber} - Payment`,
        htmlContent: `<h2>Payment Successful ✅</h2><p>Invoice #${invoiceNumber} attached.</p><p>Buyer: ${toEmail}</p>`,
        attachment: [{ content: pdfBase64, name: 'invoice.pdf' }],
      }),
    });

    const respText = await brevoResponse.text();
    console.log('Brevo response status:', brevoResponse.status, 'body:', respText);

    if (!brevoResponse.ok) {
      // forward Brevo status and body to client to aid debugging
      const status = brevoResponse.status >= 400 && brevoResponse.status < 600 ? brevoResponse.status : 502;
      return res.status(status).json({ error: respText });
    }

    // try to return JSON if Brevo returned JSON
    try {
      const json = JSON.parse(respText);
      return res.status(200).json({ success: true, brevo: json });
    } catch (_) {
      return res.status(200).json({ success: true, brevo: respText });
    }
  } catch (e) {
    console.error('Error sending invoice:', e.stack || e);
    return res.status(500).json({ error: e.message });
  }
});

// Basic status endpoints
app.get('/', (req, res) => {
  res.json({ service: 'fieldlink-backend', status: 'ok', port: 3000 });
});

app.get('/health', (req, res) => res.status(200).send('ok'));

// Start server and add error handling
const server = app.listen(3000, '0.0.0.0', () => {
  const addr = server.address();
  const host = addr && addr.address ? addr.address : '0.0.0.0';
  const port = addr && addr.port ? addr.port : 3000;
  console.log(`Backend listening on ${host}:${port}`);
});

server.on('error', (err) => {
  console.error('Server error:', err && err.stack ? err.stack : err);
  if (err && err.code === 'EADDRINUSE') {
    console.error('Port 3000 is already in use. Is another instance running?');
  }
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason && reason.stack ? reason.stack : reason);
});

process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err && err.stack ? err.stack : err);
});