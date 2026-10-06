#!/usr/bin/env python3
"""Rank the 7 beyondthefirewall zones by HTTP request volume.

Queries Cloudflare's GraphQL Analytics API (httpRequests1dGroups) for each
zone over the last N days and prints a sorted summary. Read-only — makes
no changes to anything.

Usage:
    python3 zone_request_counts.py [--days N]

The API token is never a CLI argument (would land in shell history) or an
env var set by this script — it's read from CLOUDFLARE_API_TOKEN if your
shell already has it set for this one-off, otherwise you're prompted for
it (masked, via getpass), same convention as this repo's Terraform usage.

Needs a token scoped with at least "Zone Analytics: Read" on all 7 zones
(the Terraform token's Zone:DNS/Zone Settings/WAF/Bot Management/
Transform Rules:Edit scopes don't cover Analytics) — create a separate
read-only token for this rather than reusing the Terraform one.
"""

import argparse
import datetime
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

GRAPHQL_URL = "https://api.cloudflare.com/client/v4/graphql"

# Keep in sync with infra/cloudflare/locals.tf's `zones` map.
ZONES = {
    "app": {"name": "beyondthefirewall.app", "id": "106f4e63497e9575009dd02c07dc8469"},
    "co_uk": {"name": "beyondthefirewall.co.uk", "id": "743d5d531e0e73a8c11aa7ac4bf5eda4"},
    "info": {"name": "beyondthefirewall.info", "id": "86d0eb67b82436906809d215c2625146"},
    "io": {"name": "beyondthefirewall.io", "id": "98528201d83d6d272edb65192795677c"},
    "me": {"name": "beyondthefirewall.me", "id": "943c2aef23843537ad1a3892970b1501"},
    "org": {"name": "beyondthefirewall.org", "id": "0925e07c6497f5992593989f797ded1e"},
    "uk": {"name": "beyondthefirewall.uk", "id": "358f741b135bd5392d4bf48f920f0e85"},
}

QUERY = """
query ZoneRequests($zoneTag: String!, $since: Date!, $until: Date!) {
  viewer {
    zones(filter: { zoneTag: $zoneTag }) {
      httpRequests1dGroups(limit: 31, filter: { date_geq: $since, date_leq: $until }) {
        sum { requests }
      }
    }
  }
}
"""


def fetch_zone_requests(token: str, zone_id: str, since: str, until: str) -> int:
    body = json.dumps(
        {
            "query": QUERY,
            "variables": {"zoneTag": zone_id, "since": since, "until": until},
        }
    ).encode()
    req = urllib.request.Request(
        GRAPHQL_URL,
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.load(resp)

    if payload.get("errors"):
        raise RuntimeError(json.dumps(payload["errors"]))

    groups = payload["data"]["viewer"]["zones"][0]["httpRequests1dGroups"]
    return sum(g["sum"]["requests"] for g in groups)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=7, help="Lookback window (default: 7)")
    args = parser.parse_args()

    token = os.environ.get("CLOUDFLARE_API_TOKEN") or getpass.getpass(
        "Cloudflare API token (Zone Analytics: Read, all 7 zones): "
    )

    until = datetime.date.today()
    since = until - datetime.timedelta(days=args.days)

    results = []
    for key, zone in ZONES.items():
        try:
            requests_count = fetch_zone_requests(token, zone["id"], since.isoformat(), until.isoformat())
        except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError, KeyError, IndexError) as exc:
            print(f"  {zone['name']}: failed — {exc}", file=sys.stderr)
            continue
        results.append((zone["name"], requests_count))

    if not results:
        print("No results — check the token's scope (needs Zone Analytics: Read on all 7 zones).", file=sys.stderr)
        return 1

    results.sort(key=lambda r: r[1], reverse=True)

    print(f"\nRequests per zone, last {args.days} day(s) ({since} to {until}):\n")
    width = max(len(name) for name, _ in results)
    for name, count in results:
        print(f"  {name:<{width}}  {count:>12,}")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
