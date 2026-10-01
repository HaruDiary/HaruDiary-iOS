import SwiftUI
import UIKit

/// Choosing the app's text size, with a sample that changes as soon as an option is picked.
struct TextSizeSettingsView: View {
    let controller: AppTextSizeController

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                    Text("오늘의 일기")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DiaryTheme.Colors.brand)
                    Text("글자 크기를 바꾸면 일기 목록과 내용, 쓰기 화면의 글자가 이 크기로 보여요.")
                        .font(DiaryTheme.Fonts.body)
                        .foregroundStyle(DiaryTheme.Colors.text)
                }
                .padding(.vertical, DiaryTheme.Spacing.small)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("미리보기")
            } header: {
                Text("미리보기")
            }
            Section {
                ForEach(AppTextSize.allCases) { size in
                    Button { controller.select(size) } label: {
                        HStack(spacing: DiaryTheme.Spacing.medium) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(size.title)
                                    .font(DiaryTheme.Fonts.body)
                                    .foregroundStyle(DiaryTheme.Colors.text)
                                Text(size.detail)
                                    .font(DiaryTheme.Fonts.caption)
                                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                            }
                            Spacer(minLength: 0)
                            if size == controller.setting {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(DiaryTheme.Colors.brand)
                            }
                        }
                        .frame(minHeight: DiaryTheme.Size.touchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(size == controller.setting ? .isSelected : [])
                }
            } footer: {
                Text("iPhone 설정의 글자 크기가 더 크면 그 크기로 보여요.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DiaryTheme.Colors.background)
    }
}

// Remove this UIKit bridge when settings push their screens from SwiftUI.
@MainActor
final class TextSizeSettingsHostingController: UIHostingController<TextSizeSettingsView> {
    init(controller: AppTextSizeController) {
        super.init(rootView: TextSizeSettingsView(controller: controller))
        title = "글자 크기"
    }

    required init?(coder: NSCoder) { return nil }
}
