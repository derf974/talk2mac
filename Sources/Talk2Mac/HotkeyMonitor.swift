import CoreGraphics
import Foundation

/// Push-to-talk global : Option droite (keyCode 61) maintenue = enregistrement.
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    private var tap: CFMachPort?
    private var isDown = false
    private var keyCode: Int64 = 54
    private var flag: CGEventFlags = .maskCommand

    init(key: String) {
        switch key {
        case "rightOption":  keyCode = 61; flag = .maskAlternate
        case "rightControl": keyCode = 62; flag = .maskControl
        case "rightShift":   keyCode = 60; flag = .maskShift
        case "fn":           keyCode = 63; flag = .maskSecondaryFn
        default:             keyCode = 54; flag = .maskCommand  // rightCommand
        }
    }

    func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard event.getIntegerValueField(.keyboardEventKeycode) == me.keyCode else {
                return Unmanaged.passUnretained(event)
            }
            let down = event.flags.contains(me.flag)
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
        return true
    }
}
