import SwiftUI

/// Floating button that opens the diary editor. Shared by the list and calendar screens.
struct DiaryWriteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: DiaryTheme.Size.icon))
                .foregroundStyle(DiaryTheme.Colors.surface)
                .frame(width: DiaryTheme.Size.floatingButton, height: DiaryTheme.Size.floatingButton)
                .background(DiaryTheme.Colors.brand, in: Circle())
                .shadow(color: DiaryTheme.Colors.brand.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel("일기 작성")
    }
}
