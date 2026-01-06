#!/bin/bash

# Configuration
SYNCTHING_API_KEY="${SYNCTHING_API_KEY:-}"
SYNCTHING_URL="${SYNCTHING_URL:-http://127.0.0.1:8384}"
NOTIFY_ENABLED="${SYNCTHING_NOTIFY:-true}"

# Icons
ICON_RUNNING="󰓦"
ICON_SYNCING="󰓦"
ICON_STOPPED="󰓨"
ICON_ERROR="󰓨"
ICON_PAUSED="󰏤"

# Check if syncthing service is running
is_running() {
    systemctl --user is-active syncthing.service >/dev/null 2>&1
}

# Get API key from config if not set
get_api_key() {
    if [[ -z "$SYNCTHING_API_KEY" ]]; then
        local config_file="$HOME/.local/state/syncthing/config.xml"
        [[ -f "$config_file" ]] || config_file="$HOME/.config/syncthing/config.xml"
        if [[ -f "$config_file" ]]; then
            SYNCTHING_API_KEY=$(grep -oP '(?<=<apikey>)[^<]+' "$config_file" 2>/dev/null || true)
        fi
    fi
}

# Query Syncthing API
api_get() {
    local endpoint="$1"
    get_api_key
    if [[ -n "$SYNCTHING_API_KEY" ]]; then
        curl -s -H "X-API-Key: $SYNCTHING_API_KEY" "$SYNCTHING_URL/rest/$endpoint" 2>/dev/null
    fi
}

# Get sync completion percentage
get_sync_status() {
    local completion
    completion=$(api_get "db/completion" 2>/dev/null)
    if [[ -n "$completion" ]]; then
        echo "$completion" | grep -oP '"completion":\s*\K[0-9.]+' 2>/dev/null | head -1
    fi
}

# Get connected device count
get_connections() {
    local connections
    connections=$(api_get "system/connections" 2>/dev/null)
    if [[ -n "$connections" ]]; then
        echo "$connections" | grep -oP '"connected":\s*true' | wc -l
    else
        echo "0"
    fi
}

# Check if any folder is syncing
is_syncing() {
    local status
    status=$(api_get "db/completion" 2>/dev/null)
    if [[ -n "$status" ]]; then
        local completion
        completion=$(echo "$status" | grep -oP '"completion":\s*\K[0-9.]+' 2>/dev/null | head -1)
        if [[ -n "$completion" ]] && (( $(echo "$completion < 100" | bc -l 2>/dev/null || echo 0) )); then
            return 0
        fi
    fi
    return 1
}

# Check for errors
has_errors() {
    local errors
    errors=$(api_get "system/error" 2>/dev/null)
    if [[ -n "$errors" ]] && echo "$errors" | grep -q '"errors":\s*\[\s*{'; then
        return 0
    fi
    return 1
}

# Get folder status summary
get_folder_summary() {
    local folders summary=""
    folders=$(api_get "config/folders" 2>/dev/null)
    if [[ -n "$folders" ]]; then
        local ids
        ids=$(echo "$folders" | grep -oP '"id":\s*"\K[^"]+' 2>/dev/null)
        local count=0
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            ((count++))
        done <<< "$ids"
        echo "$count folders configured"
    fi
}

# Send notification
notify() {
    if [[ "$NOTIFY_ENABLED" == "true" ]] && command -v notify-send >/dev/null; then
        notify-send "Syncthing" "$1" -i syncthing "${@:2}"
    fi
}

# Output status for waybar
status() {
    if ! is_running; then
        echo "{\"text\": \"$ICON_STOPPED\", \"tooltip\": \"Syncthing stopped\\n\\nLeft-click: Start service\", \"class\": \"stopped\"}"
        return
    fi

    local icon="$ICON_RUNNING"
    local class="active"
    local tooltip="Syncthing running"
    local extra_info=""

    # Check for errors first
    if has_errors; then
        icon="$ICON_ERROR"
        class="error"
        tooltip="Syncthing has errors!"
    # Check if syncing
    elif is_syncing; then
        local completion
        completion=$(get_sync_status)
        if [[ -n "$completion" ]]; then
            icon="$ICON_SYNCING"
            class="syncing"
            tooltip="Syncing: ${completion%.*}%"
            extra_info=" ${completion%.*}%"
        fi
    fi

    # Get connection count
    local connections
    connections=$(get_connections)
    if [[ "$connections" -gt 0 ]]; then
        tooltip="$tooltip\\n$connections device(s) connected"
    else
        tooltip="$tooltip\\nNo devices connected"
    fi

    # Get folder info
    local folder_info
    folder_info=$(get_folder_summary)
    [[ -n "$folder_info" ]] && tooltip="$tooltip\\n$folder_info"

    tooltip="$tooltip\\n\\nLeft-click: Stop service\\nMiddle-click: Open Web UI\\nRight-click: Rescan all"

    echo "{\"text\": \"${icon}${extra_info}\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
}

# Toggle start/stop
toggle() {
    if is_running; then
        systemctl --user stop syncthing.service
        notify "Stopped" -u low
    else
        systemctl --user start syncthing.service
        notify "Started" -u low
    fi
}

# Open web UI
open_webui() {
    if command -v xdg-open >/dev/null; then
        xdg-open "$SYNCTHING_URL" &>/dev/null &
    elif command -v open >/dev/null; then
        open "$SYNCTHING_URL" &>/dev/null &
    fi
}

# Rescan all folders
rescan_all() {
    get_api_key
    if [[ -z "$SYNCTHING_API_KEY" ]]; then
        notify "Cannot rescan: API key not found" -u critical
        return 1
    fi

    local folders
    folders=$(api_get "config/folders" 2>/dev/null)
    if [[ -n "$folders" ]]; then
        local ids
        ids=$(echo "$folders" | grep -oP '"id":\s*"\K[^"]+' 2>/dev/null)
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            curl -s -X POST -H "X-API-Key: $SYNCTHING_API_KEY" \
                "$SYNCTHING_URL/rest/db/scan?folder=$id" &>/dev/null
        done <<< "$ids"
        notify "Rescanning all folders" -u low
    fi
}

# Pause/resume syncing
pause_resume() {
    get_api_key
    if [[ -z "$SYNCTHING_API_KEY" ]]; then
        notify "Cannot pause: API key not found" -u critical
        return 1
    fi

    local config
    config=$(api_get "config" 2>/dev/null)
    # This is a simplified toggle - full implementation would need to track state
    notify "Use Web UI to pause/resume" -u normal
    open_webui
}

case "$1" in
    toggle)
        toggle
        ;;
    webui)
        open_webui
        ;;
    rescan)
        rescan_all
        ;;
    pause)
        pause_resume
        ;;
    status|"")
        status
        ;;
    *)
        echo "Usage: $0 {toggle|status|webui|rescan|pause}"
        exit 1
        ;;
esac
