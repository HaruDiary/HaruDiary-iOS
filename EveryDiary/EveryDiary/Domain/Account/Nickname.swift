import Foundation

/// The name shown on the profile. Apple sends a name only on the first sign-in, so users set their own.
enum Nickname {
    static let maxLength = 20

    enum Problem: Error, Equatable {
        case empty
        case tooLong
    }

    /// Trims surrounding spaces and line breaks; 1...20 characters as the user sees them.
    static func validated(_ text: String) throws -> String {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Problem.empty }
        guard name.count <= maxLength else { throw Problem.tooLong }
        return name
    }
}
