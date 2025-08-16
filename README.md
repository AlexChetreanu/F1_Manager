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

The API exposes two endpoints:

* `/sessions` – list available session keys.
* `/events` – retrieve raw event rows filtered by `session_key`, optional `endpoint`,
  and an optional `limit` (default 100).
