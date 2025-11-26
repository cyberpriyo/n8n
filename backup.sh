#!/bin/bash

# --- CONFIGURATION ---
BACKUP_DIR="backups"
DATA_DIR="n8n-data"
SLEEP_SECONDS=1800 # 30 Minutes
MAX_LOOPS=11       # 5.5 Hours
CURRENT_LOOP=0
WORKFLOW_FILE="n8n.yml"

# Ensure backup dir exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "📂 Creating backup directory..."
    mkdir -p $BACKUP_DIR
fi

# --- GIT RELOAD FUNCTION ---
# This wipes the history to keep the repo size tiny (prevents bloating)
setup_git_and_push() {
    MESSAGE=$1
    
    echo "⚙️ Configuring Git..."
    
    # 1. Delete history (The Amnesiac Step)
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
    # We add error handling here
    git remote add origin "https://oauth2:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}"
    
    echo "🚀 Pushing to GitHub..."
    if git push -q -f -u origin main; then
        echo "✅ Push successful."
    else
        echo "❌ Push FAILED. Check your GH_PAT permissions."
    fi
}

# --- THE LOOP ---
while [ $CURRENT_LOOP -lt $MAX_LOOPS ]; do
    echo "--- Loop $((CURRENT_LOOP+1)) of $MAX_LOOPS ---"
    echo "Waiting $SLEEP_SECONDS seconds..."
    sleep $SLEEP_SECONDS

    # 1. Zip the data
    echo "🗜️ Zipping data..."
    if tar -czf temp_backup.tar.gz "$DATA_DIR" 2>/dev/null; then
        echo "✅ Zip created."
    else
        echo "❌ Zip failed. Is the data directory empty?"
        continue
    fi

    # 2. Encrypt the zip
    echo "🔒 Encrypting data..."
    # Using pbkdf2 with 10000 iterations for better compatibility/security
    if openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -in temp_backup.tar.gz -out "$BACKUP_DIR/backup_latest.enc" -k "$BACKUP_PASSWORD"; then
        echo "✅ Encryption successful."
        rm temp_backup.tar.gz # Cleanup only on success
    else
        echo "❌ Encryption failed. Check BACKUP_PASSWORD."
        rm temp_backup.tar.gz
        continue
    fi

    # 3. Wipe History & Force Push
    setup_git_and_push "Auto-save: Loop $((CURRENT_LOOP+1))"

    ((CURRENT_LOOP++))
done

# --- RESTART SEQUENCE (5.5 Hours) ---
echo "⏳ Time limit reached. Performing final save..."

# Final Backup
tar -czf temp_backup.tar.gz "$DATA_DIR" 2>/dev/null
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -in temp_backup.tar.gz -out "$BACKUP_DIR/backup_latest.enc" -k "$BACKUP_PASSWORD"
rm temp_backup.tar.gz

# Final Push
setup_git_and_push "Final Save before Restart"

echo "🔄 Triggering new runner..."
gh workflow run "$WORKFLOW_FILE" --ref main

echo "✅ Done. Shutting down."
exit 0