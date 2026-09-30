import SwiftUI

/// Picking the diary's day (mockup 06). Future days cannot be picked, as before.
struct DiaryDateSheet: View {
    let onDone: (Date) -> Void
    @State private var selection: Date
    @Environment(\.dismiss) private var dismiss

    init(date: Date, onDone: @escaping (Date) -> Void) {
        self.onDone = onDone
        _selection = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: DiaryTheme.Spacing.medium) {
            Text("날짜 선택")
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.text)
                .padding(.top, DiaryTheme.Spacing.section)
            DatePicker("날짜", selection: $selection, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .tint(DiaryTheme.Colors.brand)
            DiarySheetButton(title: "선택 완료") {
                onDone(selection)
                dismiss()
            }
        }
        .padding(.horizontal, DiaryTheme.Spacing.screen)
        .padding(.bottom, DiaryTheme.Spacing.small)
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

/// A named grid of moods (mockup 07) or weathers (mockup 08). Tapping a choice selects it at once.
struct DiaryConditionSheet<Icon: View>: View {
    let title: String
    let conditions: [DiaryCondition]
    @Binding var selection: String
    @ViewBuilder let icon: (DiaryCondition) -> Icon
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DiaryTheme.Spacing.small), count: 4)

    var body: some View {
        VStack(spacing: DiaryTheme.Spacing.section) {
            Text(title)
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.text)
                .padding(.top, DiaryTheme.Spacing.section)
            LazyVGrid(columns: columns, spacing: DiaryTheme.Spacing.screen) {
                ForEach(conditions) { condition in
                    let isSelected = condition.value == selection
                    Button {
                        selection = condition.value
                    } label: {
                        VStack(spacing: 6) {
                            icon(condition)
                                .frame(width: 34, height: 34)
                                .frame(width: 60, height: 60)
                                .background(isSelected ? DiaryTheme.Colors.brand.opacity(0.16) : .clear, in: Circle())
                                .overlay {
                                    Circle().strokeBorder(isSelected ? DiaryTheme.Colors.brand : .clear, lineWidth: 2)
                                }
                            Text(condition.label)
                                .font(.footnote.weight(isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? DiaryTheme.Colors.brand : DiaryTheme.Colors.text)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(condition.label)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            Spacer(minLength: 0)
            DiarySheetButton(title: "완료") { dismiss() }
        }
        .padding(.horizontal, DiaryTheme.Spacing.screen)
        .padding(.bottom, DiaryTheme.Spacing.small)
        .presentationDetents([.height(conditions.count > 10 ? 560 : 480), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

struct DiarySheetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: DiaryTheme.SignIn.buttonHeight)
                .background(DiaryTheme.Colors.brand, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        }
        .buttonStyle(.plain)
    }
}
