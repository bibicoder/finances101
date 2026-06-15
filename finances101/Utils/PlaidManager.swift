import Foundation
import Security

/// One linked institution (Chase, Cash App, ...). Each has its own Plaid access token.
struct PlaidConnection: Identifiable, Codable, Equatable {
    let id: UUID
    var institutionName: String
    var accessToken: String
    var connectedAt: Date

    // Per-bank state. All optional → old Keychain payloads decode cleanly (missing keys → nil).
    var nickname: String?           // user-given name, overrides institutionName for display
    var cashBalance: Decimal?       // spendable cash (available) at last sync
    var creditBalance: Decimal?     // credit-card debt owed at last sync
    var syncedAt: Date?             // last successful balance sync for this bank

    /// What the user sees: their nickname if set, otherwise the institution name.
    var displayName: String {
        let nick = (nickname ?? "").trimmingCharacters(in: .whitespaces)
        return nick.isEmpty ? institutionName : nick
    }

    init(id: UUID = UUID(), institutionName: String, accessToken: String, connectedAt: Date = Date()) {
        self.id = id
        self.institutionName = institutionName
        self.accessToken = accessToken
        self.connectedAt = connectedAt
    }
}

@Observable
final class PlaidManager {
    static let shared = PlaidManager()

    private(set) var connections: [PlaidConnection] = []

    var isConnected: Bool { !connections.isEmpty }
    var connectedBankName: String { connections.map(\.displayName).joined(separator: ", ") }

    /// Sum of spendable cash across every linked bank (last sync).
    var totalCash: Decimal { connections.compactMap(\.cashBalance).reduce(0, +) }
    /// Sum of credit-card debt across every linked bank (last sync).
    var totalCredit: Decimal { connections.compactMap(\.creditBalance).reduce(0, +) }
    /// True once at least one bank has reported a synced balance.
    var hasSyncedBalances: Bool { connections.contains { $0.syncedAt != nil } }

    // Keychain keys
    private static let connectionsKey = "com.finances101.plaidConnections"
    private static let legacyTokenKey = "com.finances101.plaidAccessToken"
    private static let legacyBankNameKey = "com.finances101.plaidBankName"

    private init() {
        connections = Self.readConnections()
        migrateLegacySingleConnectionIfNeeded()
    }

    func addConnection(accessToken: String, institutionName: String) {
        connections.append(PlaidConnection(institutionName: institutionName, accessToken: accessToken))
        persist()
    }

    func removeConnection(id: UUID) {
        connections.removeAll { $0.id == id }
        persist()
    }

    /// Store the latest synced balances for one bank (called per institution during sync).
    func updateSyncedBalances(id: UUID, cash: Decimal, credit: Decimal) {
        guard let i = connections.firstIndex(where: { $0.id == id }) else { return }
        connections[i].cashBalance = cash
        connections[i].creditBalance = credit
        connections[i].syncedAt = Date()
        persist()
    }

    /// Rename a bank. Empty string clears the nickname (falls back to institution name).
    func setNickname(id: UUID, _ nickname: String) {
        guard let i = connections.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        connections[i].nickname = trimmed.isEmpty ? nil : trimmed
        persist()
    }

    func disconnectAll() {
        connections = []
        persist()
    }

    // MARK: - Legacy API (kept so old call sites keep working)

    func saveConnection(accessToken: String, bankName: String) {
        addConnection(accessToken: accessToken, institutionName: bankName)
    }

    func disconnect() { disconnectAll() }

    /// First connection's token — legacy single-bank call sites.
    func accessToken() -> String? { connections.first?.accessToken }

    // MARK: - Persistence (Keychain, JSON array)

    private func persist() {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        Self.writeKeychain(key: Self.connectionsKey, data: data)
    }

    private static func readConnections() -> [PlaidConnection] {
        guard let data = readKeychain(key: connectionsKey),
              let list = try? JSONDecoder().decode([PlaidConnection].self, from: data) else { return [] }
        return list
    }

    /// Pre-multi-bank versions stored a single token + bank name. Convert once.
    private func migrateLegacySingleConnectionIfNeeded() {
        guard connections.isEmpty,
              let tokenData = Self.readKeychain(key: Self.legacyTokenKey),
              let token = String(data: tokenData, encoding: .utf8) else { return }
        let bankName = UserDefaults.standard.string(forKey: Self.legacyBankNameKey) ?? "Bank"
        connections = [PlaidConnection(institutionName: bankName, accessToken: token)]
        persist()
        Self.deleteKeychain(key: Self.legacyTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyBankNameKey)
    }

    // MARK: - Keychain helpers

    private static func writeKeychain(key: String, data: Data) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func readKeychain(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    private static func deleteKeychain(key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }
}
