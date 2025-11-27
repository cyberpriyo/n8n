# 🚀 Infinite n8n Server (GitHub Actions + Google Drive + Vercel)

**A persistent, self-healing n8n instance running on GitHub Actions, backed up to Google Drive, and accessed via a stable Vercel URL.**

> **⚠️ WARNING:** This project uses GitHub Actions for long-running processes (hosting), which technically violates GitHub Terms of Service. Use strictly for educational/personal research purposes. Do not use for mission-critical business data.

---

## 🏗️ Architecture

This system uses three components to create a "fake" VPS experience:

1.  **The Host (GitHub Actions):** Runs the n8n Docker container. It resets every ~6 hours (GitHub hard limit).
2.  **The Storage (Google Drive):** Uses **Rclone** to sync your n8n data to a private folder in Google Drive every **10 minutes**.
3.  **The Proxy (Vercel):** A Serverless Function that acts as a "Traffic Director."
    * **Humans:** Redirects browser visits to the *current* Cloudflare URL.
    * **Robots (Webhooks):** Proxies API requests silently to the n8n server.

**Data Persistence:**
* **Frequency:** Backups run every **10 minutes**.
* **Retention:** Keeps the last **20 backups** (approx. 3.5 hours of rollbacks) in Google Drive.
* **Recovery:** On restart, the system automatically pulls the latest backup (`backup_1.tar.gz`) from Google Drive.

---

## ⚡ Quick Links

* **Stable Access URL:** `https://n8n-priyo.vercel.app`
* **Health Check:** `https://n8n-priyo.vercel.app/healthz`
* **Webhook Base URL:** `https://n8n-priyo.vercel.app/api/proxy`

---

## 🛠️ Configuration & Secrets

### 1. GitHub Repository Secrets
Go to `Settings` > `Secrets and variables` > `Actions`:

| Secret Name | Description |
| :--- | :--- |
| `GH_PAT` | **Personal Access Token.** Needs `repo` and `workflow` scopes. Used to bypass the GitHub bot restriction to trigger self-restarts. |
| `DISCORD_WEBHOOK` | URL of the Discord channel where the bot posts the new server link and status updates. |
| `RCLONE_CONFIG` | The content of your `rclone.conf` file containing the Google Drive token. |
| `N8N_BASIC_AUTH_USER` | Username for Basic Auth (Required for security since the repo/URL is public). |
| `N8N_BASIC_AUTH_PASSWORD` | Password for Basic Auth. |

### 2. Vercel Environment Variables
Go to Vercel Project > `Settings` > `Environment Variables`:

| Variable Name | Description |
| :--- | :--- |
| `GITHUB_TOKEN` | Value: Paste your `GH_PAT` here. Required for Vercel to read the private `n8n_url.txt` file from GitHub. |

### 3. Vercel Git Settings (Optimization)
To prevent Vercel from burning build minutes every time the bot updates the URL:
* **Ignored Build Step:**
    ```bash
    if [ "$VERCEL_GIT_COMMIT_AUTHOR_NAME" == "n8n-hosting-bot" ]; then exit 0; else exit 1; fi
    ```

---

## 📂 File Structure Explained

* **`.github/workflows/n8n.yml`**: The brain.
    * Installs Rclone and injects the config.
    * Restores the latest backup from Google Drive.
    * Runs n8n in Docker with Basic Auth enabled.
    * Starts Cloudflare Tunnel.
    * Updates `n8n_url.txt` with the new tunnel URL.
* **`backup.sh`**: The heartbeat.
    * Runs in the background.
    * Uploads a backup to Google Drive every **10 mins**.
    * Rotates files (keeps `backup_1` through `backup_20`).
    * **At 5.5 Hours:** Forces a final save, triggers a new workflow run, and shuts down.
* **`api/proxy.js`**: The Vercel Middleware.
    * Reads `n8n_url.txt` from GitHub.
    * Handles the logic: If Browser -> Redirect; If Webhook -> Proxy.
* **`n8n_url.txt`**: A dynamic file containing the currently active Cloudflare URL.

---

## 🔄 The Lifecycle (The "Reset" Loop)

1.  **Start (0h:00m):** Server boots. Latest backup pulled from GDrive. New Cloudflare URL generated.
2.  **Notification:** Discord receives "🚀 n8n is Online" with the new URL.
3.  **Operation (0h - 5h:30m):**
    * Server runs normally.
    * `backup.sh` uploads encrypted data to Google Drive every 10 mins.
4.  **Handover (5h:30m):**
    * `backup.sh` initiates "Restart Sequence".
    * Final "Safety Backup" is uploaded.
    * New Workflow is triggered via `gh` CLI.
    * Current runner shuts down.
5.  **Downtime (~5-10 mins):**
    * *The "Gap of Death."* The old server is dead. The new one is booting.
    * Vercel will return `503: n8n is restarting`.

---

## 🔗 How to Use Webhooks & OAuth

Since the physical URL changes, **NEVER** use the `trycloudflare.com` address for external services.

### 1. General Webhooks
If a service (e.g., GitHub, Stripe) asks for a webhook URL, use:
> `https://n8n-priyo.vercel.app/api/proxy/webhook/YOUR-WEBHOOK-ID`

### 2. Google / OAuth Redirects
If configuring a Google Cloud App or any OAuth service:
* **Authorized Redirect URI:** `https://n8n-priyo.vercel.app/api/proxy/rest/oauth2-credential/callback`

---

## 🚑 Troubleshooting

### "Connection Lost" in n8n Editor
* **Cause:** Vercel Serverless functions do not support WebSockets.
* **Fix:** Ignore it. The workflows are running. Refresh the page to see execution results.

### "401 Unauthorized"
* **Cause:** Basic Auth is enabled for security.
* **Fix:** Enter the Username and Password you set in your GitHub Secrets (`N8N_BASIC_AUTH_USER`).

### Server didn't restart automatically
* **Fix:**
    1.  Go to GitHub Repo > **Actions**.
    2.  Select **n8n-hosting**.
    3.  Click **Run workflow** manually.
    4.  It will pick up the last backup from Google Drive automatically.

---

## 🧾 Credits

* **n8n:** Fair-code licensed (Sustainable Use License).
* **Cloudflared:** MIT License.
* **Rclone:** MIT License.
