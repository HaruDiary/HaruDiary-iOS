import SwiftUI

/// Floating button that opens the diary editor. Shared by the list and calendar screens.
/// Uses the original `write` artwork and sits where the journey tab's write button does.
struct DiaryWriteButton: View {
    /// "writeLight" over the journey tab's picture. Nil picks by the appearance: the dark button would
    /// disappear on a dark screen, so dark mode uses the light one too.
    var image: String? = nil
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(image ?? (colorScheme == .dark ? "writeLight" : "write"))
                .resizable()
                .frame(width: DiaryTheme.Size.floatingButton, height: DiaryTheme.Size.floatingButton)
                .shadow(color: .black.opacity(0.3), radius: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("일기 작성")
        .padding(.trailing, DiaryTheme.Size.floatingButtonTrailing)
        .padding(.bottom, DiaryTheme.Size.floatingButtonBottom)
    }
}
