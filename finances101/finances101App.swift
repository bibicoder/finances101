import SwiftUI
import SwiftData

@main
struct finances101App: App {
    @State private var roleManager = UserRoleManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            IncomeEntry.self,
            ExpenseEntry.self,
            CharityAccrual.self,
            CharityPayment.self,
            Debt.self,
            WishlistItem.self,
            RecurringTemplate.self,
            AppSettings.self,
            Subscription.self,
            CategoryBudget.self,
            Wallet.self,
            WalletTransfer.self
        ])

        // Try with CloudKit sync first; fall back to local-only if CloudKit schema migration fails
        let cloudConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // Don't hide this: when CloudKit init fails, iCloud sync is OFF for the session.
            print("[SwiftData] CloudKit container failed, falling back to local-only store: \(error)")
        }

        // CloudKit migration failed (e.g. new model added). Use local store without wiping data.
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if roleManager.isLockScreenShown {
                    AppLockView()
                }
                if roleManager.needsDeviceSetup {
                    DeviceSetupView()
                        .transition(.opacity)
                }
            }
            .environment(roleManager)
            .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
