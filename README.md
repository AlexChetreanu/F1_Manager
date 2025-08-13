# F1 Manager

Acest repository găzduiește două componente principale pentru gestionarea
informațiilor din Formula&nbsp;1:

- **F1App** – aplicație iOS construită în SwiftUI.
- **API** – backend Laravel care furnizează datele necesare aplicației.

## Cerințe de mediu

### API
- PHP 8.2+ și [Composer](https://getcomposer.org/) pentru gestionarea
  dependențelor
- Node.js & npm pentru active front-end
- MySQL sau altă bază de date compatibilă
- Variabile de configurare în fișierul `.env` (ex. `APP_KEY`, `DB_HOST`,
  `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`)

### F1App
- macOS cu Xcode 15+ și instrumentele Swift instalate
- Simulator sau dispozitiv iOS 17+
- URL-ul API-ului este setat implicit la `http://127.0.0.1:8000` în
  `AuthViewModel.swift`

## Instalare și rulare

### API
```bash
cd API/F1_API
cp .env.example .env      # configurează variabilele de mediu
composer install          # instalează dependențele PHP
npm install               # instalează dependențele JavaScript
php artisan key:generate  # generează cheia aplicației
php artisan migrate       # creează tabelele bazei de date
php artisan serve         # pornește serverul pe http://127.0.0.1:8000
```

### F1App
```bash
cd F1App
xcodebuild -scheme F1App -destination 'platform=iOS Simulator,name=iPhone 15'
```
Alternativ, deschide `F1App.xcodeproj` în Xcode și rulează aplicația.

## Structură

- `API/` – conține serviciul Laravel.
- `F1App/` – conține aplicația iOS.

