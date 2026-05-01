#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path


OUTPUT_PATH = Path(os.getenv("GITHUB_CONTRIB_OUTPUT", "data/github_contributions.json"))
USERNAME = (os.getenv("GITHUB_CONTRIB_USERNAME", "tianye-J") or "tianye-J").strip()
TOKEN = (os.getenv("CONTRIB_TOKEN") or os.getenv("GITHUB_CONTRIB_TOKEN", "")).strip()
WEEKS = 26


def iso_today() -> date:
    return datetime.now(timezone.utc).date()


def fallback_payload(reason: str) -> dict:
    today = iso_today()
    start = today - timedelta(days=WEEKS * 7 - 1)
    return {
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "username": USERNAME,
        "total_contributions": 0,
        "status": "fallback",
        "reason": reason,
        "range": {
            "weeks": WEEKS,
            "from": start.isoformat(),
            "to": today.isoformat(),
        },
        "weeks": [],
    }


def write_payload(payload: dict) -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def build_payload(calendar: dict, start: date, end: date) -> dict:
    weeks = []
    for week in calendar.get("weeks", [])[-WEEKS:]:
        days = []
        for day in week.get("contributionDays", []):
            days.append(
                {
                    "date": day["date"],
                    "count": day["contributionCount"],
                    "level": day["contributionLevel"],
                    "color": day["color"],
                    "weekday": day["weekday"],
                }
            )
        weeks.append({"first_day": week["firstDay"], "days": days})

    return {
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "username": USERNAME,
        "total_contributions": calendar.get("totalContributions", 0),
        "status": "ok",
        "reason": "",
        "range": {
            "weeks": WEEKS,
            "from": start.isoformat(),
            "to": end.isoformat(),
        },
        "weeks": weeks,
    }


def fetch_payload() -> dict:
    end = iso_today()
    start = end - timedelta(days=WEEKS * 7 - 1)

    query = """
    query($login: String!, $from: DateTime!, $to: DateTime!) {
      user(login: $login) {
        contributionsCollection(from: $from, to: $to) {
          contributionCalendar {
            totalContributions
            weeks {
              firstDay
              contributionDays {
                color
                contributionCount
                contributionLevel
                date
                weekday
              }
            }
          }
        }
      }
    }
    """

    body = json.dumps(
        {
            "query": query,
            "variables": {
                "login": USERNAME,
                "from": f"{start.isoformat()}T00:00:00Z",
                "to": f"{end.isoformat()}T23:59:59Z",
            },
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        "https://api.github.com/graphql",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "arden-blog-github-heatmap-fetcher",
        },
    )

    with urllib.request.urlopen(req, timeout=20) as response:
        payload = json.loads(response.read().decode("utf-8"))

    if payload.get("errors"):
        raise RuntimeError(payload["errors"][0].get("message", "Unknown GraphQL error"))

    user = payload.get("data", {}).get("user")
    if not user:
        raise RuntimeError(f"GitHub user '{USERNAME}' was not found or returned no contribution data.")

    calendar = user["contributionsCollection"]["contributionCalendar"]
    return build_payload(calendar, start, end)


def main() -> int:
    if not TOKEN:
        write_payload(fallback_payload("Missing CONTRIB_TOKEN; using fallback contribution data."))
        print("warning: CONTRIB_TOKEN is missing; wrote fallback contribution data.", file=sys.stderr)
        return 0

    try:
        payload = fetch_payload()
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, RuntimeError, KeyError) as exc:
        write_payload(fallback_payload(f"GitHub contribution fetch failed: {exc}"))
        print(f"warning: failed to fetch GitHub contribution data: {exc}", file=sys.stderr)
        return 0

    write_payload(payload)
    print(
        f"Fetched GitHub contribution data for {USERNAME}: "
        f"{payload['total_contributions']} contributions across {len(payload['weeks'])} weeks."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
