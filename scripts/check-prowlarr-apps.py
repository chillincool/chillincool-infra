#!/usr/bin/env python3
"""Quick script to check what applications are configured in Prowlarr."""

import base64
import subprocess
import requests

# Get Prowlarr API key
cmd = ["kubectl", "get", "secret", "prowlarr-secret", "-n", "media", "-o", "jsonpath={.data.PROWLARR__AUTH__APIKEY}"]
result = subprocess.run(cmd, capture_output=True, text=True, check=True)
api_key = base64.b64decode(result.stdout.strip()).decode('utf-8')

# List applications
url = "https://prowlarr.chillincool.net/api/v1/applications"
headers = {"X-Api-Key": api_key}

response = requests.get(url, headers=headers, timeout=10)
if response.status_code == 200:
    apps = response.json()
    print(f"\nConfigured Applications in Prowlarr ({len(apps)} total):\n")
    for app in apps:
        print(f"  • {app['name']} (ID: {app['id']}) - {app['implementation']}")
        print(f"    Sync Level: {app['syncLevel']}")
        # Find baseUrl field
        for field in app.get('fields', []):
            if field.get('name') == 'baseUrl':
                print(f"    URL: {field.get('value')}")
        print()
else:
    print(f"Error: HTTP {response.status_code}")
    print(response.text)
