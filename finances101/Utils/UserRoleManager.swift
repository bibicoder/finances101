import Foundation
import Observation

enum UserRole {
    case owner
    case viewer
}

enum DeviceRole: String {
    case owner = "owner"
    case familyMember = "familyMember"
    case unset = ""
}

@Observable
final class UserRoleManager {
    private static let lastRoleKey = "lastSelectedRole"
    private static let deviceRoleKey = "deviceRole"

    var currentRole: UserRole = .owner
    var isLockScreenShown: Bool = false
    var deviceRole: DeviceRole = .unset

    var canEdit: Bool { currentRole == .owner }
    var needsDeviceSetup: Bool { deviceRole == .unset }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.deviceRoleKey) ?? ""
        deviceRole = DeviceRole(rawValue: saved) ?? .unset

        switch deviceRole {
        case .familyMember:
            // This is a family member's phone — always viewer, no PIN ever
            currentRole = .viewer
            isLockScreenShown = false

        case .owner:
            let hasPIN = KeychainManager.hasWifePIN()
            let lastRole = UserDefaults.standard.string(forKey: Self.lastRoleKey)
            if !hasPIN {
                currentRole = .owner
                isLockScreenShown = false
            } else if lastRole == "viewer" {
                currentRole = .viewer
                isLockScreenShown = false
            } else {
                currentRole = .owner
                isLockScreenShown = true
            }

        case .unset:
            // First launch — deviceSetup screen will show
            currentRole = .owner
            isLockScreenShown = false
        }
    }

    func completeDeviceSetup(as role: DeviceRole) {
        deviceRole = role
        UserDefaults.standard.set(role.rawValue, forKey: Self.deviceRoleKey)

        if role == .familyMember {
            currentRole = .viewer
            isLockScreenShown = false
            saveRole()
        } else if role == .unset {
            // User tapped "Change Device Role" — hide lock screen while setup screen is visible
            isLockScreenShown = false
        } else {
            currentRole = .owner
            isLockScreenShown = KeychainManager.hasWifePIN()
        }
    }

    func unlockAsOwner() {
        currentRole = .owner
        isLockScreenShown = false
        saveRole()
    }

    func unlockAsViewer() {
        currentRole = .viewer
        isLockScreenShown = false
        saveRole()
    }

    func resetToLock() {
        guard deviceRole == .owner else { return }
        if KeychainManager.hasWifePIN() {
            currentRole = .owner
            isLockScreenShown = true
        }
    }

    private func saveRole() {
        UserDefaults.standard.set(currentRole == .viewer ? "viewer" : "owner", forKey: Self.lastRoleKey)
    }
}
