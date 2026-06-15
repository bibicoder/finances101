import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query private var expenses: [ExpenseEntry]
    @Query private var debts: [Debt]
    @Query private var subscriptions: [Subscription]

    @Environment(UserRoleManager.self) private var roleManager
    @FocusState private var isBalanceFieldFocused: Bool
    @State private var initialBalance: String = ""
    @State private var charityPercentage: Double = 25.0
    @State private var charityMode: CharityMode = .percentage
    @State private var charityFixedAmount: String = ""
    @State private var currency: String = "USD"
    @State private var currencySymbol: String = "$"
    @State private var showAdvanced = false

    @State private var showExportOptions = false
    @State private var showResetAlert = false
    @State private var showPINSetup = false
    @State private var showRemovePINAlert = false
    @State private var pinExists = KeychainManager.hasWifePIN()

    @State private var showConnectBank = false
    @State private var showImportTransactions = false
    @State private var showDisconnectBankAlert = false
    @State private var showCharityView = false
    @State private var showCSVImport = false
    @State private var showWallets = false
    @State private var plaidManager = PlaidManager.shared

    // Notifications
    @State private var notificationsEnabled = NotificationManager.shared.isEnabled
    @State private var notifyPayments = NotificationManager.shared.notifyPayments
    @State private var notifyDebts = NotificationManager.shared.notifyDebts
    @State private var notifySubscriptions = NotificationManager.shared.notifySubscriptions
    @State private var notifAuthStatus: UNAuthorizationStatus = .notDetermined
    
    private let currencies = [
        ("USD", "$"),
        ("EUR", "€"),
        ("GBP", "£"),
        ("KZT", "₸"),
        ("RUB", "₽"),
        ("TRY", "₺"),
        ("AED", "د.إ")
    ]
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                charitySection
                walletsSection
                currencySection
                notificationsSection
                if roleManager.canEdit {
                    bankSection
                    familyViewSection
                    dataSection
                    advancedSection
                }
                aboutSection
            }
            .navigationDestination(isPresented: $showCharityView) {
                CharityView()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isBalanceFieldFocused = false
                    }
                }
            }
            .onAppear {
                loadSettings()
                NotificationManager.shared.checkAuthorizationStatus { status in
                    notifAuthStatus = status
                }
            }
            .onChange(of: initialBalance) { _, _ in saveSettings() }
            .onChange(of: charityPercentage) { _, _ in saveSettings() }
            .onChange(of: charityMode) { _, _ in saveSettings() }
            .onChange(of: charityFixedAmount) { _, _ in saveSettings() }
            .onChange(of: currency) { _, _ in saveSettings() }
            .confirmationDialog("Export Format", isPresented: $showExportOptions) {
                Button("PDF Report (this month)") { exportPDF(period: .thisMonth) }
                Button("PDF Report (last 3 months)") { exportPDF(period: .last3Months) }
                Button("PDF Report (this year)") { exportPDF(period: .thisYear) }
                Button("CSV Spreadsheet") { exportCSV() }
                Button("JSON Backup") { exportJSON() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { resetAllData() }
            } message: {
                Text("This will delete all your data. This cannot be undone.")
            }
            .alert("Remove My View PIN?", isPresented: $showRemovePINAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    KeychainManager.deleteWifePIN()
                    pinExists = false
                    HapticManager.success()
                }
            } message: {
                Text("My View will be accessible without a PIN.")
            }
            .sheet(isPresented: $showPINSetup, onDismiss: {
                pinExists = KeychainManager.hasWifePIN()
            }) {
                PINSetupSheet()
            }
            .sheet(isPresented: $showConnectBank) {
                ConnectBankView()
            }
            .sheet(isPresented: $showImportTransactions) {
                PlaidImportView()
            }
            .sheet(isPresented: $showCSVImport) {
                CSVImportView()
            }
            .sheet(isPresented: $showWallets) {
                WalletsView()
            }
            .alert("Disconnect Bank?", isPresented: $showDisconnectBankAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    plaidManager.disconnect()
                    HapticManager.success()
                }
            } message: {
                Text("This removes the bank connection. Your imported transactions will remain.")
            }
        }
    }
    
    private var charitySection: some View {
        Section {
            Picker("Mode", selection: $charityMode) {
                ForEach(CharityMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            if charityMode == .percentage || charityMode == .combined {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Percentage")
                        Spacer()
                        Text("\(Int(charityPercentage))%")
                            .foregroundStyle(AppColors.charity)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $charityPercentage, in: 0...50, step: 1)
                        .tint(AppColors.charity)
                }
            }

            if charityMode == .fixedAmount || charityMode == .combined {
                HStack {
                    Text("Fixed Amount")
                    Spacer()
                    TextField("0.00", text: $charityFixedAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Button {
                showCharityView = true
            } label: {
                Label("Charity History & Payments", systemImage: "heart.text.square.fill")
                    .foregroundStyle(AppColors.charity)
            }
        } header: {
            Text("Charity")
        } footer: {
            Text(charityFooterText)
        }
    }

    private var charityFooterText: String {
        switch charityMode {
        case .percentage:
            return "Donate \(Int(charityPercentage))% of each income received"
        case .fixedAmount:
            let symbol = currentSettings?.currencySymbol ?? "$"
            let amount = Decimal(userInput: charityFixedAmount) ?? 0
            return "Donate a fixed \(symbol)\(amount.formatted()) once per month"
        case .combined:
            let symbol = currentSettings?.currencySymbol ?? "$"
            let fixed = Decimal(userInput: charityFixedAmount) ?? 0
            return "Per income: whichever is greater — \(Int(charityPercentage))% or \(symbol)\(fixed.formatted()) fixed"
        }
    }
    
    private var walletsSection: some View {
        Section {
            Button {
                showWallets = true
            } label: {
                Label("Wallets & Transfers", systemImage: "wallet.pass.fill")
                    .foregroundStyle(AppColors.primaryDeep)
            }
        } header: {
            Text("Wallets")
        } footer: {
            Text("Cash, cards, and savings accounts with transfers between them")
        }
    }

    private var notificationsSection: some View {
        Section {
            if notifAuthStatus == .denied {
                HStack {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(AppColors.warning)
                    Text("Notifications blocked in iOS Settings")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.warning)
                }
            } else {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Enable Notifications", systemImage: "bell.fill")
                }
                .onChange(of: notificationsEnabled) { _, enabled in
                    NotificationManager.shared.isEnabled = enabled
                    if enabled && notifAuthStatus == .notDetermined {
                        NotificationManager.shared.requestAuthorization { granted in
                            notifAuthStatus = granted ? .authorized : .denied
                            if granted {
                                NotificationManager.shared.scheduleAll(
                                    expenses: expenses, debts: debts, subscriptions: subscriptions
                                )
                            }
                        }
                    } else {
                        NotificationManager.shared.scheduleAll(
                            expenses: expenses, debts: debts, subscriptions: subscriptions
                        )
                    }
                }

                if notificationsEnabled {
                    Toggle("Upcoming payments (1 day before)", isOn: $notifyPayments)
                        .onChange(of: notifyPayments) { _, v in
                            NotificationManager.shared.notifyPayments = v
                            NotificationManager.shared.scheduleAll(expenses: expenses, debts: debts, subscriptions: subscriptions)
                        }
                    Toggle("Debt target dates", isOn: $notifyDebts)
                        .onChange(of: notifyDebts) { _, v in
                            NotificationManager.shared.notifyDebts = v
                            NotificationManager.shared.scheduleAll(expenses: expenses, debts: debts, subscriptions: subscriptions)
                        }
                    Toggle("Subscription renewals", isOn: $notifySubscriptions)
                        .onChange(of: notifySubscriptions) { _, v in
                            NotificationManager.shared.notifySubscriptions = v
                            NotificationManager.shared.scheduleAll(expenses: expenses, debts: debts, subscriptions: subscriptions)
                        }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if notifAuthStatus != .denied {
                Text("Reminders fire at 9:00 AM on the scheduled day.")
            }
        }
    }

    private var currencySection: some View {
        Section("Currency") {
            Picker("Currency", selection: $currency) {
                ForEach(currencies, id: \.0) { code, symbol in
                    Text("\(code) (\(symbol))").tag(code)
                }
            }
            .onChange(of: currency) { _, newValue in
                if let selected = currencies.first(where: { $0.0 == newValue }) {
                    currencySymbol = selected.1
                }
            }
        }
    }
    
    private var dataSection: some View {
        Section("Data") {
            NavigationLink {
                CategoryRulesView()
            } label: {
                Label("Auto-Categorization Rules", systemImage: "tag.fill")
            }

            Button {
                showCSVImport = true
            } label: {
                Label("Import CSV from Bank", systemImage: "arrow.down.doc.fill")
            }

            Button {
                showExportOptions = true
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label("Reset All Data", systemImage: "trash")
            }
        }
    }
    
    private var bankSection: some View {
        Section {
            // One row per linked institution (Chase, Cash App, ...) — rename + per-bank balance
            ForEach(plaidManager.connections) { connection in
                BankConnectionRow(
                    connection: connection,
                    symbol: settings.first?.currencySymbol ?? "$",
                    onRename: { plaidManager.setNickname(id: connection.id, $0) },
                    onRemove: {
                        plaidManager.removeConnection(id: connection.id)
                        HapticManager.success()
                    }
                )
            }

            if plaidManager.isConnected {
                Button("Import Transactions") {
                    showImportTransactions = true
                }
            }
            Button(plaidManager.isConnected ? "Add Another Bank" : "Connect Bank (Plaid)") {
                showConnectBank = true
            }
            if plaidManager.isConnected {
                Button("Disconnect All", role: .destructive) {
                    showDisconnectBankAlert = true
                }
            }
        } header: {
            Text("Bank Integration")
        } footer: {
            Text(plaidManager.isConnected
                 ? "Balances and transactions sync automatically from all linked institutions. Pull down on the Dashboard to refresh now."
                 : "Connect your banks (Chase, Cash App, ...) to automatically import transactions via Plaid.")
        }
    }

    private var familyViewSection: some View {
        Section {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(AppColors.primaryDeep)
                Text("My View PIN")
                Spacer()
                Text(pinExists ? "Enabled" : "Off")
                    .foregroundStyle(pinExists ? AppColors.income : .secondary)
                    .font(.subheadline)
            }

            if pinExists {
                Button("Change PIN") {
                    showPINSetup = true
                }
                Button("Remove PIN", role: .destructive) {
                    showRemovePINAlert = true
                }
            } else {
                Button("Set My View PIN") {
                    showPINSetup = true
                }
            }

            Divider()

            HStack {
                Image(systemName: roleManager.deviceRole == .familyMember ? "heart.fill" : "person.fill.checkmark")
                    .foregroundStyle(roleManager.deviceRole == .familyMember ? AppColors.charity : AppColors.primaryDeep)
                Text("This Device")
                Spacer()
                Text(roleManager.deviceRole == .familyMember ? "Family Member" : "Owner")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Button("Change Device Role") {
                roleManager.completeDeviceSetup(as: .unset)
            }
            .foregroundStyle(AppColors.warning)

        } header: {
            Text("Access Control")
        } footer: {
            Text(pinExists
                 ? "My View requires this PIN. Family View is always accessible without a PIN."
                 : "Set a PIN to protect My View. Family members can open Family View freely.")
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            DisclosureGroup("Advanced Settings", isExpanded: $showAdvanced) {
                if plaidManager.isConnected {
                    // With a bank linked, the bank is the source of truth for cash —
                    // a manual starting balance would double-count, so it's disabled.
                    Text("Starting balance is managed by your linked bank. Use a manual Cash wallet for money outside the bank.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Starting Balance")
                        Spacer()
                        TextField("0.00", text: $initialBalance)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .focused($isBalanceFieldFocused)
                    }
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("2.0.0")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Built with")
                Spacer()
                Text("SwiftUI + SwiftData")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func loadSettings() {
        guard let settings = currentSettings else { return }
        initialBalance = "\(settings.initialBalance)"
        charityPercentage = settings.charityPercentage
        charityMode = settings.charityMode
        charityFixedAmount = settings.charityFixedAmount > 0 ? "\(settings.charityFixedAmount)" : ""
        currency = settings.currency
        currencySymbol = settings.currencySymbol
    }

    private func saveSettings() {
        guard let settings = currentSettings else { return }

        if let balance = Decimal(userInput: initialBalance) {
            settings.initialBalance = balance
        }
        settings.charityPercentage = charityPercentage
        settings.charityMode = charityMode
        settings.charityFixedAmount = Decimal(userInput: charityFixedAmount) ?? 0
        settings.currency = currency
        settings.currencySymbol = currencySymbol
        settings.updatedAt = Date()

        modelContext.saveWithLogging()
    }
    
    private enum PDFPeriod {
        case thisMonth, last3Months, thisYear
        var dateRange: (Date, Date) {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .thisMonth:
                let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
                return (start, now)
            case .last3Months:
                let start = cal.date(byAdding: .month, value: -3, to: now) ?? now
                return (start, now)
            case .thisYear:
                let start = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
                return (start, now)
            }
        }
    }

    private func exportPDF(period: PDFPeriod) {
        let exportManager = ExportManager(modelContext: modelContext)
        let (start, end) = period.dateRange
        if let url = exportManager.exportToPDF(startDate: start, endDate: end) {
            shareFile(url: url)
        }
    }

    private func exportJSON() {
        let exportManager = ExportManager(modelContext: modelContext)
        if let url = exportManager.exportToJSON() {
            shareFile(url: url)
        }
    }
    
    private func exportCSV() {
        let exportManager = ExportManager(modelContext: modelContext)
        if let url = exportManager.exportToCSV() {
            shareFile(url: url)
        }
    }
    
    private func shareFile(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
        }
        
        rootVC.present(activityVC, animated: true)
    }
    
    private func resetAllData() {
        do {
            try modelContext.delete(model: IncomeEntry.self)
            try modelContext.delete(model: ExpenseEntry.self)
            try modelContext.delete(model: CharityAccrual.self)
            try modelContext.delete(model: CharityPayment.self)
            try modelContext.delete(model: Debt.self)
            try modelContext.delete(model: WishlistItem.self)
            try modelContext.delete(model: RecurringTemplate.self)
            
            if let settings = currentSettings {
                settings.initialBalance = 0
            }
            
            try modelContext.save()
            HapticManager.success()
        } catch {
            print("Failed to reset data: \(error)")
        }
    }
}

// MARK: - Bank connection row (rename + balance)

private struct BankConnectionRow: View {
    let connection: PlaidConnection
    let symbol: String
    let onRename: (String) -> Void
    let onRemove: () -> Void

    @State private var nickname: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(AppColors.primaryDeep)

                TextField(connection.institutionName, text: $nickname)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { commit() }

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(AppColors.expense)
                }
                .buttonStyle(.borderless)
            }

            HStack {
                // Show the real institution under a custom nickname
                Text(connection.nickname == nil ? "Connected \(connection.connectedAt.formatted(date: .abbreviated, time: .omitted))" : connection.institutionName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let cash = connection.cashBalance {
                    Text("\(symbol)\(cash.formatted())")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppColors.income)
                }
            }
        }
        .onAppear { nickname = connection.nickname ?? "" }
        .onChange(of: nameFocused) { _, focused in if !focused { commit() } }
    }

    private func commit() {
        onRename(nickname)
        HapticManager.selection()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [
            AppSettings.self,
            IncomeEntry.self,
            ExpenseEntry.self,
            CharityAccrual.self,
            CharityPayment.self,
            Debt.self,
            WishlistItem.self,
            RecurringTemplate.self
        ], inMemory: true)
}
