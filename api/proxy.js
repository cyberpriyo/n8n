import fetch from 'node-fetch';

export default async function handler(req, res) {
  // --- CONFIGURATION ---
  const GITHUB_USER = 'cyberpriyo'; 
  const REPO_NAME = 'n8n';
  // ---------------------

  // 1. Get the current dynamic n8n URL from GitHub
  // We now use the GITHUB_TOKEN to authenticate because the repo is private
  const rawUrl = `https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/n8n_url.txt?t=${Date.now()}`;
  
  let n8nBaseUrl = '';
  try {
    const urlResponse = await fetch(rawUrl, {
      headers: {
        // This line authorizes Vercel to read your private file
        Authorization: `token ${process.env.GITHUB_TOKEN}`
      }
    });
    
    // Check if the file was actually found
    if (!urlResponse.ok) {
       throw new Error(`GitHub File Not Found: ${urlResponse.status}`);
    }

    n8nBaseUrl = (await urlResponse.text()).trim();
  } catch (e) {
    // If we can't read the file, print the error to help debug
    return res.status(500).send(`Error reading n8n URL: ${e.message}`);
  }

  // 2. Security Check: Ensure we got a valid URL
  if (!n8nBaseUrl.startsWith('http')) {
    return res.status(503).send(`n8n is currently restarting (Invalid URL found: ${n8nBaseUrl}). Please wait 2 minutes.`);
  }

  // 3. Construct the full target URL
  const targetPath = req.url.replace(/^\/api\/proxy/, '');
  const targetUrl = `${n8nBaseUrl}${targetPath}`;

  // 4. Handle Browser Visits (GET requests) -> Redirect
  if (req.method === 'GET' && !req.url.includes('/webhook')) {
    return res.redirect(307, targetUrl);
  }

  // 5. Handle Webhooks (POST/PUT/etc) -> Proxy
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
    res.status(502).send(`Failed to connect to n8n instance: ${error.message}`);
  }
}
