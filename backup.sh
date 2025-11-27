#!/bin/bash

# --- CONFIGURATION ---
BACKUP_DIR="backups"
DATA_DIR="n8n-data"
SLEEP_SECONDS=1800  # 30 Minutes
MAX_LOOPS=11        # Runs for ~5.5 hours (GitHub limit is 6h)
WORKFLOW_FILE="n8n.yml"

mkdir -p $BACKUP_DIR

# Function to rotate backups (1->2, 2->3, ... 4->5)
rotate_backups() {
    echo "🔄 Rotating backups..."
    # Remove the oldest (5)
    rm -f "$BACKUP_DIR/backup_5.enc"
    
    # Shift others up
    for i in {4..1}; do
        if [ -f "$BACKUP_DIR/backup_${i}.enc" ]; then
            mv "$BACKUP_DIR/backup_${i}.enc" "$BACKUP_DIR/backup_$((i+1)).enc"
        fi
    done
}

setup_git_and_push() {
    MESSAGE=$1
    
    # We NUKE the git history every time to keep the repo tiny.
    # We only care about the current files, not history.
    rm -rf .git
    git init
    git branch -M main
    git config --global user.email "bot@n8n.com"
    git config --global user.name "n8n Bot"
    
    git add .
    git commit -m "$MESSAGE"
    
    # Force push to overwrite the repository state
    git remote add origin "https://oauth2:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}"
    git push -q -f -u origin main
}

while [ $CURRENT_LOOP -lt $MAX_LOOPS ]; do
    echo "--- Loop $((CURRENT_LOOP+1)) of $MAX_LOOPS ---"
    
    # Wait for the next save cycle
    sleep $SLEEP_SECONDS

    # Rotate existing backups before creating a new one
    rotate_backups

    # Create new backup as backup_1.enc (The Latest)
    echo "💾 Creating new backup..."
    tar -czf temp.tar.gz "$DATA_DIR" 2>/dev/null
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -in temp.tar.gz -out "$BACKUP_DIR/backup_1.enc" -k "$BACKUP_PASSWORD"
    rm temp.tar.gz

    setup_git_and_push "Auto-save (Loop $((CURRENT_LOOP+1)))"
    ((CURRENT_LOOP++))
done

# --- FINAL SAVE & RESTART ---
echo "⏳ Time limit reached. Performing final save and restarting..."

rotate_backups

tar -czf temp.tar.gz "$DATA_DIR" 2>/dev/null
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -in temp.tar.gz -out "$BACKUP_DIR/backup_1.enc" -k "$BACKUP_PASSWORD"
rm temp.tar.gz

setup_git_and_push "Final Save & Restart"

# Trigger the workflow again
gh workflow run "$WORKFLOW_FILE" --ref main
exit 0
