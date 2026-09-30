import SwiftUI

/// The four passcode dots; they shake when `mistakes` grows.
struct PasscodeDots: View {
    let filled: Int
    let mistakes: Int

    var body: some View {
        HStack(spacing: DiaryTheme.Lock.dotSpacing) {
            ForEach(0..<AppLock.passcodeLength, id: \.self) { index in
                Circle()
                    .fill(index < filled ? DiaryTheme.Colors.brand : .clear)
                    .overlay(Circle().stroke(DiaryTheme.Colors.brand, lineWidth: 1.5))
                    .frame(width: DiaryTheme.Lock.dotSize, height: DiaryTheme.Lock.dotSize)
            }
        }
        .modifier(Shake(travel: CGFloat(mistakes)))
        .animation(.linear(duration: 0.4), value: mistakes)
        .accessibilityElement()
        .accessibilityLabel("암호 \(AppLock.passcodeLength)자리 중 \(filled)자리 입력")
    }
}

private struct Shake: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(travel * .pi * 4), y: 0))
    }
}

/// A number pad in the iPhone passcode layout. `corner` fills the empty key left of 0, e.g. with Face ID.
struct PasscodeKeypad<Corner: View>: View {
    let isDisabled: Bool
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    @ViewBuilder let corner: () -> Corner

    var body: some View {
        Grid(horizontalSpacing: DiaryTheme.Lock.keySpacing, verticalSpacing: DiaryTheme.Lock.keySpacing) {
            ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digitKey($0) }
                }
            }
            GridRow {
                // Color.clear keeps the cell when there is no corner key, so 0 stays in the middle column.
                ZStack { Color.clear; corner() }
                    .frame(width: DiaryTheme.Lock.keySize, height: DiaryTheme.Lock.keySize)
                digitKey(0)
                Button(action: onDelete) {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .foregroundStyle(DiaryTheme.Colors.brand)
                        .frame(width: DiaryTheme.Lock.keySize, height: DiaryTheme.Lock.keySize)
                }
                .accessibilityLabel("지우기")
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }

    private func digitKey(_ digit: Int) -> some View {
        Button {
            onDigit(digit)
        } label: {
            Text("\(digit)")
                .font(DiaryTheme.Lock.keyFont)
                .foregroundStyle(DiaryTheme.Colors.text)
                .frame(width: DiaryTheme.Lock.keySize, height: DiaryTheme.Lock.keySize)
                .background(DiaryTheme.Colors.surface, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

extension PasscodeKeypad where Corner == EmptyView {
    init(isDisabled: Bool, onDigit: @escaping (Int) -> Void, onDelete: @escaping () -> Void) {
        self.init(isDisabled: isDisabled, onDigit: onDigit, onDelete: onDelete, corner: { EmptyView() })
    }
}

extension Biometry {
    var symbolName: String {
        switch self {
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .faceID, .none: return "faceid"
        }
    }
}
