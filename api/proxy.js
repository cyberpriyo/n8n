import fetch from 'node-fetch';

export default async function handler(req, res) {
  // --- CONFIGURATION ---
  // REPLACE 'YOUR_USERNAME' WITH YOUR GITHUB USERNAME BELOW
  const GITHUB_USER = 'cyberpriyo'; 
  const REPO_NAME = 'n8n';
  // ---------------------

  // 1. Get the current dynamic n8n URL from your raw GitHub text file
  // We add a timestamp query (?t=...) to bypass Vercel's aggressive caching
  const rawUrl = `https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/n8n_url.txt?t=${Date.now()}`;
  
  let n8nBaseUrl = '';
  try {
    const urlResponse = await fetch(rawUrl);
    n8nBaseUrl = (await urlResponse.text()).trim();
  } catch (e) {
    return res.status(500).send('Error fetching n8n URL');
  }

  // 2. Security Check: Ensure we got a valid URL
  if (!n8nBaseUrl.startsWith('http')) {
    return res.status(503).send('n8n is currently restarting. Please wait 2 minutes.');
  }

  // 3. Construct the full target URL
  // We strip '/api/proxy' if it exists, to forward the path correctly
  const targetPath = req.url.replace(/^\/api\/proxy/, '');
  const targetUrl = `${n8nBaseUrl}${targetPath}`;

  // 4. Handle Browser Visits (GET requests) -> Redirect
  // We redirect browsers so you can see the n8n UI natively
  if (req.method === 'GET' && !req.url.includes('/webhook')) {
    return res.redirect(307, targetUrl);
  }

  // 5. Handle Webhooks (POST/PUT/etc) -> Proxy
  // We forward the data silently so the external service thinks Vercel is the server
  try {
    const response = await fetch(targetUrl, {
      method: req.method,
      headers: {
        ...req.headers,
        host: new URL(n8nBaseUrl).host, // Spoof the host header
      },
      body: req.method !== 'GET' && req.method !== 'HEAD' ? JSON.stringify(req.body) : undefined,
    });

    // Send back the n8n response to the caller
    const data = await response.text();
    res.status(response.status).send(data);
  } catch (error) {
    res.status(502).send(`Failed to connect to n8n instance: ${error.message}`);
  }
}
