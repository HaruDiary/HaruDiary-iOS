import SwiftUI

/// Lock settings inside settings' navigation stack.
struct LockSettingsScreen: View {
    @State private var model = Once { LockModule.makeSettingsViewModel() }

    var body: some View {
        LockSettingsView(viewModel: model.value)
            .navigationTitle("잠금")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Setting the app passcode, offered after unlocking with the earlier biometrics-only lock.
struct PasscodeSetupSheet: View {
    let onClose: () -> Void
    @State private var model = Once { PasscodeFlowViewModel(purpose: .create, lock: LockModule.makeLock()) }

    var body: some View {
        PasscodeFlowView(viewModel: model.value, onClose: onClose)
            .interactiveDismissDisabled()
    }
}
