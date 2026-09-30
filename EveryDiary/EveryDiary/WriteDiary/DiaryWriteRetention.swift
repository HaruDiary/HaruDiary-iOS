import UIKit

// Keeps a dismissed editor alive until its one save completion is delivered.
final class DiaryWriteRetention {
    static let shared = DiaryWriteRetention()
    private var retainedEditors: [UIViewController] = []

    func retain(_ editor: UIViewController) {
        retainedEditors.append(editor)
    }

    func release(_ editor: UIViewController) {
        retainedEditors.removeAll { $0 === editor }
    }
}
