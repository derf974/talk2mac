import Foundation

/// Nettoyage simple (sans LLM) : retire les mots parasites, applique le dictionnaire,
/// normalise les espaces et la majuscule initiale.
struct TextCleaner {
    let config: Config

    func clean(_ raw: String) -> String {
        var t = raw
            .replacingOccurrences(of: "\n", with: " ")
            // Annotations Whisper type [BLANK_AUDIO], (musique)
            .replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: " ", options: .regularExpression)

        // Mots parasites, éventuellement suivis d'une virgule.
        for f in config.fillers.sorted(by: { $0.count > $1.count }) {
            let pat = #"(?<![\p{L}])"# + NSRegularExpression.escapedPattern(for: f) + #"(?![\p{L}])[,.]?"#
            t = t.replacingOccurrences(of: pat, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        // Dictionnaire perso.
        for (heard, wanted) in config.dictionary {
            let pat = #"(?<![\p{L}])"# + NSRegularExpression.escapedPattern(for: heard) + #"(?![\p{L}])"#
            t = t.replacingOccurrences(of: pat, with: NSRegularExpression.escapedTemplate(for: wanted),
                                       options: [.regularExpression, .caseInsensitive])
        }
        // Espaces / ponctuation.
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+([,.])"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"^[\s,;.]+"#, with: "", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = t.first { t = first.uppercased() + t.dropFirst() }
        return t
    }
}
