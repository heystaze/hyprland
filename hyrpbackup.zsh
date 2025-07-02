#!/bin/zsh

# Backup script for Hyprland configurations using Zsh
# Features: Selective backup, compression, remote upload, logging

# Configuration
BACKUP_DIR="$HOME/hyprland_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="hyprland_backup_$TIMESTAMP"
LOG_FILE="$BACKUP_DIR/backup_log.txt"
CONFIG_DIR="$HOME/.config/hypr"
COMPRESSION_METHOD="tar.gz" # Options: tar.gz, zip, none

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Check if Hyprland config directory exists
if [[ ! -d "$CONFIG_DIR" ]]; then
    log_message "Error: Hyprland config directory ($CONFIG_DIR) not found!"
    exit 1
fi

# Prompt user for backup options
echo "Hyprland Configuration Backup Script"
echo "1. Full backup (all files in ~/.config/hypr)"
echo "2. Selective backup (choose specific files)"
echo "3. Full backup with compression ($COMPRESSION_METHOD)"
echo "4. Selective backup with compression ($COMPRESSION_METHOD)"
echo "5. Backup and push to remote Git repository"
echo -n "Choose an option (1-5): "
read choice

# Function to perform full backup
full_backup() {
    log_message "Starting full backup..."
    cp -r "$CONFIG_DIR" "$BACKUP_DIR/$BACKUP_FILE"
    if [[ $? -eq 0 ]]; then
        log_message "Full backup completed: $BACKUP_DIR/$BACKUP_FILE"
    else
        log_message "Error: Full backup failed!"
        exit 1
    fi
}

# Function to perform selective backup
selective_backup() {
    log_message "Starting selective backup..."
    echo "Available files in $CONFIG_DIR:"
    ls -1 "$CONFIG_DIR"
    echo -n "Enter files to back up (space-separated, e.g., hyprland.conf keybindings.conf): "
    read -A files
    mkdir -p "$BACKUP_DIR/$BACKUP_FILE"
    for file in "${files[@]}"; do
        if [[ -f "$CONFIG_DIR/$file" ]]; then
            cp "$CONFIG_DIR/$file" "$BACKUP_DIR/$BACKUP_FILE/$file"
            log_message "Backed up $file"
        else
            log_message "Warning: $file not found, skipping..."
        fi
    done
    log_message "Selective backup completed: $BACKUP_DIR/$BACKUP_FILE"
}

# Function to compress backup
compress_backup() {
    local source="$BACKUP_DIR/$BACKUP_FILE"
    log_message "Compressing backup..."
    case "$COMPRESSION_METHOD" in
        "tar.gz")
            tar -czf "$source.tar.gz" -C "$BACKUP_DIR" "$BACKUP_FILE"
            if [[ $? -eq 0 ]]; then
                log_message "Compression completed: $source.tar.gz"
                rm -rf "$source"
            else
                log_message "Error: Compression failed!"
                exit 1
            fi
            ;;
        "zip")
            zip -r "$source.zip" "$source" -j
            if [[ $? -eq 0 ]]; then
                log_message "Compression completed: $source.zip"
                rm -rf "$source"
            else
                log_message "Error: Compression failed!"
                exit 1
            fi
            ;;
        *)
            log_message "No compression applied."
            ;;
    esac
}

# Function to push to remote Git repository
push_to_git() {
    local repo_url
    echo -n "Enter remote Git repository URL (or leave blank to skip): "
    read repo_url
    if [[ -n "$repo_url" ]]; then
        log_message "Pushing to remote Git repository..."
        git -C "$BACKUP_DIR" init
        git -C "$BACKUP_DIR" add .
        git -C "$BACKUP_DIR" commit -m "Hyprland backup $TIMESTAMP"
        git -C "$BACKUP_DIR" remote add origin "$repo_url" || git -C "$BACKUP_DIR" remote set-url origin "$repo_url"
        git -C "$BACKUP_DIR" push -u origin master
        if [[ $? -eq 0 ]]; then
            log_message "Successfully pushed to $repo_url"
        else
            log_message "Error: Failed to push to Git repository!"
            exit 1
        fi
    else
        log_message "Skipping Git push (no repository URL provided)."
    fi
}

# Main logic
case "$choice" in
    1)
        full_backup
        ;;
    2)
        selective_backup
        ;;
    3)
        full_backup
        compress_backup
        ;;
    4)
        selective_backup
        compress_backup
        ;;
    5)
        full_backup
        compress_backup
        push_to_git
        ;;
    *)
        log_message "Error: Invalid option selected!"
        exit 1
        ;;
esac

log_message "Backup process completed successfully!"
