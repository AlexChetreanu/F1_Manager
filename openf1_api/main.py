import sqlite3
from typing import Dict, List

from fastapi import FastAPI, HTTPException, Request

DB_PATH = "openf1.db"
ALLOWED_TABLES = {
    "car_data",
    "drivers",
    "intervals",
    "laps",
    "location",
    "meetings",
    "overtakes",
    "pit",
    "position",
    "race_control",
    "sessions",
    "session_result",
    "starting_grid",
    "stints",
    "team_radio",
    "weather",
}

app = FastAPI(title="OpenF1 API")


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def get_columns(conn: sqlite3.Connection, table: str) -> List[str]:
    cur = conn.execute(f"PRAGMA table_info({table})")
    return [row[1] for row in cur.fetchall()]


@app.get("/{endpoint}")
async def read_table(endpoint: str, request: Request, limit: int = 100) -> List[Dict[str, object]]:
    """Generic endpoint returning rows from a table in ``openf1.db``.

    Parameters
    ----------
    endpoint: str
        Name of the table to query. Must be one of the tables from the
        OpenF1 dataset.
    request: Request
        Incoming HTTP request used to read arbitrary query parameters for
        filtering the results.
    limit: int
        Maximum number of rows to return. Defaults to 100.
    """
    if endpoint not in ALLOWED_TABLES:
        raise HTTPException(status_code=404, detail="Unknown endpoint")

    conn = get_connection()
    columns = get_columns(conn, endpoint)

    filters: Dict[str, str] = {k: v for k, v in request.query_params.items() if k != "limit"}
    where_clauses: List[str] = []
    params: List[object] = []
    for key, value in filters.items():
        if key not in columns:
            conn.close()
            raise HTTPException(status_code=400, detail=f"Unknown filter '{key}'")
        where_clauses.append(f"{key} = ?")
        params.append(value)

    query = f"SELECT * FROM {endpoint}"
    if where_clauses:
        query += " WHERE " + " AND ".join(where_clauses)
    query += " LIMIT ?"
    params.append(limit)

    cur = conn.execute(query, params)
    rows = [dict(row) for row in cur.fetchall()]
    conn.close()

    if not rows:
        raise HTTPException(status_code=404, detail="No data found")
    return rows


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
