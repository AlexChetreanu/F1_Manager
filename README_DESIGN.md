# Design System

## Tokens
- **AppColors** – `bg`, `surface`, `textPri`, `textSec`, `accent`, `stroke`
- **AppTypography** – `.titleXL()`, `.titleL()`, `.bodyStyle()`, `.captionStyle()`
- **Layout** – spacings (`xs=4`, `s=8`, `m=12`, `l=16`, `xl=24`), corner radii and shadow
- **Shimmer** – `.shimmer(active: Bool)`
- **Haptics** – `Haptics.soft()`

## Services & Stores
- `TeamColorService` fetches `/api/teams/colors`
- `TeamColorStore` caches colors and expune `color(forTeamId:)` / `color(forTeamName:)`
- Inject `TeamColorStore` in `F1AppApp` and access with `@EnvironmentObject`

## Components
- `Card` – container cu padding, stroke și shadow
- `TeamChip` – capsulă colorată cu animație de tap
- `DriverRow` – rând pentru pilot
- `StrategySuggestionCard` – card cu sugestie de strategie
- `QueuedView`, `EmptyStateView`, `ErrorBanner` – stări standard

### Exemplu
```swift
@EnvironmentObject var colorStore: TeamColorStore

DriverRow(
    position: 1,
    driverNumber: 44,
    driverName: "Lewis Hamilton",
    teamName: "Mercedes",
    trend: 1
)

TeamChip(teamId: 9, teamName: "Ferrari")
    .onTapGesture { Haptics.soft() }
```
