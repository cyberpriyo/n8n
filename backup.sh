#!/bin/bash

# --- CONFIGURATION ---
BACKUP_DIR="backups"
DATA_DIR="n8n-data"
MAX_BACKUPS=5
SLEEP_SECONDS=1800  # 30 Minutes
# 5.5 Hours = 330 Minutes. 330 / 30 = 11 Loops.
MAX_LOOPS=11 
CURRENT_LOOP=0
WORKFLOW_FILE="n8n.yml" 

mkdir -p $BACKUP_DIR

# --- GIT SETUP ---
git config --global user.email "bot@n8n.com"
git config --global user.name "n8n Bot"

# --- THE BACKUP LOOP ---
while [ $CURRENT_LOOP -lt $MAX_LOOPS ]; do
    echo "--- Loop $((CURRENT_LOOP+1)) of $MAX_LOOPS ---"
    echo "Waiting $SLEEP_SECONDS seconds..."
    sleep $SLEEP_SECONDS

    # 1. Create Backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
    echo "Creating backup: $BACKUP_FILE"
    
    tar -czf "$BACKUP_FILE" "$DATA_DIR" 2>/dev/null

    # 2. Rotate (Keep Max 5)
    ls -tp "$BACKUP_DIR" | grep -v '/$' | tail -n +$((MAX_BACKUPS + 1)) | xargs -I {} rm -- "$BACKUP_DIR/{}"

    # 3. Commit & Push
    git pull --rebase --autostash || echo "Git pull failed, continuing..."
    git add "$BACKUP_DIR"
    git commit -m "Auto-backup: $TIMESTAMP"
    git push || echo "Git push failed, will try next time"

    ((CURRENT_LOOP++))
done

# --- THE RESTART SEQUENCE (At 5.5 Hours) ---
echo "⏳ 5.5 Hours reached. Initiating restart sequence..."

# Final Safety Backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S_FINAL)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
tar -czf "$BACKUP_FILE" "$DATA_DIR" 2>/dev/null
git add "$BACKUP_DIR"
git commit -m "Final Backup before Restart: $TIMESTAMP"
git push

echo "🚀 Triggering next workflow run..."
# Triggers the workflow to start FRESH immediately
gh workflow run "$WORKFLOW_FILE" --ref main

echo "✅ Restart signal sent."
exit 0
