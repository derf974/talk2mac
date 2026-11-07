import Foundation

/// Appelle whisper-cli (whisper.cpp) en processus externe.
struct Transcriber {
    let config: Config

    enum Failure: Error, LocalizedError {
        case missing(String), failed(String)
        var errorDescription: String? {
            switch self {
            case .missing(let p): return "Introuvable : \(p)"
            case .failed(let m): return "Whisper a échoué : \(m)"
            }
        }
    }

    func transcribe(_ wav: URL) async throws -> String {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: config.whisperPath) else { throw Failure.missing(config.whisperPath) }
        guard fm.fileExists(atPath: config.modelPath) else { throw Failure.missing(config.modelPath) }

        var args = ["-m", config.modelPath, "-f", wav.path, "-l", config.language, "-nt", "-np"]
        // Contexte audio proportionnel à la durée (50 trames/s) : l'encodeur n'a pas à
        // traiter 30 s de silence. Gain ~40 % sur CPU Intel.
        let bytes = (try? fm.attributesOfItem(atPath: wav.path)[.size] as? Int) ?? 0
        let seconds = Double(max(0, bytes - 44)) / 32000.0
        let ac = min(1500, max(384, Int(seconds * 50) + 150))
        args += ["-ac", String(ac)]
        // Les mots du dictionnaire servent d'indice de vocabulaire à Whisper.
        let hints = Set(config.dictionary.values).sorted()
        if !hints.isEmpty { args += ["--prompt", hints.joined(separator: ", ")] }

        let path = config.whisperPath
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: path)
                p.arguments = args
                let out = Pipe(), err = Pipe()
                p.standardOutput = out
                p.standardError = err
                do { try p.run() } catch { cont.resume(throwing: error); return }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                if p.terminationStatus == 0 {
                    cont.resume(returning: String(decoding: data, as: UTF8.self))
                } else {
                    cont.resume(throwing: Failure.failed(String(decoding: errData.suffix(300), as: UTF8.self)))
                }
            }
        }
    }
}
