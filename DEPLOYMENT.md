Production deployment

This document shows simple production deployment options for the `index.js` backend.

Required environment variables

- `BREVO_API_KEY` - API key for Brevo (set in the host's env, do NOT commit)
- `BREVO_SENDER_EMAIL` - Optional sender email used by the service
- `PORT` - Set by most cloud hosts automatically; `index.js` respects `process.env.PORT`

Heroku (quick)

1. Login and create app:

```bash
heroku login
heroku create my-fieldlink-backend
```

2. Add Procfile (already present) and push:

```bash
git add Procfile
git commit -m "Add Procfile for Heroku"
git push heroku main
```

3. Set env vars:

```bash
heroku config:set BREVO_API_KEY=your_key_here BREVO_SENDER_EMAIL=your_sender@example.com
```

4. Open logs or tail:

```bash
heroku logs --tail
```

Render.com (recommended simple service)

1. Create a new Web Service on Render, connect your Git repo.
2. Choose "Node" and use the `start` script from `package.json` (already `node index.js`).
3. Add environment variables in Render's dashboard: `BREVO_API_KEY` and `BREVO_SENDER_EMAIL`.

Notes / recommendations

- Use HTTPS endpoints from mobile/web apps; cloud hosts provide HTTPS automatically.
- Keep `BREVO_API_KEY` as a secret in your host's environment settings.
- Verify the server is reachable by visiting `/health` after deploy.
- For high availability, use a managed host (Render, GCP, AWS Elastic Beanstalk, ECS, or similar).
