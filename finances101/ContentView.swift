import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserRoleManager.self) private var roleManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var isLoaded = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            SpendingView()
                .tabItem {
                    Label("Spending", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            DebtsWishlistView()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.clipboard")
                }
                .tag(2)

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.pie.fill")
                }
                .tag(3)

            WalletsView()
                .tabItem {
                    Label("Wallets", systemImage: "wallet.pass.fill")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .tint(AppColors.primaryDeep)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.white

            let normalColor = UIColor.systemGray
            let selectedColor = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1) // #7C3AED

            let item = UITabBarItemAppearance()
            item.normal.iconColor = normalColor
            item.normal.titleTextAttributes = [.foregroundColor: normalColor]
            item.selected.iconColor = selectedColor
            item.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            item.focused.iconColor = selectedColor
            item.focused.titleTextAttributes = [.foregroundColor: selectedColor]

            appearance.stackedLayoutAppearance = item
            appearance.inlineLayoutAppearance = item
            appearance.compactInlineLayoutAppearance = item
            // Clear the default selection indicator that causes the dark flash on tap
            appearance.selectionIndicatorImage = UIImage()

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                roleManager.resetToLock()
            }
        }
        .onAppear {
            if !isLoaded {
                isLoaded = true
                setupApp()
            }
        }
    }
    
    private func setupApp() {
        ensureSettingsExist()

        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let horizonDays = (try? modelContext.fetch(settingsDescriptor))?.first?.defaultHorizonDays ?? 30

        let recurringManager = RecurringManager(modelContext: modelContext)
        recurringManager.generateUpcomingRecurring(horizonDays: horizonDays)

        let statusManager = StatusUpdateManager(modelContext: modelContext)
        statusManager.updateOverdueStatuses()

        if NotificationManager.shared.isEnabled {
            let expenses = (try? modelContext.fetch(FetchDescriptor<ExpenseEntry>())) ?? []
            let debts = (try? modelContext.fetch(FetchDescriptor<Debt>())) ?? []
            let subscriptions = (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []
            NotificationManager.shared.scheduleAll(expenses: expenses, debts: debts, subscriptions: subscriptions)
        }
    }
    
    private func ensureSettingsExist() {
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? modelContext.fetch(descriptor), settings.isEmpty {
            let defaultSettings = AppSettings()
            modelContext.insert(defaultSettings)
            modelContext.saveWithLogging()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            IncomeEntry.self,
            ExpenseEntry.self,
            CharityAccrual.self,
            CharityPayment.self,
            Debt.self,
            WishlistItem.self,
            RecurringTemplate.self,
            AppSettings.self
        ], inMemory: true)
}
