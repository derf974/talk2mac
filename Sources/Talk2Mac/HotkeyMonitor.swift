import CoreGraphics
import Foundation

/// Push-to-talk global : la touche choisie maintenue = enregistrement.
/// La touche est une touche modificatrice (rightCommand, leftOption, fn…) ou n'importe
/// quelle autre touche, notée "key:<keyCode>" (ex. "key:105" = F13).
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// Si défini, la prochaine touche pressée est transmise ici (nom de config) au lieu de déclencher la dictée.
    var capture: ((String) -> Void)?

    private var tap: CFMachPort?
    private var isDown = false
    private var keyCode: Int64
    private var flag: CGEventFlags?  // nil = touche non modificatrice

    static let modifiers: [String: (code: Int64, flag: CGEventFlags, label: String)] = [
        "rightCommand": (54, .maskCommand, "⌘ droite"),
        "leftCommand": (55, .maskCommand, "⌘ gauche"),
        "rightOption": (61, .maskAlternate, "⌥ droite"),
        "leftOption": (58, .maskAlternate, "⌥ gauche"),
        "rightControl": (62, .maskControl, "⌃ droite"),
        "leftControl": (59, .maskControl, "⌃ gauche"),
        "rightShift": (60, .maskShift, "⇧ droite"),
        "leftShift": (56, .maskShift, "⇧ gauche"),
        "fn": (63, .maskSecondaryFn, "fn"),
    ]
    private static let keyLabels: [Int64: String] = [
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 49: "Espace", 36: "Entrée", 48: "Tab",
    ]

    static func label(for key: String) -> String {
        if let m = modifiers[key] { return m.label }
        if key.hasPrefix("key:"), let code = Int64(key.dropFirst(4)) {
            return keyLabels[code] ?? "touche \(code)"
        }
        return key
    }

    init(key: String) {
        if let m = HotkeyMonitor.modifiers[key] {
            keyCode = m.code; flag = m.flag
        } else if key.hasPrefix("key:"), let code = Int64(key.dropFirst(4)) {
            keyCode = code; flag = nil
        } else {
            keyCode = 54; flag = .maskCommand  // rightCommand par défaut
        }
    }

    func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            let code = event.getIntegerValueField(.keyboardEventKeycode)

            if let capture = me.capture {
                var name: String?
                if type == .flagsChanged {
                    if let m = HotkeyMonitor.modifiers.first(where: { $0.value.code == code }),
                       event.flags.contains(m.value.flag) { name = m.key }
                } else if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    name = "key:\(code)"
                }
                if let name { DispatchQueue.main.async { capture(name) } }
                return Unmanaged.passUnretained(event)
            }

            // Relâchement manqué (tap désactivé un instant) : on resynchronise sur n'importe quel événement.
            if me.isDown, let f = me.flag, !event.flags.contains(f) {
                me.isDown = false
                DispatchQueue.main.async { me.onRelease?() }
            }
            guard code == me.keyCode else { return Unmanaged.passUnretained(event) }
            let down: Bool
            if let flag = me.flag {
                guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }
                down = event.flags.contains(flag)
            } else {
                guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
                down = type == .keyDown
            }
            if down && !me.isDown {
                me.isDown = true
                DispatchQueue.main.async { me.onPress?() }
            } else if !down && me.isDown {
                me.isDown = false
                DispatchQueue.main.async { me.onRelease?() }
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        // Garde-fou : macOS peut désactiver le tap sans prévenir.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let tap = self?.tap, !CGEvent.tapIsEnabled(tap: tap) else { return }
            log("tap désactivé, réactivation")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return true
    }

    /// Change la touche push-to-talk à chaud.
    func setKey(_ key: String) {
        let new = HotkeyMonitor(key: key)
        keyCode = new.keyCode; flag = new.flag; isDown = false
    }
}
