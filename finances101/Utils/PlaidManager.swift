import Foundation
import Security

@Observable
final class PlaidManager {
    static let shared = PlaidManager()

    var isConnected: Bool = false
    var connectedBankName: String = ""

    private static let tokenKey = "com.finances101.plaidAccessToken"
    private static let bankNameKey = "com.finances101.plaidBankName"

    private init() {
        isConnected = Self.readToken() != nil
        connectedBankName = UserDefaults.standard.string(forKey: Self.bankNameKey) ?? ""
    }

    func saveConnection(accessToken: String, bankName: String) {
        Self.writeToken(accessToken)
        UserDefaults.standard.set(bankName, forKey: Self.bankNameKey)
        isConnected = true
        connectedBankName = bankName
    }

    func disconnect() {
        Self.deleteToken()
        UserDefaults.standard.removeObject(forKey: Self.bankNameKey)
        isConnected = false
        connectedBankName = ""
    }

    func accessToken() -> String? { Self.readToken() }

    // MARK: Keychain

    private static func writeToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: tokenKey, kSecValueData: data]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func readToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tokenKey,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteToken() {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: tokenKey]
        SecItemDelete(query as CFDictionary)
    }
}
