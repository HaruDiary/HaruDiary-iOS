import Foundation
import Observation

/// Setting, changing or turning off the app passcode from settings: the current passcode first when there is one,
/// then the new passcode twice.
@MainActor
@Observable
final class PasscodeFlowViewModel: Identifiable {
    enum Purpose: Equatable {
        case create
        case change
        case turnOff
    }

    enum Step: Equatable {
        case current
        case new
        case confirm
    }

    let purpose: Purpose
    private(set) var step: Step
    private(set) var digits = ""
    private(set) var message: String?
    /// Increases on every wrong or mismatched entry, so the dots can shake.
    private(set) var mistakes = 0
    private(set) var isDone = false

    private let lock: AppLock
    private var newPasscode: String?

    init(purpose: Purpose, lock: AppLock) {
        self.purpose = purpose
        self.lock = lock
        step = purpose == .create ? .new : .current
    }

    var title: String {
        switch step {
        case .current: return "현재 암호 입력"
        case .new: return "새 암호 입력"
        case .confirm: return "새 암호 다시 입력"
        }
    }

    var waitUntil: Date? { step == .current ? lock.waitUntil : nil }

    func type(_ digit: Int) {
        guard (0...9).contains(digit), digits.count < AppLock.passcodeLength, !isDone, waitUntil == nil else { return }
        digits += String(digit)
        if digits.count == AppLock.passcodeLength { submit() }
    }

    func deleteLast() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }

    private func submit() {
        let entered = digits
        digits = ""
        switch step {
        case .current:
            // Counted like the lock screen, so settings cannot be used to try passcodes without waiting.
            switch lock.unlock(with: entered) {
            case .unlocked:
                message = nil
                if purpose == .turnOff {
                    lock.turnOff()
                    isDone = true
                } else {
                    step = .new
                }
            case .wrong(let tries):
                mistakes += 1
                message = LockMessages.wrong(triesBeforeWait: tries)
            case .wait:
                mistakes += 1
                message = LockMessages.waiting
            }
        case .new:
            newPasscode = entered
            message = nil
            step = .confirm
        case .confirm:
            guard entered == newPasscode else {
                mistakes += 1
                newPasscode = nil
                message = "암호가 일치하지 않아요. 다시 입력해주세요."
                step = .new
                return
            }
            lock.setPasscode(entered)
            isDone = true
        }
    }
}

/// Wording shared by the lock screen and the passcode flow.
enum LockMessages {
    static let waiting = "여러 번 틀려서 잠시 후에 다시 입력할 수 있어요."

    static func wrong(triesBeforeWait: Int) -> String {
        triesBeforeWait <= 2 ? "암호가 틀렸어요. \(triesBeforeWait)번 더 틀리면 잠시 기다려야 해요." : "암호가 틀렸어요."
    }

    static func remaining(until: Date, now: Date) -> String {
        let seconds = max(1, Int(until.timeIntervalSince(now).rounded(.up)))
        return seconds >= 60 ? "\(Int((Double(seconds) / 60).rounded(.up)))분 후에 다시 시도하세요" : "\(seconds)초 후에 다시 시도하세요"
    }
}
