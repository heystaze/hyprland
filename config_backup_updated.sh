#!/bin/bash

# === CONFIGURATION ===

BASE_BACKUP_DIR=~/dotfiles
BACKUP_ARCHIVE_DIR="$BASE_BACKUP_DIR/backups"
REPO_DIR="$BASE_BACKUP_DIR/repo"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_BACKUP_DIR="$BASE_BACKUP_DIR/temp_backup_$TIMESTAMP"
ARCHIVE_NAME="backup_$TIMESTAMP.tar.gz"
ARCHIVE_PATH="$BACKUP_ARCHIVE_DIR/$ARCHIVE_NAME"
SNAPSHOT_DIR="$REPO_DIR/snapshots/$TIMESTAMP"

EXCLUDE_DIRS=(
  "cache"
  "Code"
  "discord"
  "Google"
  "Slack"
  "chromium"
  "vivaldi"
  "electron"
)

# Check if --git is passed as an argument
USE_GIT=false
for arg in "$@"; do
  if [[ "$arg" == "--git" ]]; then
    USE_GIT=true
  fi
done

# === FUNCTIONS ===

show_help() {
  echo -e "Hyprland Dotfiles Backup Script\n"
  echo "Usage:"
  echo "  ./hyprland-backup.sh              Backup selected dotfiles"
  echo "  ./hyprland-backup.sh full         Backup full ~/.config (excluding caches)"
  echo "  ./hyprland-backup.sh --git       Backup selected files and push to Git"
  echo "  ./hyprland-backup.sh full --git  Full config backup and push to Git"
  echo "  ./hyprland-backup.sh list         List all backups"
  echo "  ./hyprland-backup.sh extract <file.tar.gz>  Extract a backup"
  echo "  ./hyprland-backup.sh delete <timestamp>      Delete a snapshot"
  echo "  ./hyprland-backup.sh --help       Show this help"
}

backup_selected() {
  mkdir -p "$TEMP_BACKUP_DIR/.config"
  mkdir -p "$BACKUP_ARCHIVE_DIR"
  echo "[*] Backing up selected dotfiles..."

  DOTFILES=(
    hypr
    waybar
    wofi
    kitty
    hyprpanel
    fastfetch
    swaync
    nvim
    rofi
    alacritty
    mako
  )

  for dir in "${DOTFILES[@]}"; do
    if [ -d "$HOME/.config/$dir" ]; then
      echo " - Backing up: $HOME/.config/$dir"
      cp -rL "$HOME/.config/$dir" "$TEMP_BACKUP_DIR/.config/"
    else
      echo " - Skipping missing: $HOME/.config/$dir"
    fi
  done

  for file in .bashrc .zshrc; do
    if [ -f "$HOME/$file" ]; then
      echo " - Backing up: $HOME/$file"
      cp -L "$HOME/$file" "$TEMP_BACKUP_DIR/"
    else
      echo " - Skipping missing: $HOME/$file"
    fi
  done

echo "[*] Backing up package list..."
mkdir -p "$TEMP_BACKUP_DIR/pkglist"
pacman -Qqe > "$TEMP_BACKUP_DIR/pkglist/pacman-packages.txt"
if command -v yay &> /dev/null; then
  yay -Qqe > "$TEMP_BACKUP_DIR/pkglist/yay-packages.txt"
fi

  compress_backup
  if $USE_GIT; then
    git_commit_and_push "selected"
  fi
}

backup_full() {
  mkdir -p "$TEMP_BACKUP_DIR"
  mkdir -p "$BACKUP_ARCHIVE_DIR"
  echo "[*] Backing up full ~/.config (excluding some dirs)..."

  EXCLUDES=()
  for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDES+=(--exclude="$dir")
  done

    EXCLUDES=""
  for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDES+="--exclude=$dir/ "
  done

  rsync -av $EXCLUDES "$HOME/.config/" "$TEMP_BACKUP_DIR/.config/"


  for file in .bashrc .zshrc; do
    if [ -f "$HOME/$file" ]; then
      echo " - Backing up: $HOME/$file"
      cp -L "$HOME/$file" "$TEMP_BACKUP_DIR/"
    else
      echo " - Skipping missing: $HOME/$file"
    fi
  done

	echo "[*] Backing up package list..."
	mkdir -p "$TEMP_BACKUP_DIR/pkglist"
	pacman -Qqe > "$TEMP_BACKUP_DIR/pkglist/pacman-packages.txt"
	if command -v yay &> /dev/null; then
	yay -Qqe > "$TEMP_BACKUP_DIR/pkglist/yay-packages.txt"
	fi

  compress_backup
  if $USE_GIT; then
    git_commit_and_push "full"
  fi
}

compress_backup() {
  echo "[*] Creating archive: $ARCHIVE_PATH"
  tar -czf "$ARCHIVE_PATH" -C "$TEMP_BACKUP_DIR" .

  echo "[*] Copying snapshot to Git repo structure"
  mkdir -p "$SNAPSHOT_DIR"

  shopt -s dotglob
  cp -r "$TEMP_BACKUP_DIR/"* "$SNAPSHOT_DIR"
  shopt -u dotglob

  rm -rf "$TEMP_BACKUP_DIR"
  echo "[✓] Backup complete: $ARCHIVE_PATH"
}

git_commit_and_push() {
  echo "[*] Committing snapshot to Git repo in $REPO_DIR"
  cd "$REPO_DIR" || exit

  if [ ! -d ".git" ]; then
    echo "[*] Initializing Git repository..."
    git init
    git remote add origin git@github.com:heystaze/dotfiles.git
    git branch -M main
  fi

  git add snapshots/

  if git diff --staged --quiet; then
    echo "[=] No changes to commit."
  else
    git commit -m "Snapshot backup: $TIMESTAMP"
    git tag -a "backup_$TIMESTAMP" -m "Snapshot at $TIMESTAMP"
    git push origin main
    git push origin --tags
    echo "[✓] Changes pushed to Git."
  fi
}

list_backups() {
  echo -e "Available backups in $BACKUP_ARCHIVE_DIR:\n"
  find "$BACKUP_ARCHIVE_DIR" -name "backup_*.tar.gz" | while read -r file; do
    size=$(du -sh "$file" | cut -f1)
    mod=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
    echo " - $(basename "$file") | $size | created: $mod"
  done
}

extract_backup() {
  FILE="$1"
  if [[ -z "$FILE" ]]; then
    echo "[!] Error: No filename provided for extraction."
    exit 1
  fi

  if [[ ! -f "$BACKUP_ARCHIVE_DIR/$FILE" ]]; then
    echo "[!] Error: File '$FILE' not found in $BACKUP_ARCHIVE_DIR."
    exit 1
  fi

  DEST="$BASE_BACKUP_DIR/extracted_${FILE%.tar.gz}"
  mkdir -p "$DEST"
  echo "[*] Extracting $FILE to $DEST..."
  tar -xzf "$BACKUP_ARCHIVE_DIR/$FILE" -C "$DEST"
  echo "[✓] Extracted to: $DEST"
}

delete_snapshot() {
  SNAP_TO_DELETE="$2"
  SNAPSHOT_PATH="$REPO_DIR/snapshots/$SNAP_TO_DELETE"

  if [[ -z "$SNAP_TO_DELETE" || ! -d "$SNAPSHOT_PATH" ]]; then
    echo "[!] Error: Snapshot '$SNAP_TO_DELETE' not found."
    exit 1
  fi

  echo "[*] Deleting snapshot: $SNAPSHOT_PATH"
  rm -rf "$SNAPSHOT_PATH"

  cd "$REPO_DIR" || exit
  git rm -r --cached "snapshots/$SNAP_TO_DELETE"
  git commit -m "Removed snapshot: $SNAP_TO_DELETE"
  git push
  echo "[✓] Snapshot deleted from Git and local repo."
}


delete_snapshot() {
  TS="$1"
  if [[ -z "$TS" ]]; then
    echo "[!] Error: No timestamp provided for deletion."
    exit 1
  fi

  SNAP_DIR="$REPO_DIR/snapshots/$TS"
  if [[ ! -d "$SNAP_DIR" ]]; then
    echo "[!] Snapshot $TS not found at $SNAP_DIR"
    exit 1
  fi

  echo "[*] Removing snapshot directory: $SNAP_DIR"
  rm -rf "$SNAP_DIR"

  cd "$REPO_DIR" || exit
  git add snapshots/
  git commit -m "Removed snapshot: $TS"
  git tag -d "backup_$TS" 2>/dev/null
  git push origin main
  git push origin --delete "backup_$TS" 2>/dev/null
  echo "[✓] Snapshot $TS deleted locally and from Git."
}


# === MAIN ENTRY POINT ===

case "$1" in
  delete)
    delete_snapshot "$2"
    ;;
  --help|-h)
    show_help
    ;;
  full)
    backup_full
    ;;
  list)
    list_backups
    ;;
  extract)
    extract_backup "$2"
    ;;
  delete)
    delete_snapshot "$@"
    ;;
  "")
    backup_selected
    ;;
  *)
    echo "[!] Unknown option: $1"
    show_help
    ;;
esac
