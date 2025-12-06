#!/usr/bin/env bash
set -euo pipefail

###############################################
# 1 - TEMPLATE - EDIT THESE VALUES FOR EACH APP
###############################################

APP_NAME="appname"             # Display name
CATEGORY="apps"            # apps | opensourcegaming
IMAGE_URL="rawurl"

#############################
# 2 - ADD YOUR COMMANDS BELOW
#############################

read -r -d '' RUN_SCRIPT_CONTENT << 'EOF' || true
#!/usr/bin/env bash

command

EOF

INSTALL_COMMANDS() {
    echo "[installer] Running system install commands..."
    sudo apt-get update
    sudo apt-get install -y app
}

#############################################
# DO NOT EDIT BELOW THIS LINE
#############################################

# Debug helper
log() { printf "[installer] %s\n" "$*"; }

# Determine script directory (where this .sh file lives)
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CWD="$(pwd)"

log "script dir: $SCRIPT_DIR"
log "current working dir: $CWD"

# Resolve DATA_BASE_PATH using path_helper.py.
# We add both SCRIPT_DIR and the current working directory to sys.path
DATA_BASE_PATH="$(python3 - <<'PY'
import sys, json
from pathlib import Path

# Insert possible locations where path_helper.py might live
script_dir = Path(r'''$SCRIPT_DIR''').resolve()
cwd = Path(r'''$CWD''').resolve()

# Put script_dir and cwd at front so imports find path_helper.py if it's in the repo
sys.path.insert(0, str(script_dir))
sys.path.insert(0, str(cwd))

try:
    import path_helper
    base = path_helper.get_data_base_path()
    if base is None:
        print("")
    else:
        print(str(base))
except Exception as e:
    # No path_helper import found; output empty so caller can error
    # You can uncomment the next line for verbose python debugging:
    # print("IMPORT_ERROR:"+repr(e))
    print("")
PY
)"

if [ -z "$DATA_BASE_PATH" ]; then
    log "ERROR: Could not locate path_helper.py or get_data_base_path() returned empty."
    log "Make sure path_helper.py is in the same directory as this script or in PYTHONPATH."
    log "You can run with: PYTHONPATH=/path/to/your/project ./install_template.sh"
    exit 1
fi

DATA_BASE_PATH="$(realpath "$DATA_BASE_PATH")"
log "Resolved DATA_BASE_PATH = $DATA_BASE_PATH"

# Build paths
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

# 1) Run system installation commands
INSTALL_COMMANDS

# 2) Create necessary directories
log "Creating directories..."
mkdir -p "$ASSETS_DIR"
mkdir -p "$RUN_DIR"

# 3) Download image (if provided)
if [ -n "$IMAGE_URL" ]; then
    log "Downloading icon from $IMAGE_URL ..."
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$ASSETS_DIR/app_image.jpg" "$IMAGE_URL" || log "Warning: wget failed to download image."
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$IMAGE_URL" -o "$ASSETS_DIR/app_image.jpg" || log "Warning: curl failed to download image."
    else
        log "No wget/curl available; skipping image download."
    fi
else
    log "No IMAGE_URL provided; skipping image download."
fi

# 4) Write run script correctly
RUN_SCRIPT_PATH="$RUN_DIR/${APP_DIR_NAME}.sh"
log "Writing run script to $RUN_SCRIPT_PATH"
printf "%s\n" "$RUN_SCRIPT_CONTENT" > "$RUN_SCRIPT_PATH"
chmod +x "$RUN_SCRIPT_PATH"

# 5) Ensure category directory exists and apps.json exists with required structure
mkdir -p "$(dirname "$APPS_JSON")"

if [ ! -f "$APPS_JSON" ]; then
    log "$APPS_JSON not found — creating with proper structure."
    cat > "$APPS_JSON" <<'JSON'
{
    "apps": []
}
JSON
fi

# Sanity check that we can write to apps.json
if [ ! -w "$APPS_JSON" ]; then
    log "ERROR: Cannot write to $APPS_JSON (permission denied)."
    exit 1
fi

# 6) Append entry to JSON safely with Python
log "Adding entry to $APPS_JSON"

python3 - <<PY
import json
from pathlib import Path

apps_json = Path(r'''$APPS_JSON''')

# Load existing file; if malformed, reset to required structure
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

# Prevent duplicates by name
if not any(item.get("name") == new_entry["name"] for item in data["apps"]):
    data["apps"].append(new_entry)
    apps_json.write_text(json.dumps(data, indent=4))
    print("ADDED")
else:
    print("EXISTS")
PY

RESULT=$?

log "Install complete. Summary:"
log " - App folder: $APP_DIR"
log " - Run script: $RUN_SCRIPT_PATH"
log " - JSON file: $APPS_JSON"

exit 0

