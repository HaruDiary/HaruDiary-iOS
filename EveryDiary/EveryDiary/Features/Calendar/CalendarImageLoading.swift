import UIKit

@MainActor
protocol CalendarImageLoading {
    func image(for url: URL) async -> UIImage?
}
