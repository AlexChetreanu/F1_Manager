# Strategy Bot Runbook

## Commands

```bash
# Start queue worker
php artisan queue:work

# Populate cache for meeting 1262
php artisan strategy:run 1262

# Run Python directly (same args as job)
OF1_BASE=https://api.openf1.org/v1 OF1_DEBUG=1 \
python app/Services/StrategyBot/strategy_bot_openf1.py --meeting-key 1262 --all
```

## Test endpoint

```bash
curl -i http://127.0.0.1:8000/api/historical/meeting/1262/strategy
# 200 with JSON after job writes to cache
# 202 with {"status":"queued"} on miss (auto-dispatch)
```
*Use `127.0.0.1` instead of `.local` to avoid IPv6 resolution issues on iOS simulators.*

## Verifications

- `storage/logs/laravel.log` contains process command and env.
- `php artisan tinker --execute="cache('strategy_suggestions_1262')"` returns array/JSON.
- If `KeyError: 'session_type'`, confirm `_normalize_sessions()` runs and upstream data.
- JSON invalid → log "Invalid JSON from bot", run script standalone and capture stdout.
- Connection refused → ensure Laravel listening on `127.0.0.1:8000`.
- Python path wrong → set `STRATEGY_BOT_PYTHON` correctly and reinstall dependencies.

## Acceptance Criteria

- `php artisan strategy:run 1262` stores cache key `strategy_suggestions_1262`.
- `GET /api/historical/meeting/1262/strategy` returns 200 JSON after population and 202 queued on miss.
- Job and manual runs share `OF1_BASE` and avoid `KeyError` due to normalization.
- Logs include process command and request statuses when `OF1_DEBUG=1`.
