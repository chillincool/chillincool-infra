#!/bin/bash

# Generate API keys for *arr applications
# Usage: ./generate-api-keys.sh [app-name]

set -e

APP_NAME=${1:-"all"}

# Function to generate a random API key (32 characters, alphanumeric)
generate_api_key() {
    openssl rand -hex 16
}

# Function to create a secret YAML for an app
create_secret_yaml() {
    local app=$1
    local instance_name=$2
    local api_key=$(generate_api_key)
    local app_upper=$(echo "$app" | tr '[:lower:]' '[:upper:]')

    echo "---"
    echo "apiVersion: v1"
    echo "kind: Secret"
    echo "metadata:"
    echo "  name: ${app}-secret"
    echo "  namespace: default"
    echo "type: Opaque"
    echo "stringData:"
    echo "  ${app_upper}__APP__INSTANCENAME: \"${instance_name}\""
    echo "  ${app_upper}__AUTH__APIKEY: \"${api_key}\""

    echo "Generated API key for ${app}: ${api_key}" >&2
}

# Generate secrets based on app name
case $APP_NAME in
    "radarr")
        create_secret_yaml "radarr" "Radarr"
        ;;
    "radarr-4k")
        create_secret_yaml "radarr-4k" "Radarr 4K"
        ;;
    "sonarr")
        create_secret_yaml "sonarr" "Sonarr"
        ;;
    "sonarr-4k")
        create_secret_yaml "sonarr-4k" "Sonarr 4K"
        ;;
    "sonarr-anime")
        create_secret_yaml "sonarr-anime" "Sonarr Anime"
        ;;
    "lidarr")
        create_secret_yaml "lidarr" "Lidarr"
        ;;
    "prowlarr")
        create_secret_yaml "prowlarr" "Prowlarr"
        ;;
    "all")
        create_secret_yaml "radarr" "Radarr"
        create_secret_yaml "radarr-4k" "Radarr 4K"
        create_secret_yaml "sonarr" "Sonarr"
        create_secret_yaml "sonarr-4k" "Sonarr 4K"
        create_secret_yaml "sonarr-anime" "Sonarr Anime"
        create_secret_yaml "lidarr" "Lidarr"
        create_secret_yaml "prowlarr" "Prowlarr"
        ;;
    *)
        echo "Usage: $0 [radarr|radarr-4k|sonarr|sonarr-4k|sonarr-anime|lidarr|prowlarr|all]"
        exit 1
        ;;
esac