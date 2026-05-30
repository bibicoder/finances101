import UIKit
import LinkKit

@MainActor
enum PlaidLinkPresenter {
    private static var activeHandler: Handler?

    static func open(
        token: String,
        onSuccess: @escaping (String, String) -> Void,
        onExit: @escaping () -> Void
    ) {
        var config = LinkTokenConfiguration(token: token) { success in
            let bankName = success.metadata.institution.name
            activeHandler = nil
            onSuccess(success.publicToken, bankName)
        }
        config.onExit = { (_: LinkExit) in
            activeHandler = nil
            onExit()
        }

        switch Plaid.create(config) {
        case .success(let handler):
            activeHandler = handler
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            var top = root
            while let presented = top.presentedViewController { top = presented }
            handler.open(presentUsing: PresentationMethod.viewController(top))
        case .failure(let error):
            print("PlaidLink error: \(error)")
            onExit()
        }
    }
}
