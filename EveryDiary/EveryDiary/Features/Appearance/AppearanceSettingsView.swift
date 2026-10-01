import SwiftUI

/// Choosing light or dark; the screen changes as soon as an option is picked.
struct AppearanceSettingsView: View {
    let controller: AppAppearanceController

    var body: some View {
        List {
            Section {
                ForEach(AppAppearance.allCases) { appearance in
                    Button { controller.select(appearance) } label: {
                        HStack(spacing: DiaryTheme.Spacing.medium) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appearance.title)
                                    .font(DiaryTheme.Fonts.body)
                                    .foregroundStyle(DiaryTheme.Colors.text)
                                Text(appearance.detail)
                                    .font(DiaryTheme.Fonts.caption)
                                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                            }
                            Spacer(minLength: 0)
                            if appearance == controller.setting {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(DiaryTheme.Colors.brand)
                            }
                        }
                        .frame(minHeight: DiaryTheme.Size.touchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(appearance == controller.setting ? .isSelected : [])
                }
            } footer: {
                Text("여정의 그림은 화면 모드와 관계없이 같은 색으로 보여요.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DiaryTheme.Colors.background)
        .navigationTitle("화면 모드")
        .navigationBarTitleDisplayMode(.inline)
    }
}
