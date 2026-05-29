import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    
    @FocusState private var isBalanceFieldFocused: Bool
    @State private var initialBalance: String = ""
    @State private var charityPercentage: Double = 25.0
    @State private var currency: String = "USD"
    @State private var currencySymbol: String = "$"
    @State private var showAdvanced = false
    
    @State private var showExportOptions = false
    @State private var showResetAlert = false
    
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
                dataSection
                advancedSection
                aboutSection
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
        }
    }
    
    private var charitySection: some View {
        Section {
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
        } header: {
            Text("Charity")
        } footer: {
            Text("Charity is calculated when income is received")
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
        currency = settings.currency
        currencySymbol = settings.currencySymbol
    }
    
    private func saveSettings() {
        guard let settings = currentSettings else { return }
        
        if let balance = Decimal(string: initialBalance) {
            settings.initialBalance = balance
        }
        settings.charityPercentage = charityPercentage
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
