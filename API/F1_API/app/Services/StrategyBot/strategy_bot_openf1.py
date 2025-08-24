import os, time, json, sys
from typing import List, Dict

import requests
import pandas as pd

BASE = os.getenv('OF1_BASE', 'http://localhost:8000/api/openf1')
UA = {'User-Agent': 'F1-StrategyBot/2025'}
_last = 0.0

def _http_get(endpoint: str, **params):
    global _last
    wait = 1.0 - (time.monotonic() - _last)
    if wait > 0:
        time.sleep(wait)
    url = f"{BASE}/{endpoint}"
    r = requests.get(url, params=params, headers=UA, timeout=30)
    _last = time.monotonic()
    r.raise_for_status()
    data = r.json()
    if isinstance(data, dict) and 'data' in data:
        data = data['data']
    return data

def get_df(endpoint: str, **params) -> pd.DataFrame:
    data = _http_get(endpoint, **params)
    return pd.DataFrame(data)

def build_session_minute_frame(session_key: int) -> pd.DataFrame:
    pos = get_df('position', session_key=session_key)
    drv = get_df('drivers', session_key=session_key)
    if pos.empty or drv.empty:
        return pd.DataFrame()
    pos['minute'] = pd.to_datetime(pos['date']).dt.floor('min')
    df = pos[['minute','driver_number','position']]
    df = df.merge(drv[['driver_number','full_name','team_name']], on='driver_number', how='left')
    return df

def suggest_all_now(session_key: int) -> List[Dict]:
    df = build_session_minute_frame(session_key)
    if df.empty:
        return []
    latest = df[df['minute']==df['minute'].max()]
    out = []
    for _, r in latest.iterrows():
        out.append({
            'driver_number': int(r['driver_number']),
            'driver_name': r.get('full_name'),
            'team': r.get('team_name'),
            'position': int(r['position']) if pd.notna(r['position']) else None,
            'advice': 'STAY_OUT',
            'why': 'Insufficient data for strategy'
        })
    return out

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser('F1 Strategy Bot (simplified)')
    p.add_argument('--session-key', type=int, required=True)
    args = p.parse_args()
    sug = suggest_all_now(args.session_key)
    print(json.dumps({'session_key': args.session_key, 'suggestions': sug}, indent=2))
