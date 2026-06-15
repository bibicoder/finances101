import Foundation
import Security
import CryptoKit

enum KeychainManager {
    private static let wifePINKey = "com.finances101.wifePIN"

    // PINs are stored as SHA-256 hashes, never as plaintext.
    private static func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func saveWifePIN(_ pin: String) {
        let data = Data(hash(pin).utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: wifePINKey,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func storedValue() -> String? {
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
        storedValue() != nil
    }

    static func verifyWifePIN(_ pin: String) -> Bool {
        guard let stored = storedValue() else { return false }
        if stored == hash(pin) { return true }
        // Legacy migration: older versions stored the PIN as plaintext.
        if stored == pin {
            saveWifePIN(pin)  // upgrade to hashed storage
            return true
        }
        return false
    }
}
