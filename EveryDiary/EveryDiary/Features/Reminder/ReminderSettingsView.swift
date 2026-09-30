import SwiftUI
import UIKit

/// Settings › 알림 (mockup 17): the daily reminder to write, its time and weekdays.
struct ReminderSettingsView: View {
    @Bindable var viewModel: ReminderSettingsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.section) {
                card {
                    Toggle(isOn: Binding(get: { viewModel.settings.isOn },
                                         set: { on in Task { await viewModel.setOn(on) } })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("일기 알림 받기")
                                .font(DiaryTheme.Fonts.section)
                                .foregroundStyle(DiaryTheme.Colors.text)
                            Text("일기 쓰는 시간을 알려드려요")
                                .font(DiaryTheme.Fonts.caption)
                                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        }
                    }
                    .tint(DiaryTheme.Colors.brand)
                    .padding(DiaryTheme.Spacing.screen)
                }
                if viewModel.permission == .denied {
                    permissionNotice
                }
                if viewModel.settings.isOn {
                    timeSection
                    repeatSection
                    card {
                        Toggle("오늘 일기를 쓰면 그날은 알리지 않기", isOn: Binding(
                            get: { viewModel.settings.skipWhenWritten },
                            set: { skip in Task { await viewModel.setSkipWhenWritten(skip) } }
                        ))
                        .font(DiaryTheme.Fonts.body)
                        .foregroundStyle(DiaryTheme.Colors.text)
                        .tint(DiaryTheme.Colors.brand)
                        .padding(DiaryTheme.Spacing.screen)
                    }
                    status
                }
            }
            .padding(DiaryTheme.Spacing.screen)
            .animation(.default, value: viewModel.settings.isOn)
        }
        .background(DiaryTheme.Colors.background)
        .task { await viewModel.load() }
        // Coming back from the iPhone Settings app may have changed the permission.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.load() }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
            sectionTitle("알림 시간")
            card {
                DatePicker("알림 시간", selection: Binding(get: { viewModel.time },
                                                         set: { time in Task { await viewModel.setTime(time) } }),
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Like the iOS Reminders repeat row: the current choice opens a menu of common schedules,
    /// and the day buttons below pick any other combination.
    private var repeatSection: some View {
        card {
            VStack(spacing: 0) {
                HStack {
                    Text("반복")
                        .font(DiaryTheme.Fonts.body)
                        .foregroundStyle(DiaryTheme.Colors.text)
                    Spacer()
                    Menu {
                        ForEach(ReminderSettingsViewModel.Preset.allCases, id: \.self) { preset in
                            Button {
                                Task { await viewModel.apply(preset) }
                            } label: {
                                if viewModel.settings.weekdays == preset.weekdays {
                                    Label(preset.title, systemImage: "checkmark")
                                } else {
                                    Text(preset.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.summary)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(DiaryTheme.Fonts.body)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    }
                }
                .padding(DiaryTheme.Spacing.screen)
                Divider().padding(.leading, DiaryTheme.Spacing.screen)
                HStack(spacing: 0) {
                    ForEach(1...7, id: \.self) { weekday in
                        let isOn = viewModel.settings.weekdays.contains(weekday)
                        Button {
                            Task { await viewModel.toggle(weekday: weekday) }
                        } label: {
                            Text(ReminderPlan.weekdayNames[weekday - 1])
                                .font(DiaryTheme.Fonts.caption.weight(.semibold))
                                .foregroundStyle(isOn ? .white : weekdayColor(weekday))
                                .frame(width: 34, height: 34)
                                .background(isOn ? DiaryTheme.Colors.brand : DiaryTheme.Colors.background, in: Circle())
                                .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.touchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(ReminderPlan.weekdayNames[weekday - 1])요일")
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.horizontal, DiaryTheme.Spacing.small)
                .padding(.vertical, DiaryTheme.Spacing.small)
                .animation(.easeOut(duration: 0.15), value: viewModel.settings.weekdays)
            }
        }
    }

    /// Unselected Sunday/Saturday keep the calendar's red/blue so the week reads at a glance.
    private func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: return DiaryTheme.Colors.holiday
        case 7: return DiaryTheme.Colors.saturday
        default: return DiaryTheme.Colors.secondaryText
        }
    }

    @ViewBuilder
    private var status: some View {
        if let text = viewModel.nextReminderText {
            Label(text, systemImage: "bell")
                .font(DiaryTheme.Fonts.caption)
                .foregroundStyle(DiaryTheme.Colors.brand)
                .padding(.horizontal, DiaryTheme.Spacing.small)
        } else if viewModel.settings.weekdays.isEmpty {
            Text("요일을 하나 이상 선택하면 알려드려요.")
                .font(DiaryTheme.Fonts.caption)
                .foregroundStyle(DiaryTheme.Colors.error)
                .padding(.horizontal, DiaryTheme.Spacing.small)
        }
    }

    private var permissionNotice: some View {
        card {
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                Label("iPhone 설정에서 하루일기 알림이 꺼져 있어요", systemImage: "bell.slash")
                    .font(DiaryTheme.Fonts.body)
                    .foregroundStyle(DiaryTheme.Colors.text)
                Button("설정에서 허용하기") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .font(DiaryTheme.Fonts.body.weight(.semibold))
                .foregroundStyle(DiaryTheme.Colors.brand)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DiaryTheme.Spacing.screen)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(DiaryTheme.Fonts.section)
            .foregroundStyle(DiaryTheme.Colors.text)
            .padding(.horizontal, DiaryTheme.Spacing.small)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
    }
}
