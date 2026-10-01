import SwiftUI

/// A small note that a diary is being saved, then that it was: for when the place the diary will appear in
/// is not on screen.
struct DiarySavePill: View {
    let phase: DiarySavePhase

    var body: some View {
        HStack(spacing: DiaryTheme.Spacing.small) {
            switch phase {
            case .saving:
                ProgressView().controlSize(.small)
                Text("저장 중입니다")
            case .saved:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(DiaryTheme.Colors.brand)
                Text("저장 완료!")
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(DiaryTheme.Colors.text)
        .padding(.horizontal, DiaryTheme.Spacing.medium)
        .padding(.vertical, DiaryTheme.Spacing.small)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

/// Stands where a diary being saved will appear: a card of soft blocks with a light passing over them.
struct DiarySavingRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: DiaryTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                PhotoSkeleton(cornerRadius: 6).frame(width: 140, height: 18)
                PhotoSkeleton(cornerRadius: 6).frame(height: 12)
                PhotoSkeleton(cornerRadius: 6).frame(width: 180, height: 12)
                Text("일기를 저장하고 있어요")
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PhotoSkeleton(cornerRadius: DiaryTheme.Spacing.small).frame(width: 64, height: 64)
        }
        .padding(DiaryTheme.Spacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("일기를 저장하고 있어요")
    }
}

#if DEBUG
#Preview("저장 표시") {
    VStack(spacing: DiaryTheme.Spacing.section) {
        DiarySavePill(phase: .saving)
        DiarySavePill(phase: .saved)
        DiarySavingRow()
    }
    .padding()
    .background(DiaryTheme.Colors.background)
}
#endif
