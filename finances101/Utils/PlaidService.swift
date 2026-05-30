import Foundation

struct PlaidTransaction: Decodable {
    let transactionId: String
    let amount: Double
    let date: String
    let name: String
    let merchantName: String?
    let category: [String]?
    let pending: Bool

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case amount, date, name, pending
        case merchantName = "merchant_name"
        case category
    }
}

struct PlaidAccount: Decodable {
    let accountId: String
    let name: String
    let type: String
    let balances: Balances

    struct Balances: Decodable {
        let available: Double?
        let current: Double?
        let isoCurrencyCode: String?

        enum CodingKeys: String, CodingKey {
            case available, current
            case isoCurrencyCode = "iso_currency_code"
        }
    }

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name, type, balances
    }
}

enum PlaidError: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

enum PlaidService {
    static func createLinkToken() async throws -> String {
        let data = try await post("/create_link_token", body: [:])
        guard let token = data["link_token"] as? String else {
            throw PlaidError.invalidResponse
        }
        return token
    }

    static func exchangePublicToken(_ publicToken: String) async throws -> String {
        let data = try await post("/exchange_public_token", body: ["public_token": publicToken])
        guard let accessToken = data["access_token"] as? String else {
            throw PlaidError.invalidResponse
        }
        return accessToken
    }

    static func fetchTransactions(accessToken: String, days: Int = 30) async throws -> [PlaidTransaction] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let endDate = formatter.string(from: Date())
        let startDate = formatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!)

        let data = try await post("/transactions", body: [
            "access_token": accessToken,
            "start_date": startDate,
            "end_date": endDate,
        ])
        guard let txArray = data["transactions"] else { throw PlaidError.invalidResponse }
        let txData = try JSONSerialization.data(withJSONObject: txArray)
        return try JSONDecoder().decode([PlaidTransaction].self, from: txData)
    }

    static func fetchAccounts(accessToken: String) async throws -> [PlaidAccount] {
        let data = try await post("/accounts", body: ["access_token": accessToken])
        guard let accArray = data["accounts"] else { throw PlaidError.invalidResponse }
        let accData = try JSONSerialization.data(withJSONObject: accArray)
        return try JSONDecoder().decode([PlaidAccount].self, from: accData)
    }

    private static func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: PlaidConfig.backendURL + path) else { throw PlaidError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaidError.invalidResponse
        }
        if let error = json["error_message"] as? String { throw PlaidError.serverError(error) }
        return json
    }
}
