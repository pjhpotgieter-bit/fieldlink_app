module.exports = (req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') return res.status(405).send('Method Not Allowed');
  res.status(200).json({ service: 'fieldlink-backend', status: 'ok' });
};
