import Foundation
import Observation

enum UserRole {
    case owner
    case viewer
}

@Observable
final class UserRoleManager {
    var currentRole: UserRole = .owner
    var isLockScreenShown: Bool = KeychainManager.hasWifePIN()

    var canEdit: Bool { currentRole == .owner }

    func unlockAsOwner() {
        currentRole = .owner
        isLockScreenShown = false
    }

    func unlockAsViewer() {
        currentRole = .viewer
        isLockScreenShown = false
    }

    // Call when app goes to background — re-shows role picker on next open
    func resetToLock() {
        if KeychainManager.hasWifePIN() {
            currentRole = .owner
            isLockScreenShown = true
        }
    }
}
