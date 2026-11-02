import Foundation

/// The rule for anything the on-device model writes: it describes, it never counts.
///
/// Every number on screen comes from Vision, so a reply with a digit in it is dropped, not shown.
public enum ModelText {
    public static func withoutNumbers(_ reply: String) -> String? {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }
        return text
    }
}
