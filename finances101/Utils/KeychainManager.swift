import Foundation
import Security

enum KeychainManager {
    private static let wifePINKey = "com.finances101.wifePIN"

    static func saveWifePIN(_ pin: String) {
        let data = Data(pin.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: wifePINKey,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getWifePIN() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: wifePINKey,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteWifePIN() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: wifePINKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hasWifePIN() -> Bool {
        getWifePIN() != nil
    }

    static func verifyWifePIN(_ pin: String) -> Bool {
        getWifePIN() == pin
    }
}
