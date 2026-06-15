import SwiftUI
import SwiftData

struct SubscriptionPreset {
    let name: String
    let icon: String
    let colorHex: String
}

private let presets: [SubscriptionPreset] = [
    .init(name: "Netflix",        icon: "play.tv.fill",                    colorHex: "E50914"),
    .init(name: "Spotify",        icon: "music.note",                      colorHex: "1DB954"),
    .init(name: "YouTube",        icon: "play.rectangle.fill",             colorHex: "FF0000"),
    .init(name: "Disney+",        icon: "wand.and.stars",                  colorHex: "113CCF"),
    .init(name: "Amazon Prime",   icon: "bag.fill",                        colorHex: "FF9900"),
    .init(name: "Apple One",      icon: "icloud.fill",                     colorHex: "555555"),
    .init(name: "Hulu",           icon: "tv.fill",                         colorHex: "3DBB3D"),
    .init(name: "ChatGPT",        icon: "bubble.left.and.bubble.right.fill", colorHex: "10A37F"),
    .init(name: "Adobe",          icon: "pencil.tip.crop.circle.fill",     colorHex: "FF0000"),
    .init(name: "Microsoft 365",  icon: "doc.fill",                        colorHex: "0078D4"),
    .init(name: "Dropbox",        icon: "tray.full.fill",                  colorHex: "0061FF"),
    .init(name: "Gym",            icon: "figure.strengthtraining.traditional", colorHex: "FF6B6B"),
]

struct AddSubscriptionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingSubscription: Subscription? = nil

    @State private var name = ""
    @State private var amountText = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var nextBillingDate = Date()
    @State private var notifyDaysBefore = 3
    @State private var selectedIcon = "play.rectangle.fill"
    @State private var selectedColorHex = "3FA7F5"
    @State private var note = ""
    @State private var isActive = true

    private var isEditing: Bool { editingSubscription != nil }
    private var isValid: Bool { !name.isEmpty && Decimal(userInput: amountText) != nil }

    var body: some View {
        NavigationStack {
            Form {
                presetsSection
                detailsSection
                billingSection
                notificationSection
            }
            .navigationTitle(isEditing ? "Edit Subscription" : "Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private var presetsSection: some View {
        Section("Quick Pick") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            name = preset.name
                            selectedIcon = preset.icon
                            selectedColorHex = preset.colorHex
                            HapticManager.selection()
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: preset.colorHex).opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color(hex: preset.colorHex))
                                }
                                Text(preset.name.components(separatedBy: " ").first ?? preset.name)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 56)
                        }
                        .buttonStyle(.plain)
                        .opacity(name == preset.name ? 1 : 0.6)
                        .scaleEffect(name == preset.name ? 1.05 : 1)
                        .animation(.spring(duration: 0.2), value: name)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: selectedColorHex).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: selectedIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: selectedColorHex))
                }
                TextField("Service name", text: $name)
                    .font(.body)
            }

            HStack {
                Text("Amount")
                Spacer()
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

            if isEditing {
                Toggle("Active", isOn: $isActive)
            }
        }
    }

    private var billingSection: some View {
        Section("Billing") {
            Picker("Cycle", selection: $billingCycle) {
                ForEach(BillingCycle.allCases, id: \.self) { cycle in
                    Text(cycle.rawValue).tag(cycle)
                }
            }

            DatePicker("Next billing", selection: $nextBillingDate, displayedComponents: .date)
        }
    }

    private var notificationSection: some View {
        Section {
            Picker("Remind me", selection: $notifyDaysBefore) {
                Text("No reminder").tag(0)
                Text("1 day before").tag(1)
                Text("3 days before").tag(3)
                Text("7 days before").tag(7)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(notifyDaysBefore > 0
                 ? "You'll get a notification \(notifyDaysBefore) day\(notifyDaysBefore == 1 ? "" : "s") before billing."
                 : "No notification will be sent.")
        }
    }

    private func loadExisting() {
        guard let sub = editingSubscription else { return }
        name = sub.name
        amountText = "\(sub.amount)"
        billingCycle = sub.billingCycle
        nextBillingDate = sub.nextBillingDate
        notifyDaysBefore = sub.notifyDaysBefore
        selectedIcon = sub.icon
        selectedColorHex = sub.colorHex
        note = sub.note ?? ""
        isActive = sub.isActive
    }

    private func save() {
        guard let amount = Decimal(userInput: amountText) else { return }

        if let sub = editingSubscription {
            sub.name = name
            sub.amount = amount
            sub.billingCycle = billingCycle
            sub.nextBillingDate = nextBillingDate
            sub.notifyDaysBefore = notifyDaysBefore
            sub.icon = selectedIcon
            sub.colorHex = selectedColorHex
            sub.note = note.isEmpty ? nil : note
            sub.isActive = isActive
            SubscriptionNotificationManager.schedule(for: sub)
        } else {
            let sub = Subscription(
                name: name,
                amount: amount,
                billingCycle: billingCycle,
                nextBillingDate: nextBillingDate,
                icon: selectedIcon,
                colorHex: selectedColorHex,
                notifyDaysBefore: notifyDaysBefore
            )
            modelContext.insert(sub)
            SubscriptionNotificationManager.requestPermission()
            SubscriptionNotificationManager.schedule(for: sub)
        }

        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
