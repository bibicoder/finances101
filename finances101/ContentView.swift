import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @State private var selectedTab = 0
    @State private var isLoaded = false
    
    private var showCharityTab: Bool {
        (settings.first?.charityPercentage ?? 0) > 0
    }
    
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
            
            if showCharityTab {
                CharityView()
                    .tabItem {
                        Label("Charity", systemImage: "heart.fill")
                    }
                    .tag(4)
            }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(showCharityTab ? 5 : 4)
        }
        .tint(AppColors.primaryDeep)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
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
