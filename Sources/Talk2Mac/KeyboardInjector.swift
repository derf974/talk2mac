import CoreGraphics
import Foundation

/// Tape le texte comme un vrai clavier (événements CGEvent), pour passer à travers
/// Windows App / RDP sans dépendre du presse-papiers partagé.
struct KeyboardInjector {
    let chunkSize: Int
    let delayMs: Int

    func type(_ text: String) {
        let src = CGEventSource(stateID: .hidSystemState)
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            if chars[i] == "\n" {
                post(src, keyCode: 36, unicode: nil)  // Return
                i += 1
            } else {
                var j = i
                while j < chars.count, j - i < max(1, chunkSize), chars[j] != "\n" { j += 1 }
                post(src, keyCode: 0, unicode: String(chars[i..<j]))
                i = j
            }
            if delayMs > 0 { usleep(UInt32(delayMs) * 1000) }
        }
    }

    private func post(_ src: CGEventSource?, keyCode: CGKeyCode, unicode: String?) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down) else { continue }
            e.flags = []  // ignore les modifieurs encore enfoncés (Option)
            if let unicode {
                let u = Array(unicode.utf16)
                e.keyboardSetUnicodeString(stringLength: u.count, unicodeString: u)
            }
            e.post(tap: .cghidEventTap)
        }
    }
}
