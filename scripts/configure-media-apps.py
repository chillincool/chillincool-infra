#!/usr/bin/env python3
"""
Configure inter-app communication for media stack.

This script:
- Reads API keys from 1Password
- Configures Prowlarr with Sonarr/Radarr/Lidarr applications
- Configures *arr apps with Decypharr download client
- Uses app APIs to establish app-to-app relationships
"""

import json
import subprocess
import sys
from typing import Dict, Optional
import requests


class MediaAppConfigurator:
    def __init__(self, namespace: str = "media", use_external_urls: bool = True, use_onepassword: bool = True):
        self.namespace = namespace
        self.use_external_urls = use_external_urls
        self.use_onepassword = use_onepassword
        self.api_keys: Dict[str, str] = {}
        self.app_urls: Dict[str, str] = {}  # External URLs for script API calls
        self.internal_urls: Dict[str, str] = {}  # Internal URLs for app-to-app communication

    def get_onepassword_field(self, item_name: str, field_name: str, vault: str = "talos") -> Optional[str]:
        """Get a field value from a 1Password item."""
        try:
            cmd = [
                "op", "item", "get", item_name,
                "--vault", vault,
                "--fields", field_name,
                "--reveal"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Error getting 1Password field {item_name}/{field_name}: {e}")
        return None

    def get_onepassword_json_field(self, item_name: str, field_label: str = "json", vault: str = "talos") -> Optional[dict]:
        """Get a JSON field value from a 1Password item and parse it."""
        try:
            # Use --format json to get the full item structure
            cmd = [
                "op", "item", "get", item_name,
                "--vault", vault,
                "--format", "json"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            item_data = json.loads(result.stdout)

            # Find the field with the matching label
            for field in item_data.get("fields", []):
                if field.get("label") == field_label:
                    json_value = field.get("value")
                    if json_value:
                        return json.loads(json_value)

            print(f"Field '{field_label}' not found in 1Password item {item_name}")
        except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as e:
            print(f"Error getting JSON from 1Password field {item_name}/{field_label}: {e}")
        return None

    def load_api_keys(self):
        """Load all API keys from 1Password."""
        apps = {
            "prowlarr": ("PROWLARR__AUTH__APIKEY", 9696),
            "sonarr": ("SONARR__AUTH__APIKEY", 8989),
            "sonarr-4k": ("SONARR__AUTH__APIKEY", 8989),
            "sonarr-anime": ("SONARR__AUTH__APIKEY", 8989),
            "radarr": ("RADARR__AUTH__APIKEY", 7878),
            "radarr-4k": ("RADARR__AUTH__APIKEY", 7878),
            "lidarr": ("LIDARR__AUTH__APIKEY", 8686),
        }

        for app, (field_name, port) in apps.items():
            if self.use_onepassword:
                # Get API key from 1Password
                item_name = f"{app}-secret"
                api_key = self.get_onepassword_field(item_name, field_name)
            else:
                # Fallback: get from Kubernetes secret (not implemented, removed old methods)
                api_key = None

            if api_key:
                self.api_keys[app] = api_key

                # Always set internal URLs for app-to-app communication
                self.internal_urls[app] = f"http://{app}.{self.namespace}.svc.cluster.local:{port}"

                # Use external HTTPRoute URLs when running script locally
                if self.use_external_urls:
                    self.app_urls[app] = f"https://{app}.chillincool.net"
                else:
                    self.app_urls[app] = self.internal_urls[app]

                print(f"✓ Loaded API key for {app}: {api_key}")
            else:
                print(f"✗ Failed to load API key for {app}")

        # Load decypharr auth from 1Password
        if self.use_onepassword:
            auth_json = self.get_onepassword_json_field("decypharr-auth", "json")
            decypharr_password = self.get_onepassword_field("decypharr-auth", "password")
            print(f"Decypharr auth JSON keys: {list(auth_json.keys()) if auth_json else 'None'}, password field length: {len(decypharr_password or '')}")
            if auth_json:
                decypharr_api_key = auth_json.get("api_token")
            else:
                decypharr_api_key = None
        else:
            decypharr_api_key = None

        if decypharr_api_key:
            self.api_keys["decypharr"] = decypharr_api_key
            self.decypharr_password = decypharr_password
            self.internal_urls["decypharr"] = f"http://decypharr.{self.namespace}.svc.cluster.local:8282"
            if self.use_external_urls:
                self.app_urls["decypharr"] = "https://decypharr.chillincool.net"
            else:
                self.app_urls["decypharr"] = self.internal_urls["decypharr"]
            print(f"✓ Loaded API key for decypharr: {decypharr_api_key}")
        else:
            print(f"✗ Failed to load API key for decypharr")

    def test_api_connection(self, app: str) -> bool:
        """Test if we can connect to an app's API."""
        if app not in self.api_keys or app not in self.app_urls:
            return False

        # Determine API version (v1 for Prowlarr and Lidarr, v3 for others)
        api_version = "v1" if app in ["prowlarr", "lidarr"] else "v3"
        url = f"{self.app_urls[app]}/api/{api_version}/system/status"
        headers = {"X-Api-Key": self.api_keys[app]}

        try:
            response = requests.get(url, headers=headers, timeout=5)
            if response.status_code == 200:
                print(f"✓ Connected to {app}")
                return True
            else:
                print(f"✗ Failed to connect to {app}: HTTP {response.status_code} (URL: {url})")
                if response.text:
                    print(f"  Response: {response.text[:200]}...")  # First 200 chars
        except requests.exceptions.RequestException as e:
            print(f"✗ Connection error for {app}: {e}")
        return False

    def test_arr_api_key(self, app_name: str, api_key: str) -> bool:
        """Test if an API key works for a *arr app."""
        app_url = self.app_urls.get(app_name)
        if not app_url:
            return False

        # Determine API version (v1 for Prowlarr and Lidarr, v3 for others)
        api_version = "v1" if app_name in ["prowlarr", "lidarr"] else "v3"
        test_url = f"{app_url}/api/{api_version}/system/status"
        headers = {"X-Api-Key": api_key}

        try:
            response = requests.get(test_url, headers=headers, timeout=5)
            return response.status_code == 200
        except requests.exceptions.RequestException:
            return False

    def add_application_to_prowlarr(self, app_name: str, app_type: str, force_update: bool = False):
        """Add or update a *arr application in Prowlarr."""
        if app_name not in self.api_keys:
            print(f"✗ No API key for {app_name}, skipping")
            return False

        prowlarr_url = self.app_urls["prowlarr"]
        prowlarr_api_key = self.api_keys["prowlarr"]

        # Map app type to Prowlarr implementation
        implementation_map = {
            "sonarr": "Sonarr",
            "radarr": "Radarr",
            "lidarr": "Lidarr",
        }

        base_type = app_type.replace("-4k", "").replace("-anime", "")
        implementation = implementation_map.get(base_type)

        if not implementation:
            print(f"✗ Unknown app type: {app_type}")
            return False

        # Check if application already exists
        list_url = f"{prowlarr_url}/api/v1/applications"
        headers = {"X-Api-Key": prowlarr_api_key}

        existing_app = None
        existing_api_key = None

        try:
            response = requests.get(list_url, headers=headers, timeout=5)
            if response.status_code == 200:
                existing_apps = response.json()
                for existing in existing_apps:
                    if existing.get("name", "").lower() == app_name.lower():
                        existing_app = existing
                        # Extract existing API key from fields
                        for field in existing.get("fields", []):
                            if field.get("name") == "apiKey":
                                existing_api_key = field.get("value")
                        break
        except requests.exceptions.RequestException as e:
            print(f"✗ Error checking existing applications: {e}")
            return False

        # If app exists, decide whether to update
        if existing_app:
            app_id = existing_app["id"]
            new_api_key = self.api_keys[app_name]

            # If API keys match, no update needed
            if existing_api_key == new_api_key:
                print(f"✓ {app_name} already exists with current API key (ID: {app_id})")
                return True

            # API key has changed, update the application
            print(f"ℹ Updating {app_name} API key")
            return self._update_prowlarr_application(
                existing_app, app_name, app_type, implementation
            )

        # App doesn't exist, create it
        return self._create_prowlarr_application(
            app_name, app_type, implementation, list_url, headers
        )

    def _update_prowlarr_application(self, existing_app: dict, app_name: str, app_type: str, implementation: str) -> bool:
        """Update an existing Prowlarr application with new API key."""
        prowlarr_url = self.app_urls["prowlarr"]
        prowlarr_api_key = self.api_keys["prowlarr"]
        app_id = existing_app["id"]

        # Determine sync categories
        base_type = app_type.replace("-4k", "").replace("-anime", "")
        if base_type == "sonarr":
            sync_categories = [5000, 5030, 5040, 5045]
            if "anime" in app_name:
                sync_categories.append(5070)
        elif base_type == "radarr":
            sync_categories = [2000, 2030, 2040, 2045]
        elif base_type == "lidarr":
            sync_categories = [3000, 3010, 3040]
        else:
            sync_categories = [2000]

        # Update the fields with new API key
        updated_fields = []
        for field in existing_app.get("fields", []):
            if field.get("name") == "apiKey":
                field["value"] = self.api_keys[app_name]
            elif field.get("name") == "baseUrl":
                field["value"] = self.internal_urls[app_name]
            elif field.get("name") == "prowlarrUrl":
                field["value"] = self.internal_urls["prowlarr"]
            elif field.get("name") == "syncCategories":
                field["value"] = sync_categories
            updated_fields.append(field)

        payload = {
            **existing_app,
            "fields": updated_fields
        }

        update_url = f"{prowlarr_url}/api/v1/applications/{app_id}"
        headers = {"X-Api-Key": prowlarr_api_key}

        try:
            response = requests.put(update_url, headers=headers, json=payload, timeout=10)
            if response.status_code == 202:
                print(f"✓ Updated {app_name} in Prowlarr (ID: {app_id})")
                return True
            else:
                print(f"✗ Failed to update {app_name}: HTTP {response.status_code}")
                print(f"  Response: {response.text}")
        except requests.exceptions.RequestException as e:
            print(f"✗ Error updating {app_name}: {e}")

        return False

    def _test_prowlarr_application(self, app_id: int, app_name: str, prowlarr_url: str, headers: dict):
        """Test an application connection in Prowlarr."""
        test_url = f"{prowlarr_url}/api/v1/applications/{app_id}/test"
        try:
            response = requests.get(test_url, headers=headers, timeout=10)
            if response.status_code == 200:
                print(f"✓ Tested {app_name} connection in Prowlarr")
            else:
                print(f"⚠ Failed to test {app_name}: HTTP {response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"⚠ Error testing {app_name}: {e}")

    def _test_all_prowlarr_applications(self):
        """Test all applications in Prowlarr."""
        prowlarr_url = self.app_urls["prowlarr"]
        prowlarr_api_key = self.api_keys["prowlarr"]
        test_url = f"{prowlarr_url}/api/v1/applications/testall"
        headers = {"X-Api-Key": prowlarr_api_key}

        try:
            response = requests.post(test_url, headers=headers, timeout=30)  # Longer timeout for testing
            if response.status_code == 200:
                results = response.json()
                print("✓ Tested all Prowlarr applications:")
                for result in results:
                    app_id = result.get("id")
                    is_valid = result.get("isValid", False)
                    failures = result.get("validationFailures", [])
                    status = "✓" if is_valid else "✗"
                    print(f"  {status} App ID {app_id}: {'Valid' if is_valid else f'Invalid - {failures}'}")
            else:
                print(f"⚠ Failed to test applications: HTTP {response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"⚠ Error testing applications: {e}")

    def _create_prowlarr_application(self, app_name: str, app_type: str, implementation: str, list_url: str, headers: dict) -> bool:
        """Create a new Prowlarr application."""
        base_type = app_type.replace("-4k", "").replace("-anime", "")

        # Get sync categories for this app type
        # For Sonarr: TV categories (5000=TV, 5030=TV/WEB-DL, 5040=TV/HD, 5045=TV/UHD, 5070=Anime)
        # For Radarr: Movie categories (2000=Movies, 2030=Movies/WEB-DL, 2040=Movies/HD, 2045=Movies/UHD)
        # For Lidarr: Audio categories (3000=Audio, 3010=Audio/MP3, 3040=Audio/Lossless)
        if base_type == "sonarr":
            sync_categories = [5000, 5030, 5040, 5045]  # TV categories
            if "anime" in app_name:
                sync_categories.append(5070)  # Add Anime category
        elif base_type == "radarr":
            sync_categories = [2000, 2030, 2040, 2045]  # Movie categories
        elif base_type == "lidarr":
            sync_categories = [3000, 3010, 3040]  # Audio categories
        else:
            sync_categories = [2000]  # Default to Movies

        # Create the application
        # Use internal URLs for app-to-app communication since Prowlarr runs in-cluster
        payload = {
            "name": app_name,
            "syncLevel": "fullSync",
            "implementation": implementation,
            "configContract": f"{implementation}Settings",
            "fields": [
                {
                    "name": "prowlarrUrl",
                    "value": self.internal_urls["prowlarr"]
                },
                {
                    "name": "baseUrl",
                    "value": self.internal_urls[app_name]
                },
                {
                    "name": "apiKey",
                    "value": self.api_keys[app_name]
                },
                {
                    "name": "syncCategories",
                    "value": sync_categories
                }
            ],
            "tags": []
        }

        try:
            response = requests.post(list_url, headers=headers, json=payload, timeout=10)
            if response.status_code in [200, 201]:
                print(f"✓ Added {app_name} to Prowlarr")
                return True
            else:
                print(f"✗ Failed to add {app_name} to Prowlarr: HTTP {response.status_code}")
                print(f"  Response: {response.text}")
        except requests.exceptions.RequestException as e:
            print(f"✗ Error adding {app_name} to Prowlarr: {e}")

        return False

    def add_decypharr_to_arr(self, arr_app: str):
        """Add Decypharr as a download client to a *arr app."""
        if "decypharr" not in self.api_keys or arr_app not in self.api_keys:
            print(f"✗ Missing API keys for Decypharr or {arr_app}")
            return False

        arr_url = self.app_urls[arr_app]
        arr_api_key = self.api_keys[arr_app]

        # Determine API version (v1 for Lidarr, v3 for others)
        api_version = "v1" if arr_app == "lidarr" else "v3"
        list_url = f"{arr_url}/api/{api_version}/downloadclient"
        headers = {"X-Api-Key": arr_api_key}

        try:
            response = requests.get(list_url, headers=headers, timeout=5)
            if response.status_code == 200:
                existing_clients = response.json()
                for client in existing_clients:
                    if client.get("name", "").lower() == "decypharr":
                        print(f"✓ Decypharr already exists in {arr_app} (ID: {client['id']})")
                        return True
        except requests.exceptions.RequestException as e:
            print(f"✗ Error checking existing download clients in {arr_app}: {e}")
            return False

        # Add Decypharr as a download client (using SABnzbd implementation)
        # Get Decypharr auth details
        auth_json = self.get_onepassword_json_field("decypharr-auth", "json")
        if not auth_json:
            print(f"✗ Could not get Decypharr auth details")
            return False

        payload = {
            "enable": True,
            "protocol": "torrent",
            "priority": 1,
            "removeCompletedDownloads": True,
            "removeFailedDownloads": True,
            "name": "Decypharr",
            "fields": [
                {
                    "name": "host",
                    "value": f"decypharr.{self.namespace}.svc.cluster.local"
                },
                {
                    "name": "port",
                    "value": 8282
                },
                {
                    "name": "username",
                    "value": auth_json.get("username", "chris")
                },
                {
                    "name": "password",
                    "value": self.decypharr_password
                },
                {
                    "name": "useSsl",
                    "value": False
                },
                {
                    "name": "category",
                    "value": arr_app  # Use arr app name as category
                }
            ],
            "implementationName": "qBittorrent",
            "implementation": "qBittorrent",
            "configContract": "QBittorrentSettings",
            "tags": []
        }

        print(f"Configuring Decypharr for {arr_app} with host: decypharr.{self.namespace}.svc.cluster.local:8282, username: {auth_json.get('username', 'admin')}, password length: {len(auth_json.get('password', ''))}")

        try:
            response = requests.post(list_url, headers=headers, json=payload, timeout=10)
            if response.status_code in [200, 201]:
                print(f"✓ Added Decypharr to {arr_app}")
                return True
            else:
                print(f"✗ Failed to add Decypharr to {arr_app}: HTTP {response.status_code}")
                print(f"  Response: {response.text}")
        except requests.exceptions.RequestException as e:
            print(f"✗ Error adding Decypharr to {arr_app}: {e}")

        return False

    def configure_all(self, force_update: bool = False):
        """Configure all inter-app relationships."""
        print("\n=== Loading API Keys ===")
        self.load_api_keys()

        print("\n=== Testing API Connections ===")
        # Test connections (optional, but useful for debugging)
        for app in ["prowlarr", "sonarr", "radarr", "lidarr"]:
            if app in self.api_keys:
                self.test_api_connection(app)

        print("\n=== Configuring Prowlarr Applications ===")
        if force_update:
            print("Force update mode: Will update API keys even if old keys still work")

        arr_apps = [
            ("sonarr", "sonarr"),
            ("sonarr-4k", "sonarr"),
            ("sonarr-anime", "sonarr"),
            ("radarr", "radarr"),
            ("radarr-4k", "radarr"),
            ("lidarr", "lidarr"),
        ]

        for app_name, app_type in arr_apps:
            if app_name in self.api_keys:
                self.add_application_to_prowlarr(app_name, app_type, force_update=force_update)

        # Test all Prowlarr applications after configuration
        self._test_all_prowlarr_applications()

        print("\n=== Configuring Decypharr Download Clients ===")
        for arr_app in ["sonarr", "sonarr-4k", "sonarr-anime", "radarr", "radarr-4k", "lidarr"]:
            if arr_app in self.api_keys:
                self.add_decypharr_to_arr(arr_app)

        print("\n=== Configuration Complete ===")
        print("\nNote: Decypharr configuration requires manual setup in each *arr app")
        print("as qBittorrent type with correct username/password credentials.")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Configure media app inter-communication")
    parser.add_argument(
        "--force-update",
        action="store_true",
        help="Force update API keys even if old keys still work"
    )
    args = parser.parse_args()

    print("Media App Configurator")
    print("=" * 50)
    print("Using HTTPRoute URLs (*.chillincool.net)\n")

    configurator = MediaAppConfigurator(namespace="media", use_external_urls=True)
    configurator.configure_all(force_update=args.force_update)


if __name__ == "__main__":
    main()
