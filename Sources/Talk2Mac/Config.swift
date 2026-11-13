import Foundation

/// Configuration, chargée depuis ~/Library/Application Support/Talk2Mac/config.json
/// (créée avec les valeurs par défaut au premier lancement).
struct Config: Codable {
    /// Touche push-to-talk : rightCommand, leftCommand, rightOption, leftOption, rightControl,
    /// leftControl, rightShift, leftShift, fn, ou "key:<keyCode>" pour une autre touche (ex. F13).
    /// Le plus simple : menu > « Définir le raccourci… ».
    var hotkey = "rightCommand"
    /// "auto", "fr" ou "en"
    var language = "auto"
    var whisperPath = "/usr/local/bin/whisper-cli"
    var modelPath = ""
    /// Délai entre deux blocs de frappe (ms). À augmenter si la VDI perd des caractères.
    var keyDelayMs = 8
    /// Nombre de caractères envoyés par événement clavier.
    var chunkSize = 1
    /// Mots parasites retirés de la transcription.
    var fillers = ["euh", "euhh", "heu", "hum", "hmm", "mmh", "ben euh", "uh", "um", "uhm", "erm"]
    /// Remplacements (mot entendu -> mot voulu), insensible à la casse.
    var dictionary: [String: String] = [:]
    /// Retours sonores (utile dans une VDI où l'on ne voit pas l'icône de la barre de menus).
    var sounds = true
    /// Indicateur visuel sur la Touch Bar (sans effet si le Mac n'en a pas).
    var touchBar = true
    /// Noms de sons système (Tink, Pop, Glass, Basso, Ping, Hero, Funk, Submarine…).
    var startSound = "Tink"
    var stopSound = "Pop"
    /// Joué quand le texte vient d'être tapé.
    var doneSound = "Glass"
    /// Joué en cas d'erreur ou quand rien n'a été compris.
    var errorSound = "Basso"

    init() {}

    /// Décodage tolérant : les clés absentes gardent leur valeur par défaut.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? d.hotkey
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        whisperPath = try c.decodeIfPresent(String.self, forKey: .whisperPath) ?? d.whisperPath
        modelPath = try c.decodeIfPresent(String.self, forKey: .modelPath) ?? d.modelPath
        keyDelayMs = try c.decodeIfPresent(Int.self, forKey: .keyDelayMs) ?? d.keyDelayMs
        chunkSize = try c.decodeIfPresent(Int.self, forKey: .chunkSize) ?? d.chunkSize
        fillers = try c.decodeIfPresent([String].self, forKey: .fillers) ?? d.fillers
        dictionary = try c.decodeIfPresent([String: String].self, forKey: .dictionary) ?? d.dictionary
        sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? d.sounds
        touchBar = try c.decodeIfPresent(Bool.self, forKey: .touchBar) ?? d.touchBar
        startSound = try c.decodeIfPresent(String.self, forKey: .startSound) ?? d.startSound
        stopSound = try c.decodeIfPresent(String.self, forKey: .stopSound) ?? d.stopSound
        doneSound = try c.decodeIfPresent(String.self, forKey: .doneSound) ?? d.doneSound
        errorSound = try c.decodeIfPresent(String.self, forKey: .errorSound) ?? d.errorSound
    }

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Talk2Mac", isDirectory: true)
    }
    static var fileURL: URL { directory.appendingPathComponent("config.json") }

    static func load() -> Config {
        var cfg = Config()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Config.self, from: data) {
            cfg = decoded
        } else {
            cfg.save()
        }
        if cfg.modelPath.isEmpty {
            cfg.modelPath = directory.appendingPathComponent("ggml-small-q5_1.bin").path
        }
        // Repli sur les ressources embarquées dans l'app (build packagé avec --bundle).
        let fm = FileManager.default
        if !fm.isExecutableFile(atPath: cfg.whisperPath),
           let p = Bundle.main.path(forResource: "whisper-cli", ofType: nil) {
            cfg.whisperPath = p
        }
        if !fm.fileExists(atPath: cfg.modelPath),
           let p = Bundle.main.path(forResource: "ggml-small-q5_1", ofType: "bin") {
            cfg.modelPath = p
        }
        return cfg
    }

    func save() {
        try? FileManager.default.createDirectory(at: Config.directory, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) { try? data.write(to: Config.fileURL) }
    }
}
