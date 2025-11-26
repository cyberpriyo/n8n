# 🚀 Infinite n8n Server (GitHub Actions + Vercel Proxy)

**A persistent, self-healing n8n instance running entirely on GitHub Actions Free Tier, accessed via a stable Vercel URL.**

> **⚠️ WARNING:** This project uses GitHub Actions for long-running processes (hosting), which technically violates GitHub Terms of Service. Use strictly for educational/personal research purposes. Do not use for mission-critical business data.

---

## 🏗️ Architecture

This system uses three components to create a "fake" VPS experience:

1.  ** The Host (GitHub Actions):** Runs the n8n Docker container. It resets every 6 hours (GitHub hard limit).
2.  **The Tunnel (Cloudflared):** Exposes the local Docker port (`5678`) to the public internet via a random URL.
3.  **The Proxy (Vercel):** A Serverless Function that acts as a "Traffic Director."
    * **Humans:** Redirects browser visits to the *current* Cloudflare URL.
    * **Robots (Webhooks):** Proxies API requests silently to the n8n server.

**Data Persistence:**
* An automated script backs up the `.n8n` directory (database & encryption keys) to this Git repository every **30 minutes**.
* When the server restarts, it pulls the latest backup, restoring your account and workflows exactly where you left off.

---

## ⚡ Quick Links

* **Stable Access URL:** `https://n8n-priyo.vercel.app` (Bookmark this)
* **Health Check:** `https://n8n-priyo.vercel.app/healthz` (Returns JSON status)
* **Webhook Base URL:** `https://n8n-priyo.vercel.app/api/proxy`

---

## 🛠️ Configuration & Secrets

To redeploy or replicate this setup, ensure the following configuration exists.

### 1. GitHub Repository Secrets
Go to `Settings` > `Secrets and variables` > `Actions`:

| Secret Name | Description |
| :--- | :--- |
| `GH_PAT` | **Personal Access Token.** Needs `repo` and `workflow` scopes. Used to bypass the GitHub bot restriction and trigger self-restarts. |
| `DISCORD_WEBHOOK` | URL of the Discord channel where the bot posts the new server link and status updates. |

### 2. Vercel Environment Variables
Go to Vercel Project > `Settings` > `Environment Variables`:

| Variable Name | Description |
| :--- | :--- |
| `GITHUB_TOKEN` | Value: Paste your `GH_PAT` here. Required for Vercel to read the private `n8n_url.txt` file from GitHub. |

### 3. Vercel Git Settings
To prevent Vercel from rebuilding the site every time the bot updates the URL text file:
* **Ignored Build Step:** `if [ "$VERCEL_GIT_COMMIT_AUTHOR_NAME" == "URL Bot" ]; then exit 0; else exit 1; fi`

---

## 📂 File Structure Explained

* **`.github/workflows/n8n.yml`**: The brain.
    * Sets up Ubuntu environment.
    * Restores the latest `backup_*.tar.gz`.
    * Runs n8n in Docker.
    * Starts Cloudflare Tunnel.
    * Updates `n8n_url.txt` with the new tunnel URL.
    * Triggers `backup.sh`.
* **`backup.sh`**: The heartbeat.
    * Runs in the background.
    * Creates a backup every 30 mins.
    * **At 5.5 Hours:** Forces a final backup, triggers a new workflow run via `gh cli`, and kills the current runner.
* **`api/proxy.js`**: The Vercel Middleware.
    * Reads `n8n_url.txt` from GitHub.
    * Handles the logic: If Browser -> Redirect; If Webhook -> Proxy.
* **`n8n_url.txt`**: A dynamic file containing the currently active Cloudflare URL.

---

## 🔄 The Lifecycle (The "Reset" Loop)

1.  **Start (0h:00m):** Server boots. Latest backup restored. New Cloudflare URL generated.
2.  **Notification:** Discord receives "🚀 n8n is Online" with the new URL.
3.  **Operation (0h - 5h:30m):**
    * Server runs normally.
    * `backup.sh` commits data to Git every 30 mins.
    * Old backups are rotated (Max 5 kept).
4.  **Handover (5h:30m):**
    * `backup.sh` initiates "Restart Sequence".
    * Final "Safety Backup" is pushed.
    * New Workflow is triggered (`gh workflow run`).
    * Current runner shuts down.
5.  **Downtime (~5-10 mins):**
    * *The "Gap of Death."* The old server is dead. The new one is booting.
    * Vercel will return `503: n8n is restarting`.
    * **Any webhooks sent during this window will fail.**

---

## 🔗 How to Use Webhooks & OAuth

Since the physical URL changes, **NEVER** use the `trycloudflare.com` address for external services.

### 1. General Webhooks
If a service (e.g., GitHub, Stripe) asks for a webhook URL, use:
> `https://n8n-priyo.vercel.app/api/proxy/webhook/YOUR-WEBHOOK-ID`

### 2. Google / OAuth Redirects
If configuring a Google Cloud App or any OAuth service:
* **Authorized Redirect URI:** `https://n8n-priyo.vercel.app/api/proxy/rest/oauth2-credential/callback`

### 3. n8n Editor Settings
The Docker container is launched with these variables to ensure n8n generates the correct URLs in the UI:
```bash
-e WEBHOOK_URL=[https://n8n-priyo.vercel.app/api/proxy](https://n8n-priyo.vercel.app/api/proxy)
-e VUE_APP_URL_BASE_API=[https://n8n-priyo.vercel.app/api/proxy](https://n8n-priyo.vercel.app/api/proxy)
````

-----

## 🚑 Troubleshooting

### "Connection Lost" in n8n Editor

  * **Cause:** Vercel Serverless functions do not support WebSockets (the technology n8n uses for real-time UI updates).
  * **Fix:** Ignore it. The workflows are running. Refresh the page to see execution results.

### Vercel shows "404 Not Found"

  * **Cause:** Missing `vercel.json` or `index.html`.
  * **Fix:** Ensure `vercel.json` exists in the root with the rewrite rule `{ "source": "/(.*)", "destination": "/api/proxy" }`.

### Server didn't restart automatically

  * **Cause:** GitHub Actions glitch or API outage.
  * **Fix:**
    1.  Go to GitHub Repo \> **Actions**.
    2.  Select **n8n-hosting**.
    3.  Click **Run workflow** manually.
    4.  It will pick up the last backup and resume.

### "Bad Gateway" or "500 Error" on Vercel

  * **Cause:** The server is currently in the "Restart Gap" or the GitHub Token in Vercel is invalid.
  * **Fix:** Wait 10 minutes. If still down, check Vercel logs to see if it can read `n8n_url.txt`.

-----

## 🧾 License & Credits

  * **n8n:** Fair-code licensed (Sustainable Use License).
  * **Cloudflared:** MIT License.
  * **Concept:** "The Phoenix Server" methodology.

```
