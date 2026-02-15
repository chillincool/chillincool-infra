#!/usr/bin/env bash
set -euo pipefail

# Incoming arguments - JSON payload from Plex webhook
PAYLOAD=${1:-}

# Required environment variables
: "${DISCORD_PLEX_WEBHOOK_URL:?Discord webhook URL required}"

echo "[DEBUG] Plex Payload: ${PAYLOAD}"

function _jq() {
    jq -r "${1:?}" <<<"${PAYLOAD}"
}

function send_discord() {
    local title="$1"
    local description="$2"
    local color="$3"

    local json
    json=$(jq -n \
        --arg title "$title" \
        --arg desc "$description" \
        --argjson color "$color" \
        '{
            embeds: [{
                title: $title,
                description: $desc,
                color: $color,
                footer: {text: "Plex Media Server"}
            }]
        }')

    curl -s -H "Content-Type: application/json" -d "$json" "$DISCORD_PLEX_WEBHOOK_URL"
}

function notify() {
    local event=$(_jq '.event')

    # Only handle library.new events
    if [[ "$event" != "library.new" ]]; then
        echo "[INFO] Ignoring event: ${event}"
        return 0
    fi

    local media_type=$(_jq '.Metadata.type // "unknown"')
    local title=""
    local description=""
    local color=5793266  # Blue

    case "${media_type}" in
        "movie")
            title=$(_jq '.Metadata.title // "Unknown Movie"')
            local year=$(_jq '.Metadata.year // ""')
            local summary=$(_jq '.Metadata.summary // "" | .[0:200]')
            [[ -n "$year" ]] && title="$title ($year)"
            description="$summary"
            ;;
        "episode")
            local show=$(_jq '.Metadata.grandparentTitle // "Unknown Show"')
            local season=$(_jq '.Metadata.parentIndex // "?"')
            local episode=$(_jq '.Metadata.index // "?"')
            local ep_title=$(_jq '.Metadata.title // "Unknown Episode"')
            title="$show - S${season}E${episode}"
            description="$ep_title"
            ;;
        *)
            title=$(_jq '.Metadata.title // "Unknown Media"')
            ;;
    esac

    send_discord "Added to Library: ${title}" "$description" "$color"
}

function main() {
    if [[ -z "$PAYLOAD" ]]; then
        echo "[ERROR] No payload received" >&2
        exit 1
    fi
    notify
}

main "$@"
