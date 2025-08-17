# Proiect nou

## API Base URL

The mobile app reads its server address from `F1App/F1App/APIConfig.swift`.

- **Simulator:** the default value `http://127.0.0.1:8000` points to a server running on the same machine as the iOS Simulator.
- **Physical device:** replace `baseURL` with your computer's IP address on the local network (e.g. `http://192.168.0.10:8000`) so the device can reach the development server.

After updating the value, rebuild the app for the desired target.
