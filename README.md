# 🚀 Infinite n8n Server (GitHub Actions + Google Drive + Vercel)

**A persistent, self-healing n8n instance running on GitHub Actions, backed up to Google Drive, and accessed via a stable Vercel URL.**

> **⚠️ WARNING:** This project uses GitHub Actions for long-running processes (hosting), which technically violates GitHub Terms of Service. Use strictly for educational/personal research purposes. Do not use for mission-critical business data.

---

## 🏗️ Architecture

This system uses four components to create a robust, "fake" VPS experience:

1.  **The Host (GitHub Actions):** Runs the n8n Docker container. It resets every ~5.5 hours to avoid timeouts.
2.  **The Storage (Google Drive):** Uses **Rclone** to sync your n8n data to a private folder in Google Drive every **10 minutes**.
3.  **The Proxy (Vercel):** A Serverless Function that acts as a "Traffic Director" and handles browser redirection.
4.  **The Buffer (Hookdeck):** *Optional but Recommended.* Queues incoming webhooks during server restarts to ensure **Zero Data Loss**.

**Data Persistence:**
* **Frequency:** Backups run every **10 minutes**.
* **Retention:** Keeps the last **20 backups** (approx. 3.5 hours of rollbacks) in Google Drive.
* **Recovery:** On restart, the system automatically pulls the latest backup (`backup_1.tar.gz`) from Google Drive.

---

## ⚡ Quick Links

* **Stable Editor URL:** `https://n8n-priyo.vercel.app` (Use this to access the UI)
* **Health Check:** `https://n8n-priyo.vercel.app/healthz`
* **Webhook Base URL:** `https://n8n-priyo.vercel.app/api/proxy`

---

## 🛠️ Configuration & Secrets

### 1. GitHub Repository Secrets
Go to `Settings` > `Secrets and variables` > `Actions`:

| Secret Name | Description |
| :--- | :--- |
| `GH_PAT` | **Personal Access Token.** Needs `repo` and `workflow` scopes. Used to bypass the GitHub bot restriction to trigger self-restarts. |
| `DISCORD_WEBHOOK` | URL of the Discord channel where the bot posts status updates (Start/Stop/New URLs). |
| `RCLONE_CONFIG` | The content of your `rclone.conf` file containing the Google Drive token. |
| `N8N_BASIC_AUTH_USER` | **Required.** Username for Basic Auth (Blocks unauthorized bots from accessing your public URL). |
| `N8N_BASIC_AUTH_PASSWORD` | **Required.** Password for Basic Auth. |

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
    * **Configures n8n to generate Hookdeck URLs automatically.**
    * Starts Cloudflare Tunnel & updates `n8n_url.txt`.
* **`backup.sh`**: The heartbeat.
    * Uploads a backup to Google Drive every **10 mins**.
    * Rotates files (keeps `backup_1` through `backup_20`).
    * **At 5 Hours:** Sends a "Goodbye" Discord alert, forces a final save, triggers a new workflow run, and shuts down.
* **`api/proxy.js`**: The Vercel Middleware.
    * Reads `n8n_url.txt` from GitHub.
    * Handles the logic: If Browser -> Redirect; If Webhook -> Proxy.

---

## 🔄 The Lifecycle (The "Reset" Loop)

1.  **Start (0h:00m):** Server boots. Latest backup pulled from GDrive. New Cloudflare URL generated.
2.  **Notification:** Discord receives "🚀 n8n is Online".
3.  **Operation (0h - 5h:00m):**
    * Server runs normally.
    * `backup.sh` uploads encrypted data to Google Drive every 10 mins.
4.  **Handover (5h:00m):**
    * `backup.sh` sends **"⚠️ n8n Restarting..."** to Discord.
    * Final "Safety Backup" is uploaded.
    * New Workflow is triggered via `gh` CLI.
    * Current runner shuts down.
5.  **Downtime (~5-10 mins):**
    * *The "Gap of Death."* The old server is dead. The new one is booting.
    * **Hookdeck** catches all incoming webhooks and holds them.

---

## 🔗 Webhooks & Zero-Downtime Strategy

Since the server physically restarts 4 times a day, we use **Hookdeck** to buffer webhooks so no data is lost.

### 1. Setup Hookdeck (The Buffer)
1.  Create a **Source** in Hookdeck (e.g., `n8n-universal`).
2.  Create a **Destination** pointing to your Vercel Proxy:
    * `https://n8n-priyo.vercel.app/api/proxy`
3.  Copy your Hookdeck Source URL (e.g., `https://hkdk.events/xxxx`).
4.  Add this URL to your `n8n.yml` under the `WEBHOOK_URL` environment variable.

### 2. Using Webhooks
* **In the n8n Editor:** When you create a webhook node, it will automatically show your **Hookdeck URL**.
* **External Services (GitHub/Stripe):** Always use the Hookdeck URL.
    * *Server Online:* Hookdeck -> Vercel -> n8n (Instant).
    * *Server Restarting:* Hookdeck -> **Queue (Wait)** -> Retry -> n8n (Delayed, but safe).

### 3. Google / OAuth Redirects
OAuth callbacks cannot be buffered, so they must go through Vercel directly:
* **Authorized Redirect URI:** `https://n8n-priyo.vercel.app/api/proxy/rest/oauth2-credential/callback`

---

## 🚑 Troubleshooting

### "Connection Lost" in n8n Editor
* **Cause:** Vercel Serverless functions do not support WebSockets.
* **Fix:** Ignore it. The workflows are running. Refresh the page to see execution results.

### "401 Unauthorized"
* **Cause:** Basic Auth is enabled.
* **Fix:** Enter the Username/Password you set in GitHub Secrets.

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
* **Hookdeck:** Free tier used for webhook buffering.
