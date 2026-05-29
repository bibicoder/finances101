# finances101 — Personal Finance iOS App

## Project location
`/Users/beibarysyessiluly/Desktop/finances101/`

## What this is
SwiftUI + SwiftData personal finance tracker for iOS.
Tracks income, expenses, debts, wishlist, charity, and analytics.

## Stack
- **Language:** Swift 5
- **UI:** SwiftUI
- **Data:** SwiftData (NOT Core Data — do not reintroduce Core Data)
- **Min iOS:** check Xcode project settings

## Project structure
```
finances101/
├── finances101App.swift          # App entry + ModelContainer setup
├── ContentView.swift             # Tab navigation (5-6 tabs)
├── Models/
│   ├── IncomeEntry.swift         # Status: planned/earned/paid
│   ├── ExpenseEntry.swift        # Type: mandatory/optional/recurring; Status: planned/paid
│   ├── Debt.swift
│   ├── WishlistItem.swift
│   ├── CharityAccrual.swift
│   ├── CharityPayment.swift
│   ├── RecurringTemplate.swift
│   └── AppSettings.swift         # Single-row settings: balance, charity %, currency, horizon days
├── Views/
│   ├── Home/                     # Dashboard: balance summary, quick stats
│   ├── Spending/                 # Charts: pie chart, balance chart
│   ├── DebtsWishlist/            # Debts + wishlist combined tab
│   ├── Timeline/                 # Chronological view of entries
│   ├── Analytics/                # Trend charts
│   ├── Charity/                  # Charity tracking (shown only if % > 0)
│   ├── Settings/
│   └── Shared/                   # Add/Edit sheets for all model types
└── Utils/
    ├── DesignSystem.swift         # AppColors (hex-based color palette)
    ├── BalanceCalculator.swift    # Core balance logic
    ├── RecurringManager.swift     # Auto-generate recurring entries (90-day horizon)
    ├── StatusUpdateManager.swift  # Auto-update overdue statuses on app launch
    ├── CategoryManager.swift
    ├── ExportManager.swift
    ├── HapticManager.swift
    └── NumberFormatter+Extensions.swift
```

## Key app behavior
- On launch: generates recurring entries for next 90 days, updates overdue statuses
- Charity tab is conditional: only shown when `charityPercentage > 0` in AppSettings
- AppSettings is a singleton row — always check `settings.first` before accessing
- All monetary values use `Decimal` (not Double/Float) — keep this consistent

## Design system
```swift
AppColors.primaryDeep  = #1C3D5A  // navy
AppColors.primaryLight = #3FA7F5  // blue
AppColors.income       = #34C759  // green
AppColors.expense      = #FF6B6B  // red
AppColors.charity      = #AF52DE  // purple
```
Always use `AppColors.*` constants — do not hardcode hex values in views.

## SwiftData schema (all models registered in ModelContainer)
`IncomeEntry`, `ExpenseEntry`, `CharityAccrual`, `CharityPayment`,
`Debt`, `WishlistItem`, `RecurringTemplate`, `AppSettings`

If adding a new model — register it in `finances101App.swift` schema array.

## Rules
- Do NOT use Core Data or UserDefaults for model data — SwiftData only
- Use `HapticManager.selection()` on meaningful user interactions
- Tab order: Dashboard → Spending → Plans → Analytics → [Charity] → Settings
- Charity tab index shifts depending on whether it's visible — handle `.tag()` accordingly
