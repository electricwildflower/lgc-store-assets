#!/usr/bin/env bash
set -euo pipefail

###############################################
# 1 - TEMPLATE - EDIT THESE VALUES FOR EACH APP
###############################################

APP_NAME="Emby"             # Display name
CATEGORY="apps"             # apps | opensourcegaming
IMAGE_URL="https://github.com/electricwildflower/lgc-store-assets/blob/main/store/apps/emby/emby.jpg?raw=true"
APPIMAGE_URL="https://github.com/MediaBrowser/Emby.Theater/releases/download/4.8.20/Emby.Theater-4.8.20-linux-x64.AppImage"

#############################
# 2 - ADD YOUR COMMANDS BELOW
#############################

read -r -d '' RUN_SCRIPT_CONTENT << 'EOF' || true
#!/usr/bin/env bash
# Launch Emby Theatre AppImage

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
APPIMAGE_PATH="$SCRIPT_DIR/../Emby.Theater.AppImage"

if [ ! -f "$APPIMAGE_PATH" ]; then
    echo "ERROR: AppImage not found at $APPIMAGE_PATH"
    exit 1
fi

# Make sure it's executable
chmod +x "$APPIMAGE_PATH"

# Run the AppImage
"$APPIMAGE_PATH" "$@"
EOF

INSTALL_COMMANDS() {
    echo "[installer] Ensuring required tools (wget/curl) are installed..."

    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y wget curl
    fi
}

#############################################
# DO NOT EDIT BELOW THIS LINE
#############################################

log() { printf "[installer] %s\n" "$*"; }

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CWD="$(pwd)"
log "script dir: $SCRIPT_DIR"
log "current working dir: $CWD"

DATA_BASE_PATH="$(python3 - <<'PY'
import sys
from pathlib import Path
script_dir = Path(r'''$SCRIPT_DIR''').resolve()
cwd = Path(r'''$CWD''').resolve()
sys.path.insert(0, str(script_dir))
sys.path.insert(0, str(cwd))
try:
    import path_helper
    base = path_helper.get_data_base_path()
    print(str(base) if base else "")
except Exception:
    print("")
PY
)"

if [ -z "$DATA_BASE_PATH" ]; then
    log "ERROR: Could not locate path_helper.py or get_data_base_path() returned empty."
    exit 1
fi

DATA_BASE_PATH="$(realpath "$DATA_BASE_PATH")"
log "Resolved DATA_BASE_PATH = $DATA_BASE_PATH"

APP_DIR_NAME="$(echo "$APP_NAME" | tr ' ' '_' )"
CATEGORY_DIR="$DATA_BASE_PATH/$CATEGORY"
APP_DIR="$CATEGORY_DIR/$APP_DIR_NAME"
ASSETS_DIR="$APP_DIR/assets"
RUN_DIR="$APP_DIR/run"
APPS_JSON="$CATEGORY_DIR/apps.json"

log "CATEGORY_DIR = $CATEGORY_DIR"
log "APP_DIR = $APP_DIR"
log "APPS_JSON = $APPS_JSON"

TIMESTAMP="$(python3 - <<'PY'
from datetime import datetime
print(datetime.utcnow().isoformat())
PY
)"

# 1) Install dependencies
INSTALL_COMMANDS

# 2) Create directories
log "Creating directories..."
mkdir -p "$ASSETS_DIR"
mkdir -p "$RUN_DIR"

# 3) Download icon
if [ -n "$IMAGE_URL" ]; then
    log "Downloading icon from $IMAGE_URL ..."
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$ASSETS_DIR/app_image.jpg" "$IMAGE_URL" || log "Warning: wget failed."
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$IMAGE_URL" -o "$ASSETS_DIR/app_image.jpg" || log "Warning: curl failed."
    fi
fi

# 4) Download AppImage
log "Downloading Emby Theatre AppImage..."
APPIMAGE_PATH="$APP_DIR/Emby.Theater.AppImage"
if command -v wget >/dev/null 2>&1; then
    wget -q -O "$APPIMAGE_PATH" "$APPIMAGE_URL" || log "ERROR: Failed to download AppImage"
elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$APPIMAGE_URL" -o "$APPIMAGE_PATH" || log "ERROR: Failed to download AppImage"
fi
chmod +x "$APPIMAGE_PATH"

# 5) Write run script
RUN_SCRIPT_PATH="$RUN_DIR/${APP_DIR_NAME}.sh"
log "Writing run script to $RUN_SCRIPT_PATH"
printf "%s\n" "$RUN_SCRIPT_CONTENT" > "$RUN_SCRIPT_PATH"
chmod +x "$RUN_SCRIPT_PATH"

# 6) Ensure apps.json exists
mkdir -p "$(dirname "$APPS_JSON")"
if [ ! -f "$APPS_JSON" ]; then
    log "$APPS_JSON not found — creating with proper structure."
    cat > "$APPS_JSON" <<'JSON'
{
    "apps": []
}
JSON
fi

# 7) Append entry to JSON safely
log "Adding entry to $APPS_JSON"
python3 - <<PY
import json
from pathlib import Path

apps_json = Path(r'''$APPS_JSON''')
try:
    data = json.loads(apps_json.read_text())
    if not isinstance(data, dict) or "apps" not in data:
        data = {"apps": []}
except Exception:
    data = {"apps": []}

new_entry = {
    "name": r'''$APP_NAME''',
    "image": "apps/" + r'''$APP_DIR_NAME''' + "/assets/app_image.jpg",
    "sh_file": "apps/" + r'''$APP_DIR_NAME''' + "/run/" + r'''$APP_DIR_NAME''' + ".sh",
    "app_dir": "apps/" + r'''$APP_DIR_NAME''',
    "added_date": r'''$TIMESTAMP'''
}

if not any(item.get("name") == new_entry["name"] for item in data["apps"]):
    data["apps"].append(new_entry)
    apps_json.write_text(json.dumps(data, indent=4))
    print("ADDED")
else:
    print("EXISTS")
PY

log "Install complete. Summary:"
log " - App folder: $APP_DIR"
log " - Run script: $RUN_SCRIPT_PATH"
log " - JSON file: $APPS_JSON"

exit 0


