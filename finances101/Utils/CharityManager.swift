import Foundation
import SwiftData

enum CharityManager {
    static func createAccrualIfNeeded(for income: IncomeEntry, in modelContext: ModelContext) {
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        guard let settings = (try? modelContext.fetch(settingsDescriptor))?.first else { return }

        let shouldCreate: Bool
        switch settings.charityAccrualMode {
        case .onEarned:
            shouldCreate = income.status == .earned || income.status == .paid
        case .onPaid:
            shouldCreate = income.status == .paid
        }
        guard shouldCreate else { return }

        switch settings.charityMode {
        case .percentage:
            guard settings.charityPercentage > 0 else { return }
            createPercentageAccrual(income: income, settings: settings, modelContext: modelContext)
        case .fixedAmount:
            guard settings.charityFixedAmount > 0 else { return }
            createFixedMonthlyAccrual(referenceDate: income.payoutDate, settings: settings, modelContext: modelContext)
        case .combined:
            guard settings.charityPercentage > 0 || settings.charityFixedAmount > 0 else { return }
            createCombinedAccrual(income: income, settings: settings, modelContext: modelContext)
        }
    }

    private static func createPercentageAccrual(income: IncomeEntry, settings: AppSettings, modelContext: ModelContext) {
        let existing = (try? modelContext.fetch(FetchDescriptor<CharityAccrual>())) ?? []
        guard !existing.contains(where: { $0.linkedIncomeId == income.id }) else { return }

        let accrual = CharityAccrual(
            date: income.payoutDate,
            baseAmount: income.amount,
            percentage: settings.charityPercentage,
            linkedIncomeId: income.id,
            note: "From: \(income.title)"
        )
        modelContext.insert(accrual)
    }

    // One fixed accrual per calendar month — linkedIncomeId == nil + percentage == 0 marks fixed entries
    private static func createFixedMonthlyAccrual(referenceDate: Date, settings: AppSettings, modelContext: ModelContext) {
        let calendar = Calendar.current
        let refComponents = calendar.dateComponents([.year, .month], from: referenceDate)
        let existing = (try? modelContext.fetch(FetchDescriptor<CharityAccrual>())) ?? []

        let alreadyExists = existing.contains { accrual in
            accrual.linkedIncomeId == nil &&
            accrual.percentage == 0 &&
            calendar.dateComponents([.year, .month], from: accrual.date) == refComponents
        }
        guard !alreadyExists else { return }

        let accrual = CharityAccrual(
            date: referenceDate,
            baseAmount: 0,
            percentage: 0,
            accruedAmount: settings.charityFixedAmount,
            linkedIncomeId: nil,
            note: "Fixed monthly charity"
        )
        modelContext.insert(accrual)
    }

    // Per income: take whichever is greater — % of income or fixed amount
    private static func createCombinedAccrual(income: IncomeEntry, settings: AppSettings, modelContext: ModelContext) {
        let existing = (try? modelContext.fetch(FetchDescriptor<CharityAccrual>())) ?? []
        guard !existing.contains(where: { $0.linkedIncomeId == income.id }) else { return }

        let percentageAmount = income.amount * Decimal(settings.charityPercentage) / 100
        let combinedAmount = max(percentageAmount, settings.charityFixedAmount)

        let accrual = CharityAccrual(
            date: income.payoutDate,
            baseAmount: income.amount,
            percentage: settings.charityPercentage,
            accruedAmount: combinedAmount,
            linkedIncomeId: income.id,
            note: "From: \(income.title) (combined)"
        )
        modelContext.insert(accrual)
    }
}
