import Observation
import SwiftUI

/// A short message that leaves by itself: results that need no answer ("moved to trash", "photo not saved").
struct DiaryToastMessage: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var duration: Double = 2.0
}

@MainActor
@Observable
final class DiaryToastCenter {
    private(set) var current: DiaryToastMessage?
    @ObservationIgnored private var dismissal: Task<Void, Never>?

    func show(_ title: String, message: String, duration: Double = 2.0) {
        let toast = DiaryToastMessage(title: title, message: message, duration: duration)
        current = toast
        AccessibilityNotification.Announcement("\(title). \(message)").post()
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissal?.cancel()
        current = nil
    }
}

private struct DiaryToastOverlay: ViewModifier {
    let center: DiaryToastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = center.current {
                VStack(spacing: 2) {
                    Text(toast.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DiaryTheme.Colors.text)
                    Text(toast.message)
                        .font(.footnote)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DiaryTheme.Spacing.section)
                .padding(.vertical, DiaryTheme.Spacing.medium)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(.horizontal, DiaryTheme.Spacing.section)
                .padding(.top, DiaryTheme.Spacing.small)
                .onTapGesture { center.dismiss() }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .id(toast.id)
                .accessibilityElement(children: .combine)
            }
        }
        .animation(.easeOut(duration: 0.25), value: center.current)
    }
}

extension View {
    /// Shows the centre's messages over this view. Each sheet needs its own, since a sheet covers what is under it.
    func diaryToast(_ center: DiaryToastCenter) -> some View {
        modifier(DiaryToastOverlay(center: center))
    }
}
