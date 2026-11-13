import AppKit

/// Affiche l'état (enregistrement / transcription / terminé / erreur) sur la Touch Bar.
/// L'app n'a jamais le focus (c'est une app de barre de menus) : on utilise la Touch Bar
/// « modale système » via les sélecteurs privés d'AppKit. Sans Touch Bar, tout est sans effet.
final class TouchBarIndicator: NSObject, NSTouchBarDelegate {
    private static let itemId = NSTouchBarItem.Identifier("fr.talk2mac.status")
    private let label = NSTextField(labelWithString: "")
    private let box = NSView()
    private lazy var bar: NSTouchBar = {
        let b = NSTouchBar()
        b.delegate = self
        b.defaultItemIdentifiers = [Self.itemId]
        return b
    }()
    private static let trayId = NSTouchBarItem.Identifier("fr.talk2mac.tray")
    private let trayButton = NSButton(title: "", target: nil, action: nil)
    private var blink: Timer?
    private var hideWork: DispatchWorkItem?
    private var shown = false

    /// Enregistre une icône dans la Control Strip (toujours visible) ; à appeler au lancement.
    func setup() {
        typealias PresenceFn = @convention(c) (NSString, Bool) -> Void
        typealias CloseBoxFn = @convention(c) (Bool) -> Void
        guard let h = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW) else {
            log("Touch Bar : DFRFoundation introuvable"); return
        }
        if let sym = dlsym(h, "DFRSystemModalShowsCloseBoxWhenFrontMost") {
            unsafeBitCast(sym, to: CloseBoxFn.self)(false)
        }
        trayButton.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
        trayButton.imagePosition = .imageOnly
        trayButton.bezelStyle = .texturedRounded
        let item = NSCustomTouchBarItem(identifier: Self.trayId)
        item.view = trayButton
        let add = Selector(("addSystemTrayItem:"))
        if (NSTouchBarItem.self as AnyObject).responds(to: add) {
            _ = (NSTouchBarItem.self as AnyObject).perform(add, with: item)
        } else { log("Touch Bar : addSystemTrayItem indisponible") }
        if let sym = dlsym(h, "DFRElementSetControlStripPresenceForIdentifier") {
            unsafeBitCast(sym, to: PresenceFn.self)(Self.trayId.rawValue as NSString, true)
        } else { log("Touch Bar : presence indisponible") }
        log("Touch Bar : icône Control Strip installée")
    }

    private func tint(_ c: NSColor?) { trayButton.bezelColor = c; trayButton.contentTintColor = c == nil ? nil : .white }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier id: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard id == Self.itemId else { return nil }
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        box.wantsLayer = true
        box.layer?.cornerRadius = 6
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            box.heightAnchor.constraint(equalToConstant: 30),
        ])
        let item = NSCustomTouchBarItem(identifier: id)
        item.view = box
        return item
    }

    private func show(_ text: String, color: NSColor, autoHideAfter: TimeInterval? = nil) {
        hideWork?.cancel(); blink?.invalidate(); blink = nil
        _ = bar  // force la création des items
        label.stringValue = text
        tint(color)
        box.layer?.backgroundColor = color.cgColor
        if !shown { present(); shown = true }
        if let s = autoHideAfter {
            let w = DispatchWorkItem { [weak self] in self?.hide() }
            hideWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: w)
        }
    }

    func recording() {
        show("●  Enregistrement…", color: .systemRed)
        var on = true
        blink = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            on.toggle()
            self?.label.stringValue = on ? "●  Enregistrement…" : "○  Enregistrement…"
        }
    }
    func transcribing() { show("Transcription…", color: .systemOrange) }
    func done() { show("✓  Texte envoyé", color: .systemGreen, autoHideAfter: 1.0) }
    func failed(_ text: String = "Rien compris") { show("✕  \(text)", color: .systemGray, autoHideAfter: 1.5) }

    func hide() {
        hideWork?.cancel(); blink?.invalidate(); blink = nil
        guard shown else { return }
        shown = false
        tint(nil)
        dismiss()
    }

    // MARK: API privée
    private typealias PresentFn = @convention(c) (AnyObject, Selector, NSTouchBar, Int, NSString?) -> Void
    private typealias DismissFn = @convention(c) (AnyObject, Selector, NSTouchBar) -> Void

    private func present() {
        let sel = Selector(("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"))
        guard let m = class_getClassMethod(NSTouchBar.self, sel) else { log("Touch Bar : API indisponible"); return }
        let fn = unsafeBitCast(method_getImplementation(m), to: PresentFn.self)
        fn(NSTouchBar.self, sel, bar, 1, Self.trayId.rawValue as NSString)
    }
    private func dismiss() {
        let sel = Selector(("dismissSystemModalTouchBar:"))
        guard let m = class_getClassMethod(NSTouchBar.self, sel) else { return }
        let fn = unsafeBitCast(method_getImplementation(m), to: DismissFn.self)
        fn(NSTouchBar.self, sel, bar)
    }
}
