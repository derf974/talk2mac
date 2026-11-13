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
    private var config = Config.load()
    private lazy var hotkey = HotkeyMonitor(key: config.hotkey)
    private let recorder = AudioRecorder()
    private var busy = false
    private let touchBar = TouchBarIndicator()
    private var hotkeyItem: NSMenuItem!
    private var soundsItem: NSMenuItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon("mic")
        let menu = NSMenu()
        hotkeyItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Définir le raccourci…", action: #selector(changeHotkey), keyEquivalent: "")
        soundsItem = menu.addItem(withTitle: "Retours sonores", action: #selector(toggleSounds), keyEquivalent: "")
        refreshMenu()
        menu.addItem(.separator())
        menu.addItem(withTitle: "À propos de Talk2Mac", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(withTitle: "Ouvrir la configuration", action: #selector(openConfig), keyEquivalent: ",")
        menu.addItem(withTitle: "Recharger la configuration", action: #selector(reload), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        if config.touchBar { touchBar.setup() }
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

    private var hotkeyLabel: String { HotkeyMonitor.label(for: config.hotkey) }

    private func refreshMenu() {
        hotkeyItem.title = "Maintenir \(hotkeyLabel) pour dicter"
        soundsItem.state = config.sounds ? .on : .off
    }

    private func play(_ name: String) {
        guard config.sounds else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    @objc private func toggleSounds() {
        config.sounds.toggle()
        config.save()
        refreshMenu()
        if config.sounds { play(config.doneSound) }
    }

    @objc private func changeHotkey() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Définir le raccourci"
        a.informativeText = "Appuie sur la touche à utiliser en push-to-talk (⌘/⌥/⌃/⇧, fn, F13…). Évite une touche utilisée en dehors de la dictée."
        a.addButton(withTitle: "Annuler")
        hotkey.capture = { [weak self, weak a] key in
            guard let self else { return }
            self.hotkey.capture = nil
            self.config.hotkey = key
            self.config.save()
            self.hotkey.setKey(key)
            self.refreshMenu()
            if let a { NSApp.stopModal(withCode: .OK); a.window.orderOut(nil) }
        }
        let r = a.runModal()
        hotkey.capture = nil
        if r == .OK { play(config.doneSound) }
    }

    private func setIcon(_ name: String) {
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func startRecording() {
        guard !busy else {
            log("appui ignoré : transcription précédente en cours")
            play(config.errorSound); if config.touchBar { touchBar.failed("Patiente…") }
            return
        }
        do { try recorder.start(); setIcon("mic.fill"); play(config.startSound); if config.touchBar { touchBar.recording() }; log("enregistrement démarré") }
        catch { log("erreur micro: \(error)"); notify("Micro : \(error.localizedDescription)") }
    }

    private func stopAndType() {
        guard !busy, let wav = recorder.stop() else { log("relâché sans enregistrement actif"); return }
        busy = true
        play(config.stopSound)
        if config.touchBar { touchBar.transcribing() }
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
                    await MainActor.run { self.play(cfg.doneSound); if cfg.touchBar { self.touchBar.done() } }
                } else {
                    await MainActor.run { self.play(cfg.errorSound); if cfg.touchBar { self.touchBar.failed() } }
                }
            } catch {
                log("erreur: \(error)")
                await MainActor.run { self.play(cfg.errorSound); if cfg.touchBar { self.touchBar.failed("Erreur") }; self.notify(error.localizedDescription) }
            }
            await MainActor.run { self.busy = false; self.setIcon("mic") }
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Talk2Mac",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "Dictée vocale locale (Whisper) qui fonctionne aussi dans une VDI.\nMaintiens \(hotkeyLabel), parle, relâche.")
        ])
    }

    @objc private func openConfig() {
        // Le .json peut être associé à une app inattendue : on force TextEdit.
        if let textEdit = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
            NSWorkspace.shared.open([Config.fileURL], withApplicationAt: textEdit,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(Config.fileURL)
        }
    }
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
