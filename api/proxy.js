import fetch from 'node-fetch';

export default async function handler(req, res) {
  // --- CONFIGURATION ---
  const GITHUB_USER = 'cyberpriyo'; 
  const REPO_NAME = 'n8n';
  // ---------------------

  // 1. Get current URL
  // We use Date.now() to bust Vercel's server-side cache
  const rawUrl = `https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/n8n_url.txt?t=${Date.now()}`;
  
  let n8nBaseUrl = '';
  try {
    const urlResponse = await fetch(rawUrl, {
      headers: {
        Authorization: `token ${process.env.GITHUB_TOKEN}`
      }
    });
    
    if (!urlResponse.ok) throw new Error(`GitHub File Not Found: ${urlResponse.status}`);
    n8nBaseUrl = (await urlResponse.text()).trim();
  } catch (e) {
    return res.status(500).send(`Error reading n8n URL: ${e.message}`);
  }

  // 2. Validate URL
  if (!n8nBaseUrl.startsWith('http')) {
    return res.status(503).send(`n8n is restarting. Please wait 2 minutes.`);
  }

  const targetPath = req.url.replace(/^\/api\/proxy/, '');
  const targetUrl = `${n8nBaseUrl}${targetPath}`;

  // 3. Handle Browser Visits -> Redirect
  if (req.method === 'GET' && !req.url.includes('/webhook')) {
    // 🔥 NEW: Tell the browser "NEVER CACHE THIS REDIRECT"
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Expires', '0');
    return res.redirect(307, targetUrl);
  }

  // 4. Handle Webhooks -> Proxy
  try {
    const response = await fetch(targetUrl, {
      method: req.method,
      headers: {
        ...req.headers,
        host: new URL(n8nBaseUrl).host, 
      },
      body: req.method !== 'GET' && req.method !== 'HEAD' ? JSON.stringify(req.body) : undefined,
    });

    const data = await response.text();
    res.status(response.status).send(data);
  } catch (error) {
    res.status(502).send(`Failed to connect to n8n instance.`);
  }
}
