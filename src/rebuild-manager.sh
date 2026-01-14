#!/bin/bash

BASE_DIR="$HOME/system-rebuild"
SNAPSHOT_DIR="$HOME/rebuild-snapshots"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

mkdir -p "$BASE_DIR" "$SNAPSHOT_DIR"

pause() {
  echo
  read -rp "Press Enter to continue..."
}

create_snapshot() {
  echo "Creating rebuild snapshot..."

  rm -rf "$BASE_DIR"
  mkdir -p "$BASE_DIR"

  echo "Saving APT manual packages..."
  apt-mark showmanual > "$BASE_DIR/apt-manual.txt"

  echo "Saving Snap list..."
  snap list > "$BASE_DIR/snap-list.txt"

  echo "Saving Flatpak apps..."
  flatpak list --app > "$BASE_DIR/flatpak-apps.txt"

  echo "Saving APT sources and keys..."
  mkdir -p "$BASE_DIR/apt-sources"
  cp -r /etc/apt/sources.list* "$BASE_DIR/apt-sources/" 2>/dev/null
  cp -r /etc/apt/sources.list.d "$BASE_DIR/apt-sources/" 2>/dev/null
  cp -r /etc/apt/trusted.gpg.d "$BASE_DIR/apt-sources/" 2>/dev/null

  echo "Saving user configs..."
  cp -r "$HOME/.config" "$BASE_DIR/config"
  cp -r "$HOME/.local/share" "$BASE_DIR/local-share"

  ARCHIVE="$SNAPSHOT_DIR/ubuntu-rebuild-$DATE.tar.gz"
  tar -czvf "$ARCHIVE" -C "$HOME" system-rebuild

  echo
  echo "Snapshot created:"
  echo "$ARCHIVE"
  pause
}

list_apps() {
  echo "==== APT Manual Apps ===="
  apt-mark showmanual
  echo
  echo "==== Snap Apps ===="
  snap list
  echo
  echo "==== Flatpak Apps ===="
  flatpak list --app
  pause
}

show_changes() {
  LAST_TWO=$(ls -t "$SNAPSHOT_DIR"/ubuntu-rebuild-*.tar.gz 2>/dev/null | head -n 2)
  if [ "$(echo "$LAST_TWO" | wc -l)" -lt 2 ]; then
    echo "Not enough snapshots to compare."
    pause
    return
  fi

  TMP1=$(mktemp -d)
  TMP2=$(mktemp -d)

  tar -xzf $(echo "$LAST_TWO" | sed -n 2p) -C "$TMP1"
  tar -xzf $(echo "$LAST_TWO" | sed -n 1p) -C "$TMP2"

  echo "==== APT Changes ===="
  diff "$TMP1/system-rebuild/apt-manual.txt" "$TMP2/system-rebuild/apt-manual.txt" || true

  echo
  echo "==== Flatpak Changes ===="
  diff "$TMP1/system-rebuild/flatpak-apps.txt" "$TMP2/system-rebuild/flatpak-apps.txt" || true

  rm -rf "$TMP1" "$TMP2"
  pause
}

cleanup_snapshots() {
  echo "Available snapshots:"
  ls -lh "$SNAPSHOT_DIR"
  echo
  read -rp "Keep how many latest snapshots? " KEEP

  ls -t "$SNAPSHOT_DIR"/ubuntu-rebuild-*.tar.gz | tail -n +$((KEEP+1)) | xargs -r rm -v
  pause
}

verify_snapshot() {
  echo "Verifying snapshots..."
  for f in "$SNAPSHOT_DIR"/*.tar.gz; do
    echo "Checking $f"
    tar -tzf "$f" >/dev/null && echo "OK" || echo "CORRUPTED"
  done
  pause
}

while true; do
  clear
  echo "=================================="
  echo " Ubuntu Rebuild Manager"
  echo "=================================="
  echo "1) Create new rebuild snapshot"
  echo "2) View changes since last snapshot"
  echo "3) List installed apps"
  echo "4) Clean old snapshots"
  echo "5) Verify snapshots"
  echo "6) Exit"
  echo
  read -rp "Choose an option [1-6]: " CHOICE

  case $CHOICE in
    1) create_snapshot ;;
    2) show_changes ;;
    3) list_apps ;;
    4) cleanup_snapshots ;;
    5) verify_snapshot ;;
    6) exit 0 ;;
    *) echo "Invalid option"; pause ;;
  esac
done
