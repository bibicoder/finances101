import Foundation
import SwiftData

enum CharityManager {
    /// Creates a CharityAccrual for the given income if:
    /// - charity is enabled (percentage > 0)
    /// - no accrual already exists for this income
    /// - the income status matches the configured accrual mode (onEarned / onPaid)
    static func createAccrualIfNeeded(for income: IncomeEntry, in modelContext: ModelContext) {
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        guard let settings = (try? modelContext.fetch(settingsDescriptor))?.first,
              settings.charityPercentage > 0 else { return }

        let accrualDescriptor = FetchDescriptor<CharityAccrual>()
        let existing = (try? modelContext.fetch(accrualDescriptor)) ?? []
        guard !existing.contains(where: { $0.linkedIncomeId == income.id }) else { return }

        let shouldCreate: Bool
        switch settings.charityAccrualMode {
        case .onEarned:
            shouldCreate = income.status == .earned || income.status == .paid
        case .onPaid:
            shouldCreate = income.status == .paid
        }
        guard shouldCreate else { return }

        let accrual = CharityAccrual(
            date: income.payoutDate,
            baseAmount: income.amount,
            percentage: settings.charityPercentage,
            linkedIncomeId: income.id,
            note: "From: \(income.title)"
        )
        modelContext.insert(accrual)
    }
}
