# Strategy Bot Runbook

To avoid `Connection refused` errors on `.local` names or IPv6 addresses, use **only IPv4** endpoints.

## Pornirea serverului

```bash
php artisan serve --host 0.0.0.0 --port 8000
```

## Client (doar IPv4)

- Simulator iOS → `http://127.0.0.1:8000`
- iPhone pe LAN → `http://<IP_LAN>:8000` (ex: `http://192.168.1.23:8000`)

## Queue

```bash
php artisan queue:work
php artisan strategy:run 1262
php artisan tinker --execute="dump(cache('strategy_suggestions_1262'))"
```

## Rulează Python identic cu jobul

```bash
OF1_BASE=https://api.openf1.org/v1 OF1_DEBUG=1 \
python app/Services/StrategyBot/strategy_bot_openf1.py --meeting-key 1262 --all
```

## Test endpoint

```bash
curl -i http://127.0.0.1:8000/api/historical/meeting/1262/strategy
# 202 {"status":"queued"} la prima lovire (cache miss)
# 200 cu JSON după ce jobul scrie în cache
```

