import AppKit
import AVFoundation

func log(_ m: String) {
    let url = Config.directory.appendingPathComponent("log.txt")
    let line = "\(Date()) \(m)\n"
    if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
    else { try? line.write(to: url, atomically: true, encoding: .utf8) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let config = Config.load()
    private lazy var hotkey = HotkeyMonitor(key: config.hotkey)
    private let recorder = AudioRecorder()
    private var busy = false

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon("mic")
        let menu = NSMenu()
        menu.addItem(withTitle: "Maintenir \(config.hotkey) pour dicter", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Ouvrir la configuration", action: #selector(openConfig), keyEquivalent: ",")
        menu.addItem(withTitle: "Recharger la configuration", action: #selector(reload), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)  // nécessaire pour injecter des frappes

        hotkey.onPress = { [weak self] in self?.startRecording() }
        hotkey.onRelease = { [weak self] in self?.stopAndType() }

        // Sans « Surveillance de l'entrée », la touche ne marche qu'avec l'app au premier plan.
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            notify("Talk2Mac doit être autorisé dans Réglages Système > Confidentialité et sécurité > Surveillance de l'entrée (active la case Talk2Mac, ou ajoute l'app avec +), puis quitte et relance Talk2Mac.")
        }
        if !hotkey.start() {
            notify("Impossible d'installer le raccourci global. Vérifie Surveillance de l'entrée, puis relance.")
        }
    }

    private func setIcon(_ name: String) {
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func startRecording() {
        guard !busy else { return }
        do { try recorder.start(); setIcon("mic.fill"); log("enregistrement démarré") }
        catch { log("erreur micro: \(error)"); notify("Micro : \(error.localizedDescription)") }
    }

    private func stopAndType() {
        guard !busy, let wav = recorder.stop() else { return }
        busy = true
        setIcon("ellipsis.circle")
        let size = (try? FileManager.default.attributesOfItem(atPath: wav.path)[.size] as? Int) ?? -1
        log("enregistrement arrêté, wav=\(size) octets, AX=\(AXIsProcessTrusted())")
        let cfg = config
        Task {
            defer { try? FileManager.default.removeItem(at: wav) }
            do {
                let raw = try await Transcriber(config: cfg).transcribe(wav)
                let text = TextCleaner(config: cfg).clean(raw)
                log("brut=\(raw.debugDescription) nettoyé=\(text.debugDescription)")
                if !text.isEmpty {
                    KeyboardInjector(chunkSize: cfg.chunkSize, delayMs: cfg.keyDelayMs).type(text)
                }
            } catch {
                log("erreur: \(error)")
                await MainActor.run { self.notify(error.localizedDescription) }
            }
            await MainActor.run { self.busy = false; self.setIcon("mic") }
        }
    }

    @objc private func openConfig() { NSWorkspace.shared.open(Config.fileURL) }
    @objc private func reload() { notify("Quitte et relance Talk2Mac pour appliquer la configuration.") }

    private func notify(_ msg: String) {
        let a = NSAlert()
        a.messageText = "Talk2Mac"
        a.informativeText = msg
        a.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
