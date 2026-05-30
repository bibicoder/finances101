import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subscription.nextBillingDate) private var subscriptions: [Subscription]
    @Query private var settings: [AppSettings]

    @State private var showAdd = false
    @State private var editingSubscription: Subscription?
    @State private var showDeleteAlert = false
    @State private var toDelete: Subscription?

    private var symbol: String { settings.first?.currencySymbol ?? "$" }
    private var active: [Subscription] { subscriptions.filter(\.isActive) }
    private var inactive: [Subscription] { subscriptions.filter { !$0.isActive } }

    private var totalMonthly: Decimal {
        active.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
    }
    private var totalYearly: Decimal { totalMonthly * 12 }

    var body: some View {
        Group {
            if subscriptions.isEmpty {
                emptyState
            } else {
                subscriptionList
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSubscriptionSheet()
        }
        .sheet(item: $editingSubscription) { sub in
            AddSubscriptionSheet(editingSubscription: sub)
        }
        .alert("Remove Subscription?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let sub = toDelete {
                    SubscriptionNotificationManager.cancel(for: sub)
                    modelContext.delete(sub)
                    modelContext.saveWithLogging()
                }
            }
        } message: {
            Text("This won't affect any imported transactions.")
        }
        .onAppear { advancePastDates() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No subscriptions",
            systemImage: "repeat.circle.fill",
            description: Text("Track Netflix, Spotify, gym and other recurring payments")
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
    }

    private var subscriptionList: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                    .padding(.horizontal)

                if !active.isEmpty {
                    subscriptionSection(title: "Active", items: active)
                }
                if !inactive.isEmpty {
                    subscriptionSection(title: "Paused", items: inactive)
                }
            }
            .padding(.vertical)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Monthly")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(symbol)\(totalMonthly.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.expense)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("Yearly")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(symbol)\(totalYearly.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primaryDeep)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("Active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(active.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primaryLight)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.expense.opacity(0.2), lineWidth: 1)
        )
    }

    private func subscriptionSection(title: String, items: [Subscription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(items) { sub in
                    SubscriptionRow(subscription: sub, symbol: symbol)
                        .contentShape(Rectangle())
                        .onTapGesture { editingSubscription = sub }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                toDelete = sub
                                showDeleteAlert = true
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                sub.isActive.toggle()
                                SubscriptionNotificationManager.schedule(for: sub)
                                modelContext.saveWithLogging()
                                HapticManager.selection()
                            } label: {
                                Label(sub.isActive ? "Pause" : "Resume",
                                      systemImage: sub.isActive ? "pause.circle" : "play.circle")
                            }
                            .tint(sub.isActive ? .orange : .green)
                        }

                    if sub.id != items.last?.id {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .appCard()
            .padding(.horizontal)
        }
    }

    private func advancePastDates() {
        let today = Calendar.current.startOfDay(for: Date())
        var changed = false
        for sub in subscriptions where sub.isActive && sub.nextBillingDate < today {
            sub.advanceBillingDate()
            SubscriptionNotificationManager.schedule(for: sub)
            changed = true
        }
        if changed { modelContext.saveWithLogging() }
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: subscription.colorHex).opacity(subscription.isActive ? 0.15 : 0.07))
                    .frame(width: 44, height: 44)
                Image(systemName: subscription.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: subscription.colorHex).opacity(subscription.isActive ? 1 : 0.4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(subscription.isActive ? .primary : .secondary)

                Text(billingLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(symbol)\(subscription.amount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(subscription.isActive ? AppColors.expense : .secondary)

                dueBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var billingLabel: String {
        let date = subscription.nextBillingDate.formatted(date: .abbreviated, time: .omitted)
        return "\(subscription.billingCycle.rawValue.lowercased()) · next \(date)"
    }

    @ViewBuilder
    private var dueBadge: some View {
        let days = subscription.daysUntilBilling
        if subscription.isActive {
            if days == 0 {
                badge("Today", color: .red)
            } else if days <= 3 {
                badge("In \(days)d", color: .red)
            } else if days <= 7 {
                badge("In \(days)d", color: .orange)
            } else {
                Text("In \(days)d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}
