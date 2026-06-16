const dotenv = require('dotenv');
try { dotenv.config(); } catch (e) {}

// Import fetch compatible with node-fetch v2/v3 and Node 18+ global fetch
let fetch = undefined;
try {
  const nf = require('node-fetch');
  fetch = typeof nf === 'function' ? nf : nf && nf.default ? nf.default : undefined;
} catch (e) {
  fetch = typeof globalThis.fetch === 'function' ? globalThis.fetch : undefined;
}

function looksLikeBase64(s) {
  return typeof s === 'string' && /^[A-Za-z0-9+/=\r\n]+$/.test(s) && s.length % 4 === 0;
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' });
  const { toEmail, invoiceNumber, pdfBase64 } = req.body || {};

  if (!toEmail || !invoiceNumber || !pdfBase64) {
    return res.status(400).json({ error: 'Missing required fields: toEmail, invoiceNumber, pdfBase64' });
  }
  if (!looksLikeBase64(pdfBase64)) {
    return res.status(400).json({ error: 'pdfBase64 does not look like valid base64' });
  }

  try {
    const targetRecipient = process.env.BREVO_SENDER_EMAIL || 'fieldlink.farmerapp@gmail.com';
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
    if (!brevoResponse.ok) {
      const status = brevoResponse.status >= 400 && brevoResponse.status < 600 ? brevoResponse.status : 502;
      return res.status(status).json({ error: respText });
    }
    try { return res.status(200).json({ success: true, brevo: JSON.parse(respText) }); } catch (_) { return res.status(200).json({ success: true, brevo: respText }); }
  } catch (e) {
    console.error('Error sending invoice:', e && e.stack ? e.stack : e);
    return res.status(500).json({ error: e.message || String(e) });
  }
};
