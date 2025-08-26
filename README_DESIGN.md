# Design System & Team Colors

Acest document descrie noile componente vizuale și serviciul de culori pentru aplicația iOS **F1App**.

## TeamColorStore
- `TeamColorStore` este un `ObservableObject` care încarcă culorile echipelor prin endpoint-ul `/api/teams/colors`.
- Culorile sunt memorate în `UserDefaults` și pot fi obținute prin:
  - `color(forTeamId:)`
  - `color(forTeamName:)`
  - `color(forDriverNumber:)` (fallback la accent roșu dacă nu există mapare).
- În `F1AppApp` store-ul este creat cu `@StateObject` și injectat cu `.environmentObject`.

## Componente
- **Card** – container cu fundal `AppColors.surface`, colțuri 20, stroke fin și shadow subtil.
- **TeamChip** – capsulă colorată după echipă.
- **DriverRow** – afișează poziția, numărul și numele pilotului cu culoarea echipei.
- **StrategySuggestionCard** – card care combină `DriverRow` cu detaliile strategiei.
- **StateViews** – include `QueuedView`, `EmptyStateView` și `ErrorBanner` pentru stări de încărcare/eroare.

## Stiluri
- Paletă: alb `#FFFFFF`, roșu `#E10600`, negru `#0A0A0A` cu suport Light/Dark.
- Tipografie: `titleXL`, `titleL`, `bodyStyle`, `captionStyle` (SF Pro).
- Shimmer: `.shimmer()` pentru stări de încărcare.
- Animații: `.animation(.interpolatingSpring(stiffness: 220, damping: 28))` pe apariția cardurilor.

## Utilizare
```swift
@EnvironmentObject var colorStore: TeamColorStore

StrategySuggestionCard(suggestion: s)
TeamChip(teamId: s.teamId, teamName: s.team)
```

Culorile sunt obținute din `TeamColorStore`; în lipsă se folosește roșul de accent.
