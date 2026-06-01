import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    
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
    @State private var plaidManager = PlaidManager.shared
    
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
                currencySection
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
            }
            .onChange(of: initialBalance) { _, _ in saveSettings() }
            .onChange(of: charityPercentage) { _, _ in saveSettings() }
            .onChange(of: charityMode) { _, _ in saveSettings() }
            .onChange(of: charityFixedAmount) { _, _ in saveSettings() }
            .onChange(of: currency) { _, _ in saveSettings() }
            .confirmationDialog("Export Format", isPresented: $showExportOptions) {
                Button("JSON Backup") { exportJSON() }
                Button("CSV Spreadsheet") { exportCSV() }
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
            let amount = Decimal(string: charityFixedAmount) ?? 0
            return "Donate a fixed \(symbol)\(amount.formatted()) once per month"
        case .combined:
            let symbol = currentSettings?.currencySymbol ?? "$"
            let fixed = Decimal(string: charityFixedAmount) ?? 0
            return "Per income: whichever is greater — \(Int(charityPercentage))% or \(symbol)\(fixed.formatted()) fixed"
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
            HStack {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(AppColors.primaryDeep)
                Text("Bank Account")
                Spacer()
                Text(plaidManager.isConnected ? plaidManager.connectedBankName : "Not connected")
                    .foregroundStyle(plaidManager.isConnected ? AppColors.income : .secondary)
                    .font(.subheadline)
                    .lineLimit(1)
            }

            if plaidManager.isConnected {
                Button("Import Transactions") {
                    showImportTransactions = true
                }
                Button("Disconnect Bank", role: .destructive) {
                    showDisconnectBankAlert = true
                }
            } else {
                Button("Connect Bank (Plaid)") {
                    showConnectBank = true
                }
            }
        } header: {
            Text("Bank Integration")
        } footer: {
            Text(plaidManager.isConnected
                 ? "Pull the latest transactions from \(plaidManager.connectedBankName) into Finance 101."
                 : "Connect your bank to automatically import transactions via Plaid.")
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
                HStack {
                    Text("Initial Balance")
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

        if let balance = Decimal(string: initialBalance) {
            settings.initialBalance = balance
        }
        settings.charityPercentage = charityPercentage
        settings.charityMode = charityMode
        settings.charityFixedAmount = Decimal(string: charityFixedAmount) ?? 0
        settings.currency = currency
        settings.currencySymbol = currencySymbol
        settings.updatedAt = Date()

        modelContext.saveWithLogging()
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
