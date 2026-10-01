import SafariServices
import SwiftUI
import UIKit

/// A view model created once for a screen and kept while the screen lives.
/// (`State(initialValue:)` would build a new one every time the parent view is re-created.)
@MainActor
final class Once<Value> {
    private let make: @MainActor () -> Value
    private(set) lazy var value: Value = make()

    init(_ make: @escaping @MainActor () -> Value) {
        self.make = make
    }
}

/// System sheets that only UIKit can present (Google sign-in) need the view controller on top.
@MainActor
enum TopViewController {
    static func find() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

/// A web page inside the app. SwiftUI has no in-app browser of its own.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = DiaryTheme.Colors.brandUIKit
        return safari
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct WebPage: Identifiable {
    let url: URL
    var id: URL { url }
}
