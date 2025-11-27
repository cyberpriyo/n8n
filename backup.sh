#!/bin/bash

# --- CONFIGURATION ---
BACKUP_DIR="backups"
DATA_DIR="n8n-data"
SLEEP_SECONDS=1800
MAX_LOOPS=11
CURRENT_LOOP=0
WORKFLOW_FILE="n8n.yml"

mkdir -p $BACKUP_DIR

setup_git_and_push() {
    MESSAGE=$1
    rm -rf .git
    git init
    git branch -M main # <--- FIX: Forces branch to be 'main'
    git config --global user.email "bot@n8n.com"
    git config --global user.name "n8n Bot"
    git add .
    git commit -m "$MESSAGE"
    git remote add origin "https://oauth2:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}"
    git push -q -f -u origin main
}

while [ $CURRENT_LOOP -lt $MAX_LOOPS ]; do
    echo "--- Loop $((CURRENT_LOOP+1)) of $MAX_LOOPS ---"
    echo "Waiting $SLEEP_SECONDS seconds..."
    sleep $SLEEP_SECONDS

    tar -czf temp.tar.gz "$DATA_DIR" 2>/dev/null
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -in temp.tar.gz -out "$BACKUP_DIR/backup_latest.enc" -k "$BACKUP_PASSWORD"
    rm temp.tar.gz

    setup_git_and_push "Auto-save"
    ((CURRENT_LOOP++))
done

echo "⏳ Restarting..."
tar -czf temp.tar.gz "$DATA_DIR" 2>/dev/null
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -in temp.tar.gz -out "$BACKUP_DIR/backup_latest.enc" -k "$BACKUP_PASSWORD"
rm temp.tar.gz

setup_git_and_push "Final Save"
gh workflow run "$WORKFLOW_FILE" --ref main
exit 0