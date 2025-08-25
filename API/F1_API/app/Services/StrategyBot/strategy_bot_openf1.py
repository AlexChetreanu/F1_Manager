# file: strategy_bot_openf1.py
import math, time, json, sys, os
from dataclasses import dataclass
from typing import Dict, List, Optional
from datetime import timedelta

import requests
import pandas as pd
import numpy as np

try:
    from sklearn.ensemble import GradientBoostingClassifier  # pregătit pt extindere ML
except Exception:
    GradientBoostingClassifier = None

# ========================= Config =========================
BASE = os.getenv("OF1_BASE", "https://api.openf1.org/v1")
UA = {"User-Agent": "F1-StrategyBot/2025", "Accept": "application/json"}
DEBUG = os.getenv("OF1_DEBUG", "0") == "1"

_last_call = 0.0  # max 1 req/sec global

def _dbg(msg: str):
    if DEBUG:
        print(f"[DEBUG] {msg}", file=sys.stderr)

# ========================= Helpers =========================
def _http_get(endpoint: str, **params):
    """
    Un singur request pe secundă, fără 'limit'.
    """
    global _last_call
    wait = 1.0 - (time.monotonic() - _last_call)
    if wait > 0:
        time.sleep(wait)

    url = f"{BASE}/{endpoint}"
    try:
        r = requests.get(url, params=params, headers=UA, timeout=30)
    except requests.RequestException as e:
        _last_call = time.monotonic()
        if DEBUG:
            _dbg(f"GET {url} failed: {e}")
        raise
    _last_call = time.monotonic()
    if DEBUG:
        _dbg(f"GET {r.url} -> {r.status_code}")
    if r.status_code >= 400 and DEBUG:
        _dbg(r.text[:200])
    r.raise_for_status()

    txt = r.text.strip()
    if txt == "":
        return []
    try:
        return r.json()
    except Exception:
        return []

def _to_dt(s):
    return pd.to_datetime(s, utc=True, errors="coerce")

def _isoz(ts) -> str:
    return _to_dt(ts).strftime("%Y-%m-%dT%H:%M:%SZ")

def _nzint(x, default=0):
    """int sigur: NaN/None/etc -> default"""
    try:
        return default if pd.isna(x) else int(x)
    except Exception:
        return default

def _coerce_driver_number(df: pd.DataFrame) -> pd.DataFrame:
    if df is not None and not df.empty and "driver_number" in df.columns:
        df["driver_number"] = pd.to_numeric(df["driver_number"], errors="coerce").astype("Int64")
    return df

def _normalize_sessions(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df
    df = df.rename(columns={
        "type": "session_type",
        "name": "session_name",
        "start_time": "date_start",
        "end_time": "date_end",
        "startDate": "date_start",
        "endDate": "date_end",
    })
    if "session_type" not in df.columns and "session_name" in df.columns:
        df["session_type"] = df["session_name"]
    return df

def _normalize_meetings(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df
    df = df.rename(columns={
        "start_time": "date_start",
        "startDate": "date_start",
    })
    return df

def get_df(endpoint: str, **params) -> pd.DataFrame:
    data = _http_get(endpoint, **params)
    df = pd.DataFrame(data) if data else pd.DataFrame()
    # uniformizează cheile de merge & câteva câmpuri numerice
    df = _coerce_driver_number(df)
    for col in ("position", "gap_to_leader", "interval", "lap_number"):
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df
def _parse_tplus(s: str) -> timedelta:
    s = (s or "").strip()
    parts = s.split(":")
    if len(parts) == 2:
        h_str, m_str = parts
        sec_str = "0"
    elif len(parts) == 3:
        h_str, m_str, sec_str = parts
    else:
        raise ValueError("Format tplus invalid. Folosește HH:MM sau HH:MM:SS")
    return timedelta(hours=int(h_str), minutes=int(m_str), seconds=int(sec_str))

# ========================= API wrappers (fără limit=) =========================
def meetings_by_year(year: int) -> pd.DataFrame:
    df = get_df("meetings", year=int(year))
    if df.empty:
        df = get_df("meetings", **{
            "date_start>=": f"{year}-01-01T00:00:00Z",
            "date_end<=":   f"{year}-12-31T23:59:59Z"
        })
    return _normalize_meetings(df)

def sessions_by_year(year: int) -> pd.DataFrame:
    df = get_df("sessions", year=int(year), session_type="Race")
    if df.empty:
        df = get_df("sessions", **{
            "date_start>=": f"{year}-01-01T00:00:00Z",
            "date_end<=":   f"{year}-12-31T23:59:59Z",
            "session_type": "Race"
        })
    return _normalize_sessions(df)

def sessions_for_meeting(meeting_key: int) -> pd.DataFrame:
    return _normalize_sessions(get_df("sessions", meeting_key=int(meeting_key)))

def drivers_for_session(session_key: int) -> pd.DataFrame:
    return get_df("drivers", session_key=int(session_key))

def _fallback_time_filter(df: pd.DataFrame, col: str, date_start, date_end) -> pd.DataFrame:
    if df.empty: return df
    if col not in df.columns: return df
    df = df.copy()
    df[col] = _to_dt(df[col])
    lo = _to_dt(date_start) if date_start else df[col].min()
    hi = _to_dt(date_end)   if date_end   else df[col].max()
    return df[(df[col] >= lo) & (df[col] <= hi)]

def intervals_for_session(session_key: int, date_start=None, date_end=None) -> pd.DataFrame:
    params = {"session_key": int(session_key)}
    if date_start: params["date>="] = date_start if isinstance(date_start, str) else _isoz(date_start)
    if date_end:   params["date<="] = date_end if isinstance(date_end, str) else _isoz(date_end)
    df = get_df("intervals", **params)
    if df.empty and (date_start or date_end):
        df = get_df("intervals", session_key=int(session_key))
        df = _fallback_time_filter(df, "date", date_start, date_end)
    return df

def positions_for_session(session_key: int, date_start=None, date_end=None) -> pd.DataFrame:
    params = {"session_key": int(session_key)}
    if date_start: params["date>="] = date_start if isinstance(date_start, str) else _isoz(date_start)
    if date_end:   params["date<="] = date_end if isinstance(date_end, str) else _isoz(date_end)
    df = get_df("position", **params)
    if df.empty and (date_start or date_end):
        df = get_df("position", session_key=int(session_key))
        df = _fallback_time_filter(df, "date", date_start, date_end)
    return df

def laps_for_session(session_key: int, date_start=None, date_end=None) -> pd.DataFrame:
    params = {"session_key": int(session_key)}
    if date_start: params["date>="] = date_start if isinstance(date_start, str) else _isoz(date_start)
    if date_end:   params["date<="] = date_end if isinstance(date_end, str) else _isoz(date_end)
    df = get_df("laps", **params)
    if df.empty and (date_start or date_end):
        df = get_df("laps", session_key=int(session_key))
        df = _fallback_time_filter(df, "date_start", date_start, date_end)
    return df

def stints_for_session(session_key: int) -> pd.DataFrame:
    return get_df("stints", session_key=int(session_key))

def pit_for_session(session_key: int) -> pd.DataFrame:
    return get_df("pit", session_key=int(session_key))

def weather_for_session(session_key: int) -> pd.DataFrame:
    return get_df("weather", session_key=int(session_key))

def race_control_for_session(session_key: int) -> pd.DataFrame:
    return get_df("race_control", session_key=int(session_key))

# ========================= Meta & discovery =========================
@dataclass
class SessionMeta:
    meeting_key: int
    session_key: int
    session_type: str
    session_name: str
    circuit_key: int
    date_start: pd.Timestamp
    date_end: pd.Timestamp

def iter_year_races(year: int) -> List[SessionMeta]:
    out: List[SessionMeta] = []
    meets = meetings_by_year(year)
    if meets.empty or 'date_start' not in meets.columns or meets['date_start'].isna().all():
        _dbg("meetings_by_year empty; trying sessions_by_year")
        sess = sessions_by_year(year)
        if sess.empty:
            _dbg("sessions_by_year empty; trying session_key=latest")
            latest = _normalize_sessions(get_df("sessions", session_key="latest"))
            if latest.empty:
                return out
            r = latest.iloc[0]
            out.append(SessionMeta(
                meeting_key=int(r["meeting_key"]),
                session_key=int(r["session_key"]),
                session_type=str(r.get("session_type","")),
                session_name=str(r.get("session_name","")),
                circuit_key=int(r.get("circuit_key",-1)),
                date_start=_to_dt(r["date_start"]),
                date_end=_to_dt(r.get("date_end"))
            ))
            return out

        for _, r in sess.sort_values("date_start").iterrows():
            out.append(SessionMeta(
                meeting_key=int(r["meeting_key"]),
                session_key=int(r["session_key"]),
                session_type=str(r.get("session_type","Race")),
                session_name=str(r.get("session_name","Race")),
                circuit_key=int(r.get("circuit_key",-1)),
                date_start=_to_dt(r["date_start"]),
                date_end=_to_dt(r.get("date_end"))
            ))
        return out

    for _, m in meets.sort_values("date_start").iterrows():
        mk = int(m["meeting_key"])
        s = sessions_for_meeting(mk)
        if s.empty:
            continue
        races = s[s["session_type"] == "Race"].sort_values("date_start")
        for _, r in races.iterrows():
            out.append(SessionMeta(
                meeting_key=mk,
                session_key=int(r["session_key"]),
                session_type=str(r.get("session_type","Race")),
                session_name=str(r.get("session_name","Race")),
                circuit_key=int(r.get("circuit_key",-1)),
                date_start=_to_dt(r["date_start"]),
                date_end=_to_dt(r.get("date_end"))
            ))
    return out

# ========================= Detect actual start =========================
def detect_actual_start(session_key: int, scheduled_start: Optional[pd.Timestamp]) -> pd.Timestamp:
    """
    Start REAL: GREEN/START din race_control, apoi cel mai devreme lap1 din laps,
    apoi cel mai vechi sample din position, altfel startul oficial.
    """
    candidates: List[pd.Timestamp] = []

    rc = race_control_for_session(session_key)
    if not rc.empty and "date" in rc.columns:
        rc["date"] = _to_dt(rc["date"])
        msg = rc.get("message")
        flag = rc.get("flag")
        cat  = rc.get("category")

        mask = pd.Series(False, index=rc.index)
        if flag is not None:
            mask = mask | rc["flag"].astype(str).str.upper().str.contains("GREEN", na=False)
        if msg is not None:
            mask = mask | rc["message"].astype(str).str.upper().str.contains("START|GREEN FLAG|RACE START", na=False)
        if cat is not None:
            mask = mask | rc["category"].astype(str).str.upper().str.contains("SESSIONSTART|START", na=False)

        dt = rc.loc[mask, "date"].min()
        if pd.notna(dt):
            candidates.append(dt)

    laps0 = laps_for_session(session_key)
    if not laps0.empty and "date_start" in laps0.columns:
        laps0["date_start"] = _to_dt(laps0["date_start"])
        if "lap_number" in laps0.columns:
            lap1 = laps0[pd.to_numeric(laps0["lap_number"], errors="coerce") == 1]
            dt = lap1["date_start"].min() if not lap1.empty else laps0["date_start"].min()
        else:
            dt = laps0["date_start"].min()
        if pd.notna(dt):
            candidates.append(dt)

    pos0 = positions_for_session(session_key)
    if not pos0.empty and "date" in pos0.columns:
        pos0["date"] = _to_dt(pos0["date"])
        dt = pos0["date"].min()
        if pd.notna(dt):
            candidates.append(dt)

    if candidates:
        actual = min([c for c in candidates if pd.notna(c)], default=scheduled_start)
        if DEBUG:
            _dbg(f"Actual start detected: {actual} (scheduled: {scheduled_start})")
        return actual
    return scheduled_start

def minute_from_lap(session_key: int, lap_no: int) -> Optional[pd.Timestamp]:
    laps = laps_for_session(session_key)
    if laps.empty or "date_start" not in laps.columns or "lap_number" not in laps.columns:
        return None
    laps["date_start"] = _to_dt(laps["date_start"])
    mask = pd.to_numeric(laps["lap_number"], errors="coerce") == int(lap_no)
    if not mask.any():
        return None
    t = laps.loc[mask, "date_start"].min()
    return t.floor("min") if pd.notna(t) else None

# ========================= Time grid & resampling =========================
def minute_grid(date_start: pd.Timestamp, date_end: Optional[pd.Timestamp]) -> pd.DatetimeIndex:
    if pd.isna(date_start):
        raise ValueError("date_start is NaT")
    horizon = date_start + pd.Timedelta(hours=3)
    if pd.isna(date_end) or date_end > horizon:
        date_end = horizon
    return pd.date_range(start=date_start.floor("min"), end=date_end.floor("min"), freq="min")

def _resample_last(df: pd.DataFrame, on_col="date", by=["driver_number"], value_cols=None,
                   grid: Optional[pd.DatetimeIndex]=None, drivers: Optional[List[int]]=None) -> pd.DataFrame:
    """
    Forward-fill pe minut. Dacă df e gol sau lipsesc cheile 'by', întoarce scheletul (minute × driver_number).
    """
    def _skeleton():
        if grid is None:
            return pd.DataFrame()
        if drivers and len(drivers) > 0:
            sk = pd.MultiIndex.from_product([grid, drivers], names=["minute","driver_number"]).to_frame(index=False)
            sk["driver_number"] = pd.to_numeric(sk["driver_number"], errors="coerce").astype("Int64")
            return sk
        return pd.DataFrame({"minute": grid})

    if df.empty:
        return _skeleton()

    tmp = df.copy()
    tmp[on_col] = _to_dt(tmp[on_col])
    for col in by:
        if col not in tmp.columns:
            return _skeleton()

    tmp = tmp.sort_values([*by, on_col])

    out_list = []
    for dn, g in tmp.groupby(by):
        g = g.set_index(on_col)
        cols = value_cols if value_cols is not None else [c for c in g.columns if c not in by]
        g = g[cols].resample("min").last().ffill()
        if isinstance(dn, tuple):
            for key, val in zip(by, dn):
                g[key] = val
        else:
            g[by[0]] = dn
        out_list.append(g)

    out = pd.concat(out_list).reset_index().rename(columns={on_col: "minute"})
    if "driver_number" in out.columns:
        out["driver_number"] = pd.to_numeric(out["driver_number"], errors="coerce").astype("Int64")

    if grid is not None and drivers and len(drivers) > 0:
        full_idx = pd.MultiIndex.from_product([grid, drivers], names=["minute","driver_number"])
        out = (out.set_index(["minute","driver_number"])
                 .reindex(full_idx)
                 .groupby(level=1).ffill()
                 .reset_index())
        out["driver_number"] = pd.to_numeric(out["driver_number"], errors="coerce").astype("Int64")
    elif grid is not None:
        out = (out.set_index("minute").reindex(grid)
                 .groupby(by, dropna=False).ffill()
                 .reset_index())

    return out

# ========================= Builder (3h de la start) =========================
def build_session_minute_frame(meta: SessionMeta):
    # detectează startul real
    actual_start = detect_actual_start(meta.session_key, meta.date_start)

    # fereastră de colectare cu PAD ±10 min, dar gridul rămâne fix 3h
    WINDOW_PAD = pd.Timedelta(minutes=10)
    date_from = _isoz(actual_start - WINDOW_PAD)
    date_to   = _isoz(actual_start + pd.Timedelta(hours=3) + WINDOW_PAD)
    grid = minute_grid(actual_start, meta.date_end)

    # schelet: lista de piloți din sesiune
    drv = drivers_for_session(meta.session_key)
    drivers = sorted(pd.to_numeric(drv["driver_number"], errors="coerce").dropna().astype(int).unique().tolist()) \
              if not drv.empty and "driver_number" in drv.columns else []
    driver_meta = {}
    if not drv.empty:
        for _, row in drv.iterrows():
            dn = _nzint(row.get("driver_number"))
            driver_meta[dn] = {
                "name": row.get("full_name") or row.get("broadcast_name") or row.get("name_acronym") or f"#{dn}",
                "acronym": row.get("name_acronym"),
                "team": row.get("team_name") or row.get("team") or None
            }

    # Intervals & Position
    intervals = intervals_for_session(meta.session_key, date_start=date_from, date_end=date_to)
    inter_m = _resample_last(intervals, "date", ["driver_number"],
                             ["gap_to_leader","interval","meeting_key","session_key"],
                             grid=grid, drivers=drivers)

    pos = positions_for_session(meta.session_key, date_start=date_from, date_end=date_to)
    pos_m = _resample_last(pos, "date", ["driver_number"],
                           ["position","meeting_key","session_key"],
                           grid=grid, drivers=drivers)

    # Weather (global)
    w = weather_for_session(meta.session_key)
    if not w.empty:
        w["date"] = _to_dt(w["date"])
        w = (w.sort_values("date").set_index("date").resample("min").last().ffill()
               .reset_index().rename(columns={"date":"minute"}))
    else:
        w = pd.DataFrame({"minute": grid})

    # Race Control
    rc = race_control_for_session(meta.session_key)
    if not rc.empty:
        rc["date"] = _to_dt(rc["date"])
        rc["is_sc"]    = (rc["category"]=="SafetyCar").astype(int)
        rc["is_vsc"]   = (rc["category"]=="VirtualSafetyCar").astype(int)
        rc["is_red"]   = rc.get("flag","").eq("RED").astype(int) if "flag" in rc.columns else 0
        rc["is_green"] = rc.get("flag","").eq("GREEN").astype(int) if "flag" in rc.columns else 0
        rc_m = (rc.sort_values("date").set_index("date")[["is_sc","is_vsc","is_red","is_green"]]
                  .resample("min").max().fillna(0).astype(int).reset_index()
                  .rename(columns={"date":"minute"}))
    else:
        rc_m = pd.DataFrame({"minute": grid, "is_sc":0, "is_vsc":0, "is_red":0, "is_green":0})

    # Laps
    laps = laps_for_session(meta.session_key, date_start=date_from, date_end=date_to)
    if not laps.empty:
        laps["date_start"] = _to_dt(laps["date_start"])
        dur_col = next((c for c in ["lap_duration","duration","lap_time","time"] if c in laps.columns), None)
        laps["lap_duration_s"] = pd.to_numeric(laps[dur_col], errors="coerce") if dur_col else np.nan
        is_out_col = "is_pit_out_lap" if "is_pit_out_lap" in laps.columns else None
        laps["is_outlap"] = laps[is_out_col].fillna(False).astype(bool) if is_out_col else False
    else:
        laps = pd.DataFrame(columns=["driver_number","lap_number","lap_duration_s","date_start","is_outlap"])

    # Stints → compound & tyre_age (folosește și tyre_age_at_start dacă există)
    st = stints_for_session(meta.session_key)
    if not st.empty and not laps.empty and "lap_number" in laps.columns:
        s = st.rename(columns=str.lower)
        needed = {"driver_number","compound","lap_start","lap_end"}
        if needed.issubset(set(s.columns)):
            if "tyre_age_at_start" not in s.columns:
                s["tyre_age_at_start"] = 0
            rows = []
            for _, row in s.dropna(subset=["driver_number","lap_start","lap_end"]).iterrows():
                dn = int(row["driver_number"])
                comp = str(row["compound"])
                L0, L1 = int(row["lap_start"]), int(row["lap_end"])
                age0 = int(row.get("tyre_age_at_start") or 0)
                for L in range(L0, L1+1):
                    rows.append((dn, L, comp, age0 + (L - L0)))
            stint_map = pd.DataFrame(rows, columns=["driver_number","lap_number","compound","tyre_age_laps"])
            stint_map["driver_number"] = pd.to_numeric(stint_map["driver_number"], errors="coerce").astype("Int64")
            laps = laps.merge(stint_map, on=["driver_number","lap_number"], how="left")

    # Pit → pit_loss mediana
    pit = pit_for_session(meta.session_key)
    if not pit.empty:
        dur_cols = [c for c in pit.columns if any(k in c.lower() for k in ["dur","time","loss"])]
        if dur_cols:
            pit["pit_loss_est"] = pd.to_numeric(pit[dur_cols[0]], errors="coerce")
            pit_loss_base = float(np.nanmedian(pit["pit_loss_est"]))
            if not (5.0 <= pit_loss_base <= 40.0):
                pit_loss_base = 20.0
        else:
            pit_loss_base = 20.0
    else:
        pit_loss_base = 20.0

    # Pace curat (fără SC/VSC/out-lap)
    if not laps.empty:
        laps["minute"] = laps["date_start"].dt.floor("min")
        laps = laps.merge(rc_m, on="minute", how="left")
        laps["is_neutralized"] = ((laps["is_sc"]==1)|(laps["is_vsc"]==1)|(laps["is_red"]==1)).fillna(False)
        clean = laps[~laps["is_outlap"] & ~laps["is_neutralized"] & laps["lap_duration_s"].notna()].copy()
        if not clean.empty:
            clean["pace_ma3"] = clean.groupby("driver_number")["lap_duration_s"].transform(
                lambda s: s.rolling(3, min_periods=1).median()
            )
            last_pace = (clean.sort_values(["driver_number","lap_number"])
                             .groupby("driver_number").tail(1)[["driver_number","pace_ma3","lap_number","compound","tyre_age_laps"]])
            last_pace["driver_number"] = pd.to_numeric(last_pace["driver_number"], errors="coerce").astype("Int64")
        else:
            last_pace = pd.DataFrame(columns=["driver_number","pace_ma3","lap_number","compound","tyre_age_laps"])
    else:
        last_pace = pd.DataFrame(columns=["driver_number","pace_ma3","lap_number","compound","tyre_age_laps"])

    # Schelet base minute × driver
    if drivers:
        base = pd.MultiIndex.from_product([grid, drivers], names=["minute","driver_number"]).to_frame(index=False)
        base["driver_number"] = pd.to_numeric(base["driver_number"], errors="coerce").astype("Int64")
    else:
        base = pd.DataFrame({"minute": grid})

    # Join-uri pe schelet
    df = base.merge(pos_m, on=["minute","driver_number"] if "driver_number" in base.columns else ["minute"], how="left")
    df = df.merge(inter_m, on=["minute","driver_number"] if "driver_number" in base.columns else ["minute"], how="left")
    df = df.merge(last_pace, on="driver_number", how="left") if "driver_number" in df.columns else df
    df = df.merge(rc_m, on="minute", how="left")
    df = df.merge(w, on="minute", how="left", suffixes=("","_w"))

    # -------- Normalizează tipuri & NaN-safe --------
    for c in ["is_sc", "is_vsc", "is_red"]:
        if c not in df.columns: df[c] = 0
        df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0).astype(int)

    df["gap_ahead_s"]  = pd.to_numeric(df.get("interval"), errors="coerce")
    df["gap_leader_s"] = pd.to_numeric(df.get("gap_to_leader"), errors="coerce")
    df["position"]     = pd.to_numeric(df.get("position"), errors="coerce")

    df["pace_ma3"] = pd.to_numeric(df.get("pace_ma3"), errors="coerce")
    if "driver_number" in df.columns:
        med = df.groupby("driver_number")["gap_leader_s"].transform("median")
        df["pace_ma3"] = df["pace_ma3"].fillna(med).astype(float)
    else:
        df["pace_ma3"] = df["pace_ma3"].astype(float)

    # is_green_effective + pit_loss ajustat
    df["is_green_effective"] = ((df["is_sc"]==0) & (df["is_vsc"]==0) & (df["is_red"]==0)).astype(int)
    df["pit_loss_s"] = pit_loss_base * np.where(df["is_sc"]==1, 0.65, np.where(df["is_vsc"]==1, 0.75, 1.0))

    # -------- Heuristică under/overcut (fără sentinel) --------
    OUTLAP_PENALTY = 2.5
    NEW_TYRE_DELTA = 0.35
    FRONT_OLD_SLOWDOWN = 0.20
    WARMUP_LOSS = 0.15

    df["front_old_pace"] = df["pace_ma3"] + FRONT_OLD_SLOWDOWN
    df["our_new_pace"]   = (df["pace_ma3"] - NEW_TYRE_DELTA).clip(lower=0.0)
    df["gain_2laps"]     = 2.0*(df["front_old_pace"] - df["our_new_pace"]) - OUTLAP_PENALTY - df["pit_loss_s"]

    have_gap  = df["gap_ahead_s"].notna()
    have_pace = df["pace_ma3"].notna()

    df["undercut_score_rule"] = np.where(
        have_gap & have_pace,
        df["gain_2laps"] - df["gap_ahead_s"] - 0.5,
        np.nan
    )
    df["overcut_gain_1lap"] = (OUTLAP_PENALTY + WARMUP_LOSS) - FRONT_OLD_SLOWDOWN
    df["overcut_score_rule"] = np.where(
        have_gap,
        df["overcut_gain_1lap"] - df["gap_ahead_s"] - 0.5,
        np.nan
    )

    # estimare tururi
    if not laps.empty and "lap_number" in laps.columns:
        df["race_laps_est"] = pd.to_numeric(laps["lap_number"], errors="coerce").max()
    else:
        df["race_laps_est"] = np.nan

    # meta piloți
    if driver_meta and "driver_number" in df.columns:
        meta_df = pd.DataFrame([
            {"driver_number": int(dn), "driver_name": v["name"], "driver_team": v["team"], "driver_acr": v["acronym"]}
            for dn, v in driver_meta.items()
        ])
        meta_df["driver_number"] = pd.to_numeric(meta_df["driver_number"], errors="coerce").astype("Int64")
        df = df.merge(meta_df, on="driver_number", how="left")

    return df, pit_loss_base, actual_start

# ========================= Decision (per pilot) =========================
def decide_from_row(r: pd.Series, driver_number: int) -> Dict:
    score    = float(r.get("undercut_score_rule")) if pd.notna(r.get("undercut_score_rule")) else np.nan
    over_s   = float(r.get("overcut_score_rule")) if pd.notna(r.get("overcut_score_rule")) else np.nan
    gap      = r.get("gap_ahead_s", np.nan)
    pit_loss = r.get("pit_loss_s", np.nan)

    is_red    = bool(r.get("is_red", 0) == 1)
    is_sc     = bool(r.get("is_sc", 0)  == 1)
    is_vsc    = bool(r.get("is_vsc", 0) == 1)
    is_green  = bool(r.get("is_green_effective", 0) == 1)

    if is_red:
        return {"advice":"NO_ACTION","why":"Red flag – pit tratat separat."}

    if is_sc or is_vsc:
        if (not np.isnan(score) and score>-2.0) or (not np.isnan(gap) and not np.isnan(pit_loss) and gap < 0.5*pit_loss):
            return {"advice":"BOX_NOW_SC","why":"Pit loss redus sub SC/VSC."}
        return {"advice":"HOLD_SC","why":"Sub SC/VSC dar fereastra nu e optimă încă."}

    if is_green:
        if (not np.isnan(score) and score>0.0) and (not np.isnan(gap) and gap<12.0):
            return {"advice":"BOX_NOW_UNDERCUT","why":f"UndercutScore={score:.2f} > 0, gap mic."}
        if (not np.isnan(score) and score>-0.5) and (not np.isnan(gap) and not np.isnan(pit_loss) and gap < 0.7*pit_loss):
            return {"advice":"BOX_SOON_1LAP","why":"Gap < 0.7*PitLoss; fereastră apropiată."}
        if (not np.isnan(over_s) and over_s>0.0) and (pd.notna(r.get("gap_leader_s")) and r["gap_leader_s"]>pit_loss):
            return {"advice":"STAY_OUT_OVERCUT","why":f"OvercutScore={over_s:.2f} > 0 și aer curat."}

    why = []
    if np.isnan(score) or score <= 0:  why.append("Câștig undercut sub gap.")
    if not np.isnan(gap) and not np.isnan(pit_loss) and gap >= 0.7*pit_loss: why.append("Gap prea mare vs pit loss.")
    if not why: why.append("Context nefavorabil acum.")
    return {"advice":"STAY_OUT","why":" ".join(why)}

# ========================= Snapshot for ALL drivers =========================
def snapshot_minute(df_minute: pd.DataFrame, minute: pd.Timestamp) -> pd.DataFrame:
    snap = df_minute[df_minute["minute"]==minute].copy()
    if snap.empty:
        return snap
    if "position" in snap.columns and "driver_number" in snap.columns:
        front = snap[["driver_number","position"]].copy()
        pos2drv = dict(zip(front["position"], front["driver_number"]))
        def _ahead(row):
            p = row["position"]
            if pd.isna(p) or p<=1: return np.nan
            return pos2drv.get(p-1, np.nan)
        snap["target_driver"] = snap.apply(_ahead, axis=1)
    else:
        snap["target_driver"] = np.nan
    return snap

def suggest_all_now(df_minute: pd.DataFrame, minute: pd.Timestamp) -> List[Dict]:
    snap = snapshot_minute(df_minute, minute)
    if snap.empty:
        return []
    out = []
    for _, r in snap.sort_values("position").iterrows():
        dn = _nzint(r.get("driver_number"), -1)
        decision = decide_from_row(r, dn)
        out.append({
            "driver_number": None if dn<0 else dn,
            "driver_name": r.get("driver_name"),
            "team": r.get("driver_team"),
            "position": None if pd.isna(r.get("position")) else int(r["position"]),
            "target_driver": None if pd.isna(r.get("target_driver")) else int(r["target_driver"]),
            "gap_ahead": None if pd.isna(r.get("gap_ahead_s")) else float(r["gap_ahead_s"]),
            "gap_leader": None if pd.isna(r.get("gap_leader_s")) else float(r["gap_leader_s"]),
            "compound": r.get("compound"),
            "tyre_age_laps": None if pd.isna(r.get("tyre_age_laps")) else int(r["tyre_age_laps"]),
            "undercut_score": None if pd.isna(r.get("undercut_score_rule")) else round(float(r["undercut_score_rule"]),2),
            "overcut_score": None if pd.isna(r.get("overcut_score_rule")) else round(float(r["overcut_score_rule"]),2),
            "pit_loss": None if pd.isna(r.get("pit_loss_s")) else float(r["pit_loss_s"]),
            "advice": decision["advice"],
            "why": decision["why"],
            "flags": {"SC": _nzint(r.get("is_sc")), "VSC": _nzint(r.get("is_vsc")), "RED": _nzint(r.get("is_red"))}
        })
    return out

# ========================= Year runner (summary) =========================
def run_year(year: int) -> pd.DataFrame:
    metas = iter_year_races(year)
    rows = []
    for meta in metas:
        try:
            df_min, pit_loss, actual_start = build_session_minute_frame(meta)
            if df_min.empty:
                rows.append({"year":year,"meeting_key":meta.meeting_key,"session_key":meta.session_key,
                             "session_name":meta.session_name,"circuit_key":meta.circuit_key,"error":"Minute frame gol"})
                continue
            last_min = df_min["minute"].max()
            sug = suggest_all_now(df_min, last_min)
            rows.append({
                "year": year, "meeting_key": meta.meeting_key, "session_key": meta.session_key,
                "session_name": meta.session_name, "circuit_key": meta.circuit_key,
                "actual_start": str(actual_start),
                "last_minute": str(last_min), "pit_loss_base": pit_loss,
                "suggestions": sug
            })
        except Exception as e:
            rows.append({"year":year,"meeting_key":meta.meeting_key,"session_key":meta.session_key,
                         "session_name":meta.session_name,"circuit_key":meta.circuit_key,"error":str(e)})
    return pd.DataFrame(rows)

# ========================= CLI =========================
if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser("F1 Strategy Bot (OpenF1)")
    p.add_argument("--year", type=int, default=2025, help="An analizat (meeting-first).")
    p.add_argument("--meeting-key", "--meeting_key", dest="meeting_key", type=int,
                   help="Rulează pe meeting-ul dat (Race).")
    p.add_argument("--session-key", type=str, help="Race session_key (acceptă și 'latest').")
    p.add_argument("--all", action="store_true", help="Printează recomandări pentru TOȚI piloții.")
    p.add_argument("--minute", type=str, help="Timp absolut (UTC) ex. 2024-05-05T20:30:00Z.")
    p.add_argument("--tplus", type=str, help="Timp relativ la startul real, HH:MM[:SS], ex 00:35:00.")
    p.add_argument("--lap", type=int, help="Alege începutul turului L (după lider).")
    p.add_argument("--watch", action="store_true", help="Recalculează periodic (live).")
    p.add_argument("--poll", type=int, default=12, help="Secunde între rulări în watch (>=9 recomandat).")
    p.add_argument("--summary-year", action="store_true", help="Sinteză pentru toate cursele din an.")
    args, _ = p.parse_known_args()
    if not args.meeting_key and not args.session_key and not args.summary_year:
        sys.exit("Specify --meeting-key or --session-key")

    # alegem sesiunea
    if args.session_key:
        sess_df = _normalize_sessions(get_df("sessions", session_key=args.session_key))
        if sess_df.empty:
            sys.exit("Sesiune inexistentă.")
        r = sess_df.iloc[0]
    elif args.meeting_key:
        sess = sessions_for_meeting(args.meeting_key)
        if sess.empty:
            sys.exit("Nu găsesc sesiuni pentru meeting_key.")
        race = sess[sess["session_type"] == "Race"].sort_values("date_start").tail(1)
        if race.empty:
            sys.exit("Nu găsesc sesiune Race pentru meeting-ul dat.")
        r = race.iloc[0]
    elif args.summary_year:
        df = run_year(args.year)
        print(df.to_json(orient="records", force_ascii=False, indent=2))
        sys.exit(0)
    else:
        # meeting-first: ultima cursă din an (fallback pe sessions/year, apoi latest)
        r = None
        meets = meetings_by_year(args.year)
        if meets.empty or 'date_start' not in meets.columns or meets['date_start'].isna().all():
            sess_year = sessions_by_year(args.year)
            if not sess_year.empty:
                r = sess_year.sort_values("date_start").tail(1).iloc[0]
            else:
                latest = _normalize_sessions(get_df("sessions", session_key="latest"))
                if latest.empty:
                    sys.exit(f"Nu găsesc curse Race în {args.year}.")
                r = latest.iloc[0]
        else:
            mk = int(meets.sort_values("date_start").iloc[-1]["meeting_key"])
            sess = sessions_for_meeting(mk)
            race = sess[sess["session_type"] == "Race"].sort_values("date_start").tail(1)
            if race.empty:
                sys.exit("Nu găsesc sesiune Race pentru meeting-ul selectat.")
            r = race.iloc[0]

    # meta & build
    meta = SessionMeta(int(r["meeting_key"]), int(r["session_key"]), str(r.get("session_type","Race")),
                       str(r.get("session_name","Race")), int(r.get("circuit_key",-1)),
                       _to_dt(r["date_start"]), _to_dt(r.get("date_end")))
    df, pit_loss, actual_start = build_session_minute_frame(meta)

    # alegerea minutului de analiză
    if args.minute:
        minute = _to_dt(args.minute).floor("min")
    elif args.tplus:
        minute = (actual_start + _parse_tplus(args.tplus)).floor("min")
    elif args.lap:
        m = minute_from_lap(meta.session_key, args.lap)
        minute = m if m is not None else df["minute"].max()
    else:
        minute = df["minute"].max()

    def _emit_all():
        sug_all = suggest_all_now(df, minute)
        print(json.dumps({
            "meeting_key": meta.meeting_key, "session_key": meta.session_key,
            "actual_start": str(actual_start),
            "minute": str(minute), "pit_loss_base": pit_loss,
            "suggestions": sug_all
        }, indent=2, ensure_ascii=False))

    if args.watch:
        poll = max(args.poll, 9)
        while True:
            df, pit_loss, actual_start = build_session_minute_frame(meta)
            if args.minute:
                minute = _to_dt(args.minute).floor("min")
            elif args.tplus:
                minute = (actual_start + _parse_tplus(args.tplus)).floor("min")
            elif args.lap:
                m = minute_from_lap(meta.session_key, args.lap)
                minute = m if m is not None else df["minute"].max()
            else:
                minute = df["minute"].max()

            _emit_all() if args.all else print(json.dumps({
                "meeting_key": meta.meeting_key, "session_key": meta.session_key,
                "actual_start": str(actual_start),
                "minute": str(minute), "pit_loss_base": pit_loss,
                "suggestion": (suggest_all_now(df, minute)[0] if suggest_all_now(df, minute) else None)
            }, indent=2, ensure_ascii=False))
            sys.stdout.flush()
            time.sleep(poll)
    else:
        if args.all:
            _emit_all()
        else:
            sug_list = suggest_all_now(df, minute)
            sug = (sug_list[0] if sug_list else None)
            print(json.dumps({
                "meeting_key": meta.meeting_key, "session_key": meta.session_key,
                "actual_start": str(actual_start),
                "minute": str(minute), "pit_loss_base": pit_loss,
                "suggestion": sug
            }, indent=2, ensure_ascii=False))
