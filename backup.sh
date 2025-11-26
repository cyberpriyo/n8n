#!/bin/bash

# Configuration
BACKUP_DIR="backups"
MAX_BACKUPS=5
SLEEP_SECONDS=1800 # 30 Minutes

mkdir -p $BACKUP_DIR

# Configure Git
git config --global user.email "actions@github.com"
git config --global user.name "GitHub Actions Backup"

while true; do
    # 1. Wait for the interval
    echo "Waiting $SLEEP_SECONDS seconds before next backup..."
    sleep $SLEEP_SECONDS

    # 2. Create Backup (Compress the .n8n folder)
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
    
    echo "Creating backup: $BACKUP_FILE"
    # We backup the mapped volume folder 'n8n-data'
    tar -czf "$BACKUP_FILE" n8n-data 2>/dev/null

    # 3. Rotate Backups (Keep only latest 5)
    # List files by time, skip top 5, delete the rest
    ls -tp "$BACKUP_DIR" | grep -v '/$' | tail -n +$((MAX_BACKUPS + 1)) | xargs -I {} rm -- "$BACKUP_DIR/{}"

    # 4. Push to Git
    git pull --rebase # Pull changes just in case to avoid conflicts
    git add "$BACKUP_DIR"
    git commit -m "Auto-backup: $TIMESTAMP"
    git push

    echo "Backup completed and pushed."
done
