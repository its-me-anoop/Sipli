import Foundation

/// Only label evidence proposes package size. Consumption always needs a separate choice.
struct ScanDraft: Equatable {
    enum Portion: String, CaseIterable { case all = "All", half = "Half", custom = "Custom" }
    var fluidType: FluidType = .other
    var packageML: Double?
    var evidence: String = ""
    var needsReview = true
    var method: String = ""

    static func validML(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (10...5000).contains(value) else { return nil }
        return value
    }

    static func consumedML(portion: Portion?, packageML: Double?, customML: Double?) -> Double? {
        switch portion {
        case .all: return validML(packageML)
        case .half: return validML(packageML.flatMap(validML).map { $0 / 2 })
        case .custom: return validML(customML)
        case nil: return nil
        }
    }

    /// Strict whole-string parsing; locale decimals are accepted, grouping and mixed units aren't.
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let decimal = locale.decimalSeparator ?? "."
        let escaped = NSRegularExpression.escapedPattern(for: decimal)
        guard trimmed.range(of: "^\\d{1,5}(?:" + escaped + "\\d{1,2})?$", options: .regularExpression) != nil else { return nil }
        return Double(trimmed.replacingOccurrences(of: decimal, with: "."))
    }
}

enum ScanLabelEvidence {
    struct Candidate: Equatable { let ml: Double; let line: String }

    static func candidates(in text: String) -> [Candidate] {
        let pattern = #"(?<![\p{L}\p{N}.,−-])(\d{1,4}(?:[.,]\d{1,2})?)\s*(ml|millilit(?:er|re)s?|cl|centilit(?:er|re)s?|l|lit(?:er|re)s?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return text.components(separatedBy: .newlines).flatMap { line -> [Candidate] in
            let lower = line.lowercased()
            // Nutrition/serving figures are not package capacity. Multipacks need manual review.
            let exclusions = ["per ", "pour ", "por ", "pro ", "par ", "nutrition", "serving", "portion", "100ml", "100 ml", "100mℓ", "每", "栄養"]
            guard !exclusions.contains(where: lower.contains),
                  lower.range(of: #"\d\s*[x×]\s*\d"#, options: .regularExpression) == nil else { return [] }
            let ns = line as NSString
            return regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { match in
                let value = ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                let unit = ns.substring(with: match.range(at: 2)).lowercased()
                guard let n = Double(value) else { return nil }
                let ml = n * (unit == "cl" || unit.hasPrefix("centi") ? 10 : unit == "l" || unit.hasPrefix("lit") ? 1000 : 1)
                guard let valid = ScanDraft.validML(ml) else { return nil }
                return Candidate(ml: valid, line: line)
            }
        }
    }

    static func verifiedCapacity(label: String?, evidence: String?, ocr: String, confident: Bool, labelled: Bool) -> Double? {
        guard confident, labelled, let label, let evidence, !evidence.isEmpty,
              ocr.localizedCaseInsensitiveContains(evidence) else { return nil }
        let all = candidates(in: ocr)
        guard let candidate = candidates(in: label).first,
              all.contains(where: { abs($0.ml - candidate.ml) < 0.01 }),
              candidates(in: evidence).contains(where: { abs($0.ml - candidate.ml) < 0.01 }),
              !all.contains(where: { abs($0.ml - candidate.ml) > 1 }) else { return nil }
        return candidate.ml
    }
}

/// The view owns one gate per scan. It claims a commit before invoking the only diary write.
@MainActor
final class ScanLogGate {
    private(set) var entry: HydrationEntry?
    private var claimed = false
    func log(volumeML: Double?, type: FluidType, write: (Double, FluidType) -> HydrationEntry) -> HydrationEntry? {
        guard !claimed, let ml = ScanDraft.validML(volumeML) else { return nil }
        claimed = true
        let result = write(ml, type)
        entry = result
        return result
    }
    func undo(remove: (HydrationEntry) -> Void) {
        guard let entry else { return }
        self.entry = nil
        remove(entry)
        // Keep claimed true: Undo must not turn repeated Log taps into another write.
    }
}
