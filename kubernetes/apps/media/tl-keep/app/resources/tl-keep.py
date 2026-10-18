"""Keep a fixed number of TorrentLeech torrents tagged so Cleanuparr never deletes them.

TorrentLeech awards seeding points for up to KEEP_COUNT torrents. Cleanuparr's seeding
rules cannot count torrents, so this tags the ones to keep and Cleanuparr's Download
Cleaner has the tag on its ignore list.
"""

import json
import os
import re
import sys
import urllib.parse
import urllib.request

BASE_URL = os.environ["QBITTORRENT_URL"].rstrip("/")
KEEP_COUNT = int(os.environ.get("KEEP_COUNT", "100"))
KEEP_TAG = os.environ.get("KEEP_TAG", "tl-keep")
TRACKER = re.compile(os.environ.get("TRACKER_PATTERN", "torrentleech|tleechreload"))
DRY_RUN = os.environ.get("DRY_RUN", "").lower() in ("1", "true")
# Tracker messages meaning the torrent was removed from the site. These earn no seeding
# points, so they are never kept and Cleanuparr's dead-torrent handling can remove them.
UNREGISTERED = re.compile(r"unregistered|not registered|torrent not found|does not exist|deleted|nuked|trumped|dupe", re.I)


def api(path, data=None):
    body = urllib.parse.urlencode(data).encode() if data else None
    with urllib.request.urlopen(f"{BASE_URL}/api/v2/{path}", data=body, timeout=60) as resp:
        return resp.read()


def tags(torrent):
    return {tag.strip() for tag in torrent["tags"].split(",") if tag.strip()}


def unregistered(torrent):
    trackers = json.loads(api(f"torrents/trackers?hash={torrent['hash']}"))
    # Skip the DHT/PeX/LSD pseudo-entries, which have no real URL
    return any("://" in t["url"] and UNREGISTERED.search(t.get("msg") or "") for t in trackers)


def main():
    torrents = json.loads(api("torrents/info"))
    if not torrents:
        sys.exit("qBittorrent returned no torrents, refusing to change tags")

    tagged = [t for t in torrents if KEEP_TAG in tags(t)]

    # qBittorrent blanks the tracker field while a tracker is unreachable, so a torrent
    # that already has the tag still counts as a candidate.
    candidates = [
        t for t in torrents
        if t["progress"] == 1 and (TRACKER.search(t["tracker"]) or (not t["tracker"] and t in tagged))
    ]
    dropped = [t for t in candidates if unregistered(t)]
    candidates = [t for t in candidates if t not in dropped]
    for torrent in dropped:
        print(f"unregistered, not keeping: {torrent['name']}")

    # Hardlinked torrents first (keeping them costs no disk), then the newest.
    candidates.sort(key=lambda t: ("no-hardlink" in tags(t), -t["added_on"]))
    keep = {t["hash"] for t in candidates[:KEEP_COUNT]}

    add = [t for t in candidates if t["hash"] in keep and KEEP_TAG not in tags(t)]
    remove = [t for t in tagged if t["hash"] not in keep]

    print(f"{len(candidates)} candidates, keeping {len(keep)}, tagging {len(add)}, untagging {len(remove)}")
    for action, changed in (("addTags", add), ("removeTags", remove)):
        for torrent in changed:
            print(f"{action}: {torrent['name']}")
        if changed and not DRY_RUN:
            api(f"torrents/{action}", {"hashes": "|".join(t["hash"] for t in changed), "tags": KEEP_TAG})


if __name__ == "__main__":
    main()
