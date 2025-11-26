#!/bin/bash

# --- CONFIGURATION ---
BACKUP_DIR="backups"
DATA_DIR="n8n-data"
SLEEP_SECONDS=1800 # 30 Minutes
MAX_LOOPS=11       # 5.5 Hours
CURRENT_LOOP=0
WORKFLOW_FILE="n8n.yml"

mkdir -p $BACKUP_DIR

# --- GIT RELOAD FUNCTION ---
# This wipes the history to keep the repo size tiny (prevents bloating)
setup_git_and_push() {
    MESSAGE=$1
    
    # 1. Delete history
    rm -rf .git
    
    # 2. Re-initialize
    git init
    git config --global user.email "bot@n8n.com"
    git config --global user.name "n8n Bot"
    
    # 3. Add files
    git add .
    
    # 4. Commit
    git commit -m "$MESSAGE"
    
    # 5. Force Push (Using the GH_TOKEN for Auth)
    # We use quiet (-q) to prevent the token from leaking in logs
    git remote add origin "https://oauth2:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}"
    git push -q -f -u origin main
}

# --- THE LOOP ---
while [ $CURRENT_LOOP -lt $MAX_LOOPS ]; do
    echo "--- Loop $((CURRENT_LOOP+1)) of $MAX_LOOPS ---"
    echo "Waiting $SLEEP_SECONDS seconds..."
    sleep $SLEEP_SECONDS

    # 1. Zip the data
    echo "🗜️ Zipping data..."
    tar -czf temp_backup.tar.gz "$DATA_DIR" 2>/dev/null

    # 2. Encrypt the zip
    # We overwrite the SAME file to save space.
    echo "🔒 Encrypting data..."
    openssl enc -aes-256-cbc -salt -pbkdf2 -in temp_backup.tar.gz -out "$BACKUP_DIR/backup_latest.enc" -k "$BACKUP_PASSWORD"
    
    # 3. Cleanup raw file
    rm temp_backup.tar.gz

    # 4. Wipe History & Force Push
    echo "🚀 Pushing to GitHub (History Wiped)..."
    setup_git_and_push "Auto-save: Loop $((CURRENT_LOOP+1))"

    ((CURRENT_LOOP++))
done

# --- RESTART SEQUENCE (5.5 Hours) ---
echo "⏳ 5.5 Hours reached. Performing final save..."

# Final Backup
tar -czf temp_backup.tar.gz "$DATA_DIR" 2>/dev/null
openssl enc -aes-256-cbc -salt -pbkdf2 -in temp_backup.tar.gz -out "$BACKUP_DIR/backup_latest.enc" -k "$BACKUP_PASSWORD"
rm temp_backup.tar.gz

# Final Push
setup_git_and_push "Final Save before Restart"

echo "🔄 Triggering new runner..."
gh workflow run "$WORKFLOW_FILE" --ref main

echo "✅ Done. Shutting down."
exit 0
