import json
import sqlite3
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

DB_PATH = "openf1.db"

app = FastAPI(title="OpenF1 API")


class RawEvent(BaseModel):
    endpoint: str
    session_key: int
    time_field: str
    time_value: str
    payload: dict


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


@app.get("/sessions")
def list_sessions() -> dict:
    """Return available session keys."""
    conn = get_connection()
    cur = conn.execute("SELECT DISTINCT session_key FROM raw_events ORDER BY session_key")
    sessions = [row[0] for row in cur.fetchall()]
    conn.close()
    return {"sessions": sessions}


@app.get("/events", response_model=List[RawEvent])
def read_events(
    session_key: int,
    endpoint: Optional[str] = None,
    limit: int = 100,
) -> List[RawEvent]:
    """Retrieve raw events for a session.

    Parameters
    ----------
    session_key: int
        Session identifier from the OpenF1 dataset.
    endpoint: str, optional
        Filter results to a specific endpoint, e.g. "car_data".
    limit: int
        Maximum number of rows to return.
    """
    conn = get_connection()
    query = (
        "SELECT endpoint, session_key, time_field, time_value, payload "
        "FROM raw_events WHERE session_key = ?"
    )
    params: List[object] = [session_key]
    if endpoint:
        query += " AND endpoint = ?"
        params.append(endpoint)
    query += " ORDER BY time_value LIMIT ?"
    params.append(limit)
    cur = conn.execute(query, params)
    rows = cur.fetchall()
    conn.close()
    if not rows:
        raise HTTPException(status_code=404, detail="No events found")
    return [
        RawEvent(
            endpoint=row["endpoint"],
            session_key=row["session_key"],
            time_field=row["time_field"],
            time_value=row["time_value"],
            payload=json.loads(row["payload"]),
        )
        for row in rows
    ]


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
