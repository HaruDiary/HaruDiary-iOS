import SwiftUI

/// Reminder settings inside settings' navigation stack.
struct ReminderSettingsScreen: View {
    @State private var model: Once<ReminderSettingsViewModel>

    init(reminders: DiaryReminders?) {
        _model = State(initialValue: Once { ReminderModule.makeSettingsViewModel(reminders: reminders) })
    }

    var body: some View {
        ReminderSettingsView(viewModel: model.value)
            .navigationTitle("알림")
            .navigationBarTitleDisplayMode(.inline)
    }
}
