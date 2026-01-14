#!/bin/bash

APP_NAME="Rebuild Manager"
SNAPSHOT_DIR="$HOME/rebuild-snapshots"

# Check for zenity
if ! command -v zenity >/dev/null 2>&1; then
    zenity --error --title="$APP_NAME" \
        --text="Zenity is not installed.\nPlease install it first."
    exit 1
fi

while true; do
    ACTION=$(zenity --list \
        --title="$APP_NAME" \
        --width=420 \
        --height=320 \
        --column="Action" \
        "Create new snapshot" \
        "View snapshot changes" \
        "List installed apps" \
        "Use existing snapshot" \
        "Clean old snapshots" \
        "Verify snapshots" \
        "Exit")

    # Cancel button or window closed
    if [[ -z "$ACTION" ]]; then
        exit 0
    fi

    case "$ACTION" in
        "Create new snapshot")
            rebuild-manager
            ;;
        "View snapshot changes")
            rebuild-manager
            ;;
        "List installed apps")
            rebuild-manager
            ;;
        "Use existing snapshot")
            SNAPSHOT=$(zenity --file-selection \
                --title="Select a rebuild snapshot" \
                --filename="$SNAPSHOT_DIR/" \
                --file-filter="Rebuild snapshots | *.tar.gz")

            if [[ -n "$SNAPSHOT" ]]; then
                zenity --info \
                    --title="$APP_NAME" \
                    --text="Snapshot selected:\n\n$SNAPSHOT\n\n(Execution logic will be added in Phase 2)"
            fi
            ;;
        "Clean old snapshots")
            rebuild-manager
            ;;
        "Verify snapshots")
            rebuild-manager
            ;;
        "Exit")
            exit 0
            ;;
    esac
done

