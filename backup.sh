#!/bin/bash

# Hyprland configuration backup script
# Backs up ~/.config/hypr and related dotfiles to a specified directory or Git repository

# Configuration
BACKUP_DIR="$HOME/hyprland_backups"
TIMESTAMP=$(date +%Y%m%d)
BACKUP_NAME="hyprland_backup_$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
CONFIG_DIR="$HOME/.config/hypr"
GIT_REPO="" # Set to your Git repository URL if using Git, e.g., "git@github.com:username/hyprland-config.git"
BRANCH="main" # Git branch to use

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Check if Hyprland config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: Hyprland configuration directory ($CONFIG_DIR) not found."
    exit 1
fi

# Create backup
echo "Creating backup of $CONFIG_DIR to $BACKUP_PATH..."
cp -r "$CONFIG_DIR" "$BACKUP_PATH"

# Optionally include other related dotfiles (e.g., waybar, wofi)
# Add or remove directories as needed
RELATED_DIRS=(
    "$HOME/.config/waybar"
    "$HOME/.config/wofi"
    "$HOME/.config/mako"
    "$HOME/.config/alacritty"
)
for dir in "${RELATED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "Backing up $dir..."
        cp -r "$dir" "$BACKUP_PATH"
    fi
done

# Compress the backup
echo "Compressing backup..."
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
rm -rf "$BACKUP_PATH"

# Optional Git backup
if [ -n "$GIT_REPO" ]; then
    echo "Pushing backup to Git repository..."
    TEMP_DIR=$(mktemp -d)
    git clone --branch "$BRANCH" "$GIT_REPO" "$TEMP_DIR" || {
        echo "Error: Failed to clone Git repository."
        exit 1
    }
    cp -r "$CONFIG_DIR" "$TEMP_DIR/hypr"
    for dir in "${RELATED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            cp -r "$dir" "$TEMP_DIR"
        fi
    done
    cd "$TEMP_DIR"
    git add .
    git commit -m "Hyprland config backup $TIMESTAMP"
    git push origin "$BRANCH"
    cd -
    rm -rf "$TEMP_DIR"
    echo "Backup pushed to Git repository."
fi

echo "Backup completed: $BACKUP_PATH.tar.gz"
