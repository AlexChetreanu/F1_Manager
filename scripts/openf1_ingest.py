#!/usr/bin/env python3
"""Pull OpenF1 race data into a local SQLite database.

This script mirrors the ingestion pipeline described in the proposal:
* Fetch all 2024 meetings and their Race sessions.
* For each session, pull data from multiple endpoints within the
  [start, start+3h] window using time slicing.
* Results are written to a SQLite database table `raw_events` for later
  normalisation into per-endpoint tables.

The script uses asyncio + aiohttp for concurrent requests and applies a
simple exponential backoff on HTTP 429/5xx responses.
"""

import asyncio
import json
import sqlite3
from datetime import datetime, timedelta
from typing import Dict, Tuple

import aiohttp

BASE_URL = "https://api.openf1.org/v1"
YEAR = 2024
WINDOW_HOURS = 3
CHUNK_MINUTES = 5

# endpoint -> time field
ENDPOINTS: Dict[str, str] = {
    "car_data": "date",
    "intervals": "date",
    "position": "date",
    "laps": "date_start",
    "location": "date",
    "race_control": "date",
    "weather": "date",
    "pit": "date",
    "team_radio": "date",
    "overtakes": "date",
    "session_result": "date",
    "starting_grid": "date",
}

async def fetch_with_retry(session: aiohttp.ClientSession, url: str, params: Dict[str, str], retries: int = 3) -> list:
    delay = 1
    for attempt in range(retries):
        try:
            async with session.get(url, params=params, timeout=30) as resp:
                if resp.status in {429} or resp.status >= 500:
                    raise aiohttp.ClientResponseError(resp.request_info, resp.history, status=resp.status)
                return await resp.json()
        except Exception:
            if attempt == retries - 1:
                raise
            await asyncio.sleep(delay)
            delay *= 2

async def main() -> None:
    conn = sqlite3.connect("openf1.db")
    conn.execute(
        """CREATE TABLE IF NOT EXISTS raw_events (
               endpoint TEXT,
               session_key INTEGER,
               time_field TEXT,
               time_value TEXT,
               payload TEXT
           )"""
    )

    async with aiohttp.ClientSession() as http:
        meetings = await fetch_with_retry(http, f"{BASE_URL}/meetings", {"year": YEAR})
        for meeting in meetings:
            mk = meeting.get("meeting_key")
            sessions = await fetch_with_retry(
                http,
                f"{BASE_URL}/sessions",
                {"meeting_key": mk, "session_type": "Race"},
            )
            for sess in sessions:
                sk = sess.get("session_key")
                ds = sess.get("date_start")
                if not sk or not ds:
                    continue
                start = datetime.fromisoformat(ds.replace("Z", "+00:00"))
                window_end = start + timedelta(hours=WINDOW_HOURS)
                w_start = start
                while w_start < window_end:
                    w_end = min(w_start + timedelta(minutes=CHUNK_MINUTES), window_end)
                    tasks = []
                    ep_meta: Dict[str, Tuple[str, datetime, datetime]] = {}
                    for ep, tf in ENDPOINTS.items():
                        params = {
                            "session_key": sk,
                            f"{tf}>=" : w_start.isoformat(),
                            f"{tf}<=" : w_end.isoformat(),
                        }
                        ep_meta[ep] = (tf, w_start, w_end)
                        tasks.append(fetch_with_retry(http, f"{BASE_URL}/{ep}", params))
                    results = await asyncio.gather(*tasks, return_exceptions=True)
                    for (ep, (tf, _ws, _we)), res in zip(ep_meta.items(), results):
                        if isinstance(res, Exception) or not isinstance(res, list):
                            continue
                        rows = []
                        for item in res:
                            time_val = item.get(tf) or item.get("date")
                            rows.append((ep, sk, tf, time_val, json.dumps(item)))
                        if rows:
                            conn.executemany("INSERT INTO raw_events VALUES (?,?,?,?,?)", rows)
                    conn.commit()
                    w_start = w_end
    conn.close()

if __name__ == "__main__":
    asyncio.run(main())
