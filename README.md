# Proiect nou

## OpenF1 Python API

This repository now includes a small FastAPI application that serves data from the
`openf1.db` SQLite database. The database can be populated using the
`scripts/openf1_ingest.py` script.

### Running the API

```bash
pip install -r openf1_api/requirements.txt
uvicorn openf1_api.main:app --reload
```

The API exposes endpoints for each table in `openf1.db`. The following paths are
available and mirror the OpenF1 dataset:

`/car_data`, `/drivers`, `/intervals`, `/laps`, `/location`, `/meetings`,
`/overtakes`, `/pit`, `/position`, `/race_control`, `/sessions`, `/session_result`,
`/starting_grid`, `/stints`, `/team_radio`, and `/weather`.

Every endpoint accepts arbitrary query parameters that match column names in the
underlying table for filtering. A `limit` parameter (default `100`) controls the
maximum number of rows returned.
