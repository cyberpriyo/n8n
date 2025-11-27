#!/bin/bash

# --- CONFIGURATION ---
DATA_DIR="n8n-data"
SLEEP_SECONDS=600   # 10 Minutes
MAX_LOOPS=34        # ~5.6 hours
REMOTE="gdrive:"    
BACKUP_FOLDER="n8n_backups"
CURRENT_LOOP=0      # <--- THIS WAS MISSING!

# Function to rotate backups
rotate_backups() {
    echo "🔄 Rotating backups on Google Drive (Keeping last 20)..."
    
    # Check remote existence
    if ! rclone listremotes | grep -q "$REMOTE"; then
        echo "❌ Error: Rclone remote '$REMOTE' not found!"
        return 1
    fi

    # 1. Delete the oldest (backup_20)
    rclone delete "$REMOTE$BACKUP_FOLDER/backup_20.tar.gz" 2>/dev/null
    
    # 2. Shift everything up (19->20 ... 1->2)
    for i in {19..1}; do
        NEXT=$((i+1))
        if rclone lsf "$REMOTE$BACKUP_FOLDER/backup_${i}.tar.gz" >/dev/null 2>&1; then
            rclone moveto "$REMOTE$BACKUP_FOLDER/backup_${i}.tar.gz" "$REMOTE$BACKUP_FOLDER/backup_${NEXT}.tar.gz"
        fi
    done
}

setup_git_and_push() {
    git config --global user.email "bot@n8n.com"
    git config --global user.name "URL Bot"
    git add n8n_url.txt
    git commit -m "Update Active URL" || echo "No changes"
    git push -q origin main
}

# The Loop
while [ "$CURRENT_LOOP" -lt "$MAX_LOOPS" ]; do
    echo "--- Loop $((CURRENT_LOOP+1)) of $MAX_LOOPS ---"
    
    # Wait 10 minutes
    sleep $SLEEP_SECONDS

    # 1. Rotate
    rotate_backups

    # 2. Upload New (as backup_1)
    echo "☁️ Uploading backup_1..."
    tar -czf temp.tar.gz "$DATA_DIR"
    rclone copy temp.tar.gz "$REMOTE$BACKUP_FOLDER"
    rclone moveto "$REMOTE$BACKUP_FOLDER/temp.tar.gz" "$REMOTE$BACKUP_FOLDER/backup_1.tar.gz"
    rm temp.tar.gz

    # 3. Keep GitHub Alive
    setup_git_and_push
    ((CURRENT_LOOP++))
done

# --- FINAL SAVE & RESTART ---
echo "⏳ Time limit reached. Restarting..."
rotate_backups
tar -czf temp.tar.gz "$DATA_DIR"
rclone copy temp.tar.gz "$REMOTE$BACKUP_FOLDER"
rclone moveto "$REMOTE$BACKUP_FOLDER/temp.tar.gz" "$REMOTE$BACKUP_FOLDER/backup_1.tar.gz"
rm temp.tar.gz

# Trigger next workflow
gh workflow run n8n.yml --ref main
exit 0
