#!/bin/bash

# ============================================================
# linux-rebuild-manager (CLI Reference Version)
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
# Detect system
# -----------------------------
DISTRO="unknown"
[[ -f /etc/os-release ]] && . /etc/os-release && DISTRO="$ID"

HAS_APT=false
HAS_SNAP=false
HAS_FLATPAK=false

command -v apt >/dev/null 2>&1 && HAS_APT=true
command -v snap >/dev/null 2>&1 && HAS_SNAP=true
command -v flatpak >/dev/null 2>&1 && HAS_FLATPAK=true

echo "Detected system:"
echo "  Distribution : $DISTRO"
echo "  APT support  : $HAS_APT"
echo "  Snap support : $HAS_SNAP"
echo "  Flatpak      : $HAS_FLATPAK"
echo

# -----------------------------
# Paths
# -----------------------------
BASE_DIR="$HOME/system-rebuild"
SNAPSHOT_DIR="$HOME/rebuild-snapshots"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

mkdir -p "$BASE_DIR" "$SNAPSHOT_DIR"

pause() {
    echo
    read -rp "Press Enter to continue..."
}

# ============================================================
# SNAPSHOT CREATION
# ============================================================
create_snapshot() {
    echo "[1/4] Preparing snapshot directory..."
    rm -rf "$BASE_DIR"
    mkdir -p "$BASE_DIR"

    if $HAS_APT; then
        echo "[2/4] Saving APT packages..."
        apt-mark showmanual > "$BASE_DIR/apt-manual.txt"
    fi

    if $HAS_SNAP; then
        echo "[3/4] Saving Snap packages..."
        snap list > "$BASE_DIR/snap-list.txt"
    fi

    if $HAS_FLATPAK; then
        echo "[4/4] Saving Flatpak applications..."
        flatpak list --app --columns=application > "$BASE_DIR/flatpak-apps.txt"
    fi

    cp -r "$HOME/.config" "$BASE_DIR/config" 2>/dev/null
    cp -r "$HOME/.local/share" "$BASE_DIR/local-share" 2>/dev/null

    ARCHIVE="$SNAPSHOT_DIR/linux-rebuild-$DATE.tar.gz"
    tar -czf "$ARCHIVE" -C "$HOME" system-rebuild

    echo
    echo "Snapshot created:"
    echo "$ARCHIVE"
    pause
}

# ============================================================
# LIST & COMPARE
# ============================================================
list_apps() {
    $HAS_APT && echo "==== APT ====" && apt-mark showmanual && echo
    $HAS_SNAP && echo "==== Snap ====" && snap list && echo
    $HAS_FLATPAK && echo "==== Flatpak ====" && flatpak list --app && echo
    pause
}

show_changes() {
    LAST_TWO=$(ls -t "$SNAPSHOT_DIR"/linux-rebuild-*.tar.gz 2>/dev/null | head -n 2)
    [[ $(echo "$LAST_TWO" | wc -l) -lt 2 ]] && echo "Not enough snapshots." && pause && return

    TMP1=$(mktemp -d)
    TMP2=$(mktemp -d)

    tar -xzf "$(echo "$LAST_TWO" | sed -n 2p)" -C "$TMP1"
    tar -xzf "$(echo "$LAST_TWO" | sed -n 1p)" -C "$TMP2"

    [[ -f "$TMP1/system-rebuild/apt-manual.txt" ]] && \
        echo "==== APT Changes ====" && \
        diff "$TMP1/system-rebuild/apt-manual.txt" "$TMP2/system-rebuild/apt-manual.txt" || true
   if [[ -f "$TMP1/system-rebuild/flatpak-apps.txt" ]]; then
    echo "==== Flatpak Changes ===="

    awk '{print $1}' "$TMP1/system-rebuild/flatpak-apps.txt" | sort > "$TMP1/flat1.txt"
    awk '{print $1}' "$TMP2/system-rebuild/flatpak-apps.txt" | sort > "$TMP2/flat2.txt"

    diff "$TMP1/flat1.txt" "$TMP2/flat2.txt" || true
    echo
   fi

    rm -rf "$TMP1" "$TMP2"
    pause
}

cleanup_snapshots() {
    ls -lh "$SNAPSHOT_DIR"
    read -rp "Keep how many latest snapshots? " KEEP
    ls -t "$SNAPSHOT_DIR"/linux-rebuild-*.tar.gz | tail -n +$((KEEP+1)) | xargs -r rm -v
    pause
}

verify_snapshots() {
    for f in "$SNAPSHOT_DIR"/*.tar.gz; do
        echo "Checking $f"
        tar -tzf "$f" >/dev/null && echo "OK" || echo "CORRUPTED"
    done
    pause
}

# ============================================================
# SNAPSHOT SELECTION (ONLY GUI USE)
# ============================================================
select_snapshot() {
    if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
        zenity --file-selection \
          --title="Select rebuild snapshot" \
          --filename="$SNAPSHOT_DIR/" \
          --file-filter="Rebuild archives (*.tar.gz) | *.tar.gz"
    else
        ls -1 "$SNAPSHOT_DIR"/*.tar.gz | nl
        read -rp "Enter snapshot number: " N
        ls -1 "$SNAPSHOT_DIR"/*.tar.gz | sed -n "${N}p"
    fi
}

# ============================================================
# RESTORE FUNCTIONS
# ============================================================



install_missing_apt() {
    $HAS_APT || return
    SNAP="$1"
    TMP=$(mktemp -d)
    tar -xzf "$SNAP" -C "$TMP"

    [[ ! -f "$TMP/system-rebuild/apt-manual.txt" ]] && rm -rf "$TMP" && return

    echo "[1/3] Restoring APT packages..."
    apt-mark showmanual | sort > "$TMP/current.txt"
    sort "$TMP/system-rebuild/apt-manual.txt" > "$TMP/snap.txt"
    MISSING=$(comm -13 "$TMP/current.txt" "$TMP/snap.txt")

    [[ -z "$MISSING" ]] && echo "No missing APT packages." && rm -rf "$TMP" && return

    echo "$MISSING"
    read -rp "Proceed with APT install? [y/N]: " C
    [[ "$C" != "y" && "$C" != "Y" ]] && rm -rf "$TMP" && return

    sudo apt update && sudo apt install -y $MISSING
    rm -rf "$TMP"
}

install_missing_flatpak() {

    SNAP="$1"

    # -----------------------------
    # Ensure Flatpak is installed
    # -----------------------------
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "[INFO] Flatpak not found. Installing Flatpak (required for restore)."

        if ! command -v apt >/dev/null 2>&1; then
            echo "[ERROR] Automatic Flatpak installation is supported only on Debian/Ubuntu."
            return 1
        fi

        if [ "$EUID" -ne 0 ]; then
            echo "[ERROR] Flatpak installation requires root privileges."
            echo "        Please run the recovery with sudo."
            return 1
        fi

        apt update
        apt install -y flatpak
    else
        echo "[INFO] Flatpak is already installed."
    fi

    # -----------------------------
    # Ensure Flathub remote exists
    # -----------------------------
    if ! flatpak remote-list | awk '{print $1}' | grep -qx flathub; then
        echo "[INFO] Adding Flathub remote..."
        flatpak remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo
    else
        echo "[INFO] Flathub remote already configured."
    fi

    # -----------------------------
    # Extract snapshot
    # -----------------------------
    TMP=$(mktemp -d)
    tar -xzf "$SNAP" -C "$TMP"

    # -----------------------------
    # Locate Flatpak app list (robust)
    # -----------------------------
    LIST="$(find "$TMP" -type f -name 'flatpak-apps.txt' 2>/dev/null | head -n 1)"

    if [[ -z "$LIST" ]]; then
        echo "[INFO] No Flatpak app list found in snapshot. Skipping Flatpak restore."
        rm -rf "$TMP"
        return 0
    fi

    # -----------------------------
    # Restore Flatpak applications
    # -----------------------------
    echo "[2/3] Restoring Flatpak applications..."

    CURRENT="$(flatpak list --app --columns=application)"
    FOUND=false

    while read -r APP; do
        [[ -z "$APP" ]] && continue
        if ! echo "$CURRENT" | grep -qx "$APP"; then
            FOUND=true
            echo "Installing Flatpak: $APP"
            flatpak install -y flathub "$APP"
        fi
    done < "$LIST"

    $FOUND || echo "No missing Flatpak apps."

    rm -rf "$TMP"
}



install_missing_snap() {
    $HAS_SNAP || return
    SNAP="$1"
    TMP=$(mktemp -d)
    tar -xzf "$SNAP" -C "$TMP"

    LIST="$TMP/system-rebuild/snap-list.txt"
    [[ ! -f "$LIST" ]] && rm -rf "$TMP" && return

    echo "[3/3] Restoring Snap packages..."

    CURRENT=$(snap list | awk 'NR>1 {print $1}')
    FOUND=false

    awk 'NR>1 {print $1}' "$LIST" | while read -r APP; do
        if ! echo "$CURRENT" | grep -qx "$APP"; then
            FOUND=true
            echo "Installing Snap: $APP"
            sudo snap install "$APP"
        fi
    done

    $FOUND || echo "No missing Snap packages."

    rm -rf "$TMP"
}

restore_configs() {
    SNAP="$1"
    TMP=$(mktemp -d)

    tar -xzf "$SNAP" -C "$TMP"

    CFG_SRC="$TMP/system-rebuild/config"

    if [ ! -d "$CFG_SRC" ]; then
        echo "No user config data found in snapshot."
        rm -rf "$TMP"
        return
    fi

    AVAILABLE=$(ls -1 "$CFG_SRC")
    [ -z "$AVAILABLE" ] && echo "No config folders found." && rm -rf "$TMP" && return

    SELECTED=""

    # GUI only for config selection
    if command -v zenity >/dev/null && [ -n "$DISPLAY" ]; then
        SELECTED=$(zenity --list \
            --title="Select application configs to restore" \
            --text="Choose which application settings to restore" \
            --checklist \
            --column="Restore" --column="Config Folder" \
            $(for f in $AVAILABLE; do echo FALSE "$f"; done) \
            --separator=" ")
    else
        echo "Available config folders:"
        echo "$AVAILABLE"
        read -rp "Enter config folders to restore (space-separated): " SELECTED
    fi

    [ -z "$SELECTED" ] && echo "No configs selected." && rm -rf "$TMP" && return

    BACKUP="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP"

    echo "Backing up existing configs to:"
    echo "$BACKUP"

    for cfg in $SELECTED; do
        [ -d "$HOME/.config/$cfg" ] && cp -a "$HOME/.config/$cfg" "$BACKUP/"
        cp -a "$CFG_SRC/$cfg" "$HOME/.config/"
        echo "Restored config: $cfg"
    done

    rm -rf "$TMP"
    echo "Selected application configs restored."
}

restore_safe_mode() {
    SNAP=$(select_snapshot) || return

    clear
    echo "Restoring from:"
    echo "$SNAP"
    echo

    read -rp "Restore missing applications (APT + Flatpak + Snap)? [y/N]: " C
    [[ "$C" != "y" && "$C" != "Y" ]] && return

    install_missing_apt "$SNAP"
    install_missing_flatpak "$SNAP"
    install_missing_snap "$SNAP"

    echo
    read -rp "Restore user application configurations (~/.config)? [y/N]: " CFG
    [[ "$CFG" == "y" || "$CFG" == "Y" ]] && restore_configs "$SNAP"

    pause
}

# ============================================================
# MAIN MENU
# ============================================================
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
