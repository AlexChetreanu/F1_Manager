# Proiect nou

## API Base URL

The mobile app reads its server address from `F1App/Info.plist` (`API_BASE_URL`).

- **Simulator:** the default value `http://127.0.0.1:8000` points to a server running on the same machine.
- **Physical device:** replace `API_BASE_URL` with your computer's IPv4 address on the local network (e.g. `http://192.168.0.10:8000`) so the device can reach the development server.

After updating the value, rebuild the app for the desired target.

## F1 news API

Quick check for available Autosport news:

```bash
curl -s 'http://127.0.0.1:8000/api/news/f1?days=30&limit=20' | jq 'length'
```

## Historical playback API

### Backend

```bash
cd API/F1_API
composer install    # only first time
php artisan serve   # starts Laravel backend on http://127.0.0.1:8000
```

The new historical endpoints live under `/api/historical` and expose:

- `/historical/resolve`
- `/historical/session/{session_key}/manifest`
- `/historical/session/{session_key}/drivers`
- `/historical/session/{session_key}/track`
- `/historical/session/{session_key}/events`
- `/historical/session/{session_key}/laps`
- `/historical/session/{session_key}/frames`

### iOS client

Open `F1App/F1App.xcodeproj` in Xcode 15+. Ensure `API_BASE_URL` in `Info.plist`
points to the backend server (see above). The client uses the new
`HistoricalStreamService` to stream frames and `PlaybackViewModel` to
control buffering and playback.

Run unit tests with `swift test` or the Xcode test action.
