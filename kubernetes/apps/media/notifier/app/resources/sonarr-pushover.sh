#!/usr/bin/env bash
set -euo pipefail

# Incoming arguments
PAYLOAD=${1:-}

# Required environment variables
: "${APPRISE_SONARR_PUSHOVER_URL:?Pushover URL required}"

echo "[DEBUG] Sonarr Payload: ${PAYLOAD}"

function _jq() {
    jq -r "${1:?}" <<<"${PAYLOAD}"
}

function get_instance_name() {
    local app_url=$(_jq '.applicationUrl')
    # Extract subdomain from URL (e.g., "sonarr-4k" from "https://sonarr-4k.chillincool.net")
    local hostname=$(echo "$app_url" | sed -E 's|https?://([^/.]+).*|\1|')
    case "$hostname" in
        sonarr-4k)    echo "Sonarr 4K" ;;
        sonarr-anime) echo "Sonarr Anime" ;;
        sonarr)       echo "Sonarr" ;;
        *)            echo "Sonarr" ;;
    esac
}

function notify() {
    local event_type=$(_jq '.eventType')
    local instance=$(get_instance_name)

    case "${event_type}" in
        "Download")
            printf -v PUSHOVER_TITLE \
                "%s: Episode %s" "$instance" "$( [[ "$(_jq '.isUpgrade')" == "true" ]] && echo "Upgraded" || echo "Added" )"
            printf -v PUSHOVER_MESSAGE "<b>%s (S%02dE%02d)</b><small>\n%s</small><small>\n\n<b>Client:</b> %s</small>" \
                "$(_jq '.series.title')" \
                "$(_jq '.episodes[0].seasonNumber')" \
                "$(_jq '.episodes[0].episodeNumber')" \
                "$(_jq '.episodes[0].title')" \
                "$(_jq '.downloadClient')"
            printf -v PUSHOVER_URL "%s/series/%s" \
                "$(_jq '.applicationUrl')" \
                "$(_jq '.series.titleSlug')"
            printf -v PUSHOVER_URL_TITLE "View Series"
            printf -v PUSHOVER_PRIORITY "low"
            ;;
        "ManualInteractionRequired")
            printf -v PUSHOVER_TITLE "%s: Manual Interaction Required" "$instance"
            printf -v PUSHOVER_MESSAGE "<b>%s</b><small>\n<b>Client:</b> %s</small>" \
                "$(_jq '.series.title')" \
                "$(_jq '.downloadClient')"
            printf -v PUSHOVER_URL "%s/activity/queue" "$(_jq '.applicationUrl')"
            printf -v PUSHOVER_URL_TITLE "View Queue"
            printf -v PUSHOVER_PRIORITY "high"
            ;;
        "Test")
            printf -v PUSHOVER_TITLE "%s: Test Notification" "$instance"
            printf -v PUSHOVER_MESSAGE "Howdy this is a test notification"
            printf -v PUSHOVER_URL "%s" "$(_jq '.applicationUrl')"
            printf -v PUSHOVER_URL_TITLE "View Series"
            printf -v PUSHOVER_PRIORITY "low"
            ;;
        *)
            echo "[ERROR] Unknown event type: ${event_type}" >&2
            return 1
            ;;
    esac

    apprise -vv --title "${PUSHOVER_TITLE}" --body "${PUSHOVER_MESSAGE}" --input-format html \
        "${APPRISE_SONARR_PUSHOVER_URL}?url=${PUSHOVER_URL}&url_title=${PUSHOVER_URL_TITLE}&priority=${PUSHOVER_PRIORITY}&format=html"
}

function main() {
    notify
}

main "$@"
