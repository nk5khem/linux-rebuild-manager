#!/bin/bash

# ============================================================
# linux-rebuild-manager
# ============================================================

# -----------------------------
# Load version
# -----------------------------
VERSION="dev"
if [[ -f "/usr/share/linux-rebuild-manager/VERSION" ]]; then
    VERSION="$(cat /usr/share/linux-rebuild-manager/VERSION)"
elif [[ -f "$(dirname "$0")/../VERSION" ]]; then
    VERSION="$(cat "$(dirname "$0")/../VERSION")"
fi

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "linux-rebuild-manager version $VERSION"
    exit 0
fi

# -----------------------------
# Detect Linux distribution
# -----------------------------
DISTRO="unknown"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="$ID"
fi

# -----------------------------
# Detect package manager support
# -----------------------------
HAS_APT=false
HAS_SNAP=false
HAS_FLATPAK=false

command -v apt >/dev/null 2>&1 && HAS_APT=true
command -v snap >/dev/null 2>&1 && HAS_SNAP=true
command -v flatpak >/dev/null 2>&1 && HAS_FLATPAK=true

# -----------------------------
# Display system summary
# -----------------------------
echo "Detected system:"
echo "  Distribution : $DISTRO"
echo "  APT support  : $HAS_APT"
echo "  Snap support : $HAS_SNAP"
echo "  Flatpak      : $HAS_FLATPAK"
echo

# -----------------------------
# Paths & directories
# -----------------------------
BASE_DIR="$HOME/system-rebuild"
SNAPSHOT_DIR="$HOME/rebuild-snapshots"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

mkdir -p "$BASE_DIR" "$SNAPSHOT_DIR"

# -----------------------------
# Helpers
# -----------------------------
pause() {
    echo
    read -rp "Press Enter to continue..."
}

# -----------------------------
# GUI Progress helper
# -----------------------------
progress_gui() {
    PERCENT="$1"
    MESSAGE="$2"

    if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
        echo "$PERCENT"
        echo "# $MESSAGE"
    fi
}

# -----------------------------
# Core functionality
# -----------------------------
create_snapshot() {
        progress_gui 5 "Preparing snapshot environment"
        echo "Creating rebuild snapshot..."

    rm -rf "$BASE_DIR"
    mkdir -p "$BASE_DIR"

    if $HAS_APT; then
        progress_gui 20 "Saving APT package list"
        echo "Saving APT manual packages..."
        apt-mark showmanual > "$BASE_DIR/apt-manual.txt"
    else
        echo "Skipping APT packages (APT not available)."
    fi

    if $HAS_SNAP; then
        progress_gui 35 "Saving Snap package list"
        echo "Saving Snap list..."
        snap list > "$BASE_DIR/snap-list.txt"
    else
        echo "Skipping Snap packages (Snap not available)."
    fi

    if $HAS_FLATPAK; then
        progress_gui 50 "Saving Flatpak applications"
        echo "Saving Flatpak apps..."
        flatpak list --app --columns=application > "$BASE_DIR/flatpak-apps.txt"
    else
        echo "Skipping Flatpak apps (Flatpak not available)."
    fi

    if $HAS_APT; then
        echo "Saving APT sources and keys..."
        mkdir -p "$BASE_DIR/apt-sources"
        cp -r /etc/apt/sources.list* "$BASE_DIR/apt-sources/" 2>/dev/null
        cp -r /etc/apt/sources.list.d "$BASE_DIR/apt-sources/" 2>/dev/null
        cp -r /etc/apt/trusted.gpg.d "$BASE_DIR/apt-sources/" 2>/dev/null
    fi

    echo "Saving user configs..."
    progress_gui 65 "Saving user configuration files"
    cp -r "$HOME/.config" "$BASE_DIR/config" 2>/dev/null
    cp -r "$HOME/.local/share" "$BASE_DIR/local-share" 2>/dev/null

    progress_gui 85 "Creating compressed archive"
    ARCHIVE="$SNAPSHOT_DIR/linux-rebuild-$DATE.tar.gz"
    tar -czf "$ARCHIVE" -C "$HOME" system-rebuild

    echo
    echo "Snapshot created:"
    progress_gui 100 "Snapshot completed"
    echo "$ARCHIVE"
    pause
}

list_apps() {
    if $HAS_APT; then
        echo "==== APT Manual Apps ===="
        apt-mark showmanual
        echo
    fi

    if $HAS_SNAP; then
        echo "==== Snap Apps ===="
        snap list
        echo
    fi

    if $HAS_FLATPAK; then
        echo "==== Flatpak Apps ===="
        flatpak list --app
        echo
    fi

    pause
}

show_changes() {
    LAST_TWO=$(ls -t "$SNAPSHOT_DIR"/linux-rebuild-*.tar.gz 2>/dev/null | head -n 2)

    if [[ "$(echo "$LAST_TWO" | wc -l)" -lt 2 ]]; then
        echo "Not enough snapshots to compare."
        pause
        return
    fi

    TMP1=$(mktemp -d)
    TMP2=$(mktemp -d)

    tar -xzf "$(echo "$LAST_TWO" | sed -n 2p)" -C "$TMP1"
    tar -xzf "$(echo "$LAST_TWO" | sed -n 1p)" -C "$TMP2"

    if [[ -f "$TMP1/system-rebuild/apt-manual.txt" ]]; then
        echo "==== APT Changes ===="
        diff "$TMP1/system-rebuild/apt-manual.txt" "$TMP2/system-rebuild/apt-manual.txt" || true
        echo
    fi

    if [[ -f "$TMP1/system-rebuild/flatpak-apps.txt" ]]; then
        echo "==== Flatpak Changes ===="
        diff "$TMP1/system-rebuild/flatpak-apps.txt" "$TMP2/system-rebuild/flatpak-apps.txt" || true
        echo
    fi

    rm -rf "$TMP1" "$TMP2"
    pause
}

cleanup_snapshots() {
    echo "Available snapshots:"
    ls -lh "$SNAPSHOT_DIR"
    echo
    read -rp "Keep how many latest snapshots? " KEEP

    ls -t "$SNAPSHOT_DIR"/linux-rebuild-*.tar.gz | tail -n +$((KEEP+1)) | xargs -r rm -v
    pause
}

verify_snapshots() {
    echo "Verifying snapshots..."
    for f in "$SNAPSHOT_DIR"/*.tar.gz; do
        echo "Checking $f"
        tar -tzf "$f" >/dev/null && echo "OK" || echo "CORRUPTED"
    done
    pause
}

# -----------------------------
# Main menu
# -----------------------------
select_snapshot() {
  SNAP_DIR="$HOME/rebuild-snapshots"

  if [ ! -d "$SNAP_DIR" ]; then
    echo "No rebuild archive directory found."
    pause
    return 1
  fi

  if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
    zenity --file-selection \
      --title="Select rebuild archive" \
      --filename="$SNAP_DIR/" \
      --file-filter="Rebuild archives (*.tar.gz) | *.tar.gz"
  else
    echo "Available rebuild archives:"
    ls -1 "$SNAP_DIR"/*.tar.gz 2>/dev/null | nl
    echo
    read -rp "Enter archive number: " N
    ls -1 "$SNAP_DIR"/*.tar.gz | sed -n "${N}p"
  fi
}

preview_restore() {
  SNAP="$1"
  TMP=$(mktemp -d)

  tar -xzf "$SNAP" -C "$TMP"

  echo "===== APT changes ====="
  if command -v apt >/dev/null; then
    apt-mark showmanual | sort > "$TMP/current-apt.txt"
    sort "$TMP/system-rebuild/apt-manual.txt" > "$TMP/snap-apt.txt"
    diff "$TMP/current-apt.txt" "$TMP/snap-apt.txt" || true
  fi

  echo
  echo "===== Flatpak changes ====="
  if command -v flatpak >/dev/null; then
    flatpak list --app --columns=application | sort > "$TMP/current-flat.txt"
    awk '{print $1}' "$TMP/system-rebuild/flatpak-apps.txt" | sort > "$TMP/snap-flat.txt"
    diff "$TMP/current-flat.txt" "$TMP/snap-flat.txt" || true
  fi

  rm -rf "$TMP"
}

restore_safe_mode() {
  SNAP=$(select_snapshot) || return

  clear
  echo "Previewing restore from:"
  echo "$SNAP"
  echo
  preview_restore "$SNAP"
  progress_gui 10 "Restore preview completed"

  CONFIRM_RESTORE=false

  if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
    zenity --question \
      --title="Restore applications" \
      --text="Preview complete.\n\nDo you want to restore missing applications from this snapshot?"
    [ $? -eq 0 ] && CONFIRM_RESTORE=true
  else
    read -rp "Restore missing applications (APT + Flatpak)? [y/N]: " CONFIRM
    [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] && CONFIRM_RESTORE=true
  fi

  $CONFIRM_RESTORE || return
  progress_gui 30 "Restoring APT packages"
  install_missing_apt "$SNAP"
  progress_gui 55 "Restoring Flatpak applications"
  install_missing_flatpak "$SNAP"
  progress_gui 75 "Restoring Snap packages"
  install_missing_snap "$SNAP"

  progress_gui 90 "Application restore completed"
  if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
    zenity --question \
      --title="Restore configs?" \
      --text="Do you want to restore selected application configurations?\n\n(Advanced users only)"
    [ $? -eq 0 ] && restore_configs "$SNAP"
  else
    read -rp "Restore selected configs? [y/N]: " CFG
    [[ "$CFG" == "y" || "$CFG" == "Y" ]] && restore_configs "$SNAP"
  fi
  progress_gui 100 "Restore process completed"
}



install_missing_apt() {
  SNAP="$1"
  TMP=$(mktemp -d)

  tar -xzf "$SNAP" -C "$TMP"

  if ! command -v apt >/dev/null; then
    echo "APT not available on this system."
    rm -rf "$TMP"
    pause
    return
  fi

  echo "Calculating missing APT packages..."

  apt-mark showmanual | sort > "$TMP/current-apt.txt"
  sort "$TMP/system-rebuild/apt-manual.txt" > "$TMP/snap-apt.txt"

  MISSING=$(comm -13 "$TMP/current-apt.txt" "$TMP/snap-apt.txt")

  if [ -z "$MISSING" ]; then
    echo "No missing APT packages to install."
    rm -rf "$TMP"
    pause
    return
  fi

  echo "The following packages will be installed:"
  echo "$MISSING"
  echo

  if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
    zenity --question \
      --title="Confirm APT Restore" \
      --text="Install missing APT packages from snapshot?\n\n$(echo "$MISSING" | tr '\n' ' ')"
    [ $? -ne 0 ] && rm -rf "$TMP" && return
  else
    read -rp "Proceed with installation? [y/N]: " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && rm -rf "$TMP" && return
  fi

  echo "Installing missing APT packages..."
  sudo apt update
  sudo apt install -y $MISSING

  rm -rf "$TMP"
  echo "APT restore completed."
  pause
}

install_missing_flatpak() {
  SNAP="$1"

  if ! command -v flatpak >/dev/null; then
    echo "Flatpak not available on this system."
    pause
    return
  fi

  TMP=$(mktemp -d)
  tar -xzf "$SNAP" -C "$TMP"

  SNAP_LIST="$TMP/system-rebuild/flatpak-apps.txt"

  if [ ! -f "$SNAP_LIST" ]; then
    echo "No Flatpak data found in snapshot."
    rm -rf "$TMP"
    pause
    return
  fi

  echo "Calculating missing Flatpak applications..."

  CURRENT=$(flatpak list --app --columns=application)
  FOUND=false

  while read -r APP; do
    if ! echo "$CURRENT" | grep -qx "$APP"; then
      FOUND=true
      echo "Installing Flatpak: $APP"
      flatpak install -y flathub "$APP"
    fi
  done < "$SNAP_LIST"

  $FOUND || echo "No missing Flatpak apps to install."

  rm -rf "$TMP"
  pause
}


install_missing_snap() {
  SNAP="$1"
  TMP=$(mktemp -d)

  tar -xzf "$SNAP" -C "$TMP"

  if ! command -v snap >/dev/null; then
    echo "Snap not available on this system."
    rm -rf "$TMP"
    pause
    return
  fi

  SNAP_FILE="$TMP/system-rebuild/snap-list.txt"

  if [ ! -f "$SNAP_FILE" ]; then
    echo "No Snap data in snapshot."
    rm -rf "$TMP"
    pause
    return
  fi

  echo "Calculating missing Snap applications..."

  snap list | awk 'NR>1 {print $1}' | sort > "$TMP/current-snap.txt"
  awk 'NR>1 {print $1}' "$SNAP_FILE" | sort > "$TMP/snap-snap.txt"

  MISSING=$(comm -13 "$TMP/current-snap.txt" "$TMP/snap-snap.txt")

  if [ -z "$MISSING" ]; then
    echo "No missing Snap apps to install."
    rm -rf "$TMP"
    pause
    return
  fi

  echo "The following Snap apps will be installed:"
  echo "$MISSING"
  echo

  if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
    zenity --question \
      --title="Confirm Snap Restore" \
      --text="Install missing Snap applications?\n\n$(echo "$MISSING" | tr '\n' ' ')"
    [ $? -ne 0 ] && rm -rf "$TMP" && return
  else
    read -rp "Install missing Snap apps? [y/N]: " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && rm -rf "$TMP" && return
  fi

  for APP in $MISSING; do
    echo "Installing Snap: $APP"
    sudo snap install "$APP"
  done

  rm -rf "$TMP"
  echo "Snap restore completed."
  pause
}


restore_configs() {
  SNAP="$1"
  TMP=$(mktemp -d)

  tar -xzf "$SNAP" -C "$TMP"

  CFG_SRC="$TMP/system-rebuild/config"
  SHARE_SRC="$TMP/system-rebuild/local-share"

  [ ! -d "$CFG_SRC" ] && echo "No config data in snapshot." && rm -rf "$TMP" && pause && return

  # Build list of available config folders
  AVAILABLE=$(ls -1 "$CFG_SRC")

  if [ -z "$AVAILABLE" ]; then
    echo "No config folders found in snapshot."
    rm -rf "$TMP"
    pause
    return
  fi

  SELECTED=""

  if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
    SELECTED=$(zenity --list \
      --title="Select configs to restore" \
      --text="Choose application configs to restore" \
      --checklist \
      --column="Restore" --column="Config Folder" \
      $(for f in $AVAILABLE; do echo FALSE "$f"; done) \
      --separator=" ")
  else
    echo "Available config folders:"
    echo "$AVAILABLE"
    read -rp "Enter folder names to restore (space separated): " SELECTED
  fi

  [ -z "$SELECTED" ] && rm -rf "$TMP" && return

  BACKUP="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUP"

  echo "Backing up existing configs to:"
  echo "$BACKUP"

  for cfg in $SELECTED; do
    [ -d "$HOME/.config/$cfg" ] && cp -a "$HOME/.config/$cfg" "$BACKUP/"
    cp -a "$CFG_SRC/$cfg" "$HOME/.config/"
  done

  echo "Selected configs restored."
  rm -rf "$TMP"
  pause
}


#----------------------------
#---------------------------
while true; do
    clear
    echo "=================================="
    echo " Linux Rebuild Manager  v$VERSION"
    echo "=================================="
    echo "1) Create new rebuild archive"
    echo "2) View changes since last archive"
    echo "3) List installed apps"
    echo "4) Clean old archives"
    echo "5) Verify archives"
    echo "6) Restore snapshot (safe mode)"
    echo "7) Exit"
    echo
    read -rp "Choose an option [1-7]: " CHOICE

    case $CHOICE in
        1) create_snapshot ;;
        2) show_changes ;;
        3) list_apps ;;
        4) cleanup_snapshots ;;
        5) verify_snapshots ;;
        6) restore_safe_mode ;;
        7) exit 0 ;;
        *) echo "Invalid option"; pause ;;
    esac
done
