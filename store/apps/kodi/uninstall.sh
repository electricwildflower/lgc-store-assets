#!/usr/bin/env bash
set -e

# --------------------------
# App metadata
# --------------------------
APP_NAME="Kodi"                   # Name stored in apps.json
FOLDER_NAME="kodi"                # Folder name under /apps/
DISPLAY_NAME="Kodi"  # Pretty name
PACKAGE_NAME="kodi"               # apt/flatpak/snap ID

# --------------------------
# Resolve data path from path_helper.py
# --------------------------
DATA_BASE=$(python3 - <<'PY'
from path_helper import get_data_base_path
print(get_data_base_path())
PY
)

APPS_DIR="$DATA_BASE/apps"
APP_DIR="$APPS_DIR/$FOLDER_NAME"
APPS_JSON="$APPS_DIR/apps.json"

echo "Using DATA_BASE: $DATA_BASE"
echo "Using APP_DIR: $APP_DIR"
echo "Using APPS_JSON: $APPS_JSON"


# --------------------------
# Uninstall system packages
# --------------------------
echo "Uninstalling $DISPLAY_NAME from system..."

# apt
if command -v apt >/dev/null 2>&1; then
    sudo apt remove --purge -y "$PACKAGE_NAME" || true
    sudo apt autoremove -y || true
fi

# flatpak
if command -v flatpak >/dev/null 2>&1; then
    flatpak remove -y org.videolan.VLC || true
fi

# snap
if command -v snap >/dev/null 2>&1; then
    sudo snap remove vlc || true
fi


# --------------------------
# Remove LGC app folder
# --------------------------
if [ -d "$APP_DIR" ]; then
    echo "Deleting directory: $APP_DIR"
    rm -rf "$APP_DIR"
else
    echo "No app directory found at $APP_DIR"
fi


# --------------------------
# Remove entry from apps.json
# --------------------------
if [ -f "$APPS_JSON" ]; then
    echo "Removing entry from apps.json for: $APP_NAME"

    # jq version
    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        jq --arg name "$APP_NAME" '
            .apps = (.apps | map(select(.name != $name)))
        ' "$APPS_JSON" > "$tmp" && mv "$tmp" "$APPS_JSON"

    else
        # Python fallback
        python3 - <<PY
import json

path = "$APPS_JSON"

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

if isinstance(data, dict) and isinstance(data.get("apps"), list):
    data["apps"] = [x for x in data["apps"] if x.get("name") != "$APP_NAME"]

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
PY

    fi

else
    echo "apps.json not found at: $APPS_JSON"
fi


echo "$DISPLAY_NAME successfully uninstalled."
exit 0

