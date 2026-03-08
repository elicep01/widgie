import AppKit
import Carbon.HIToolbox

struct HotkeyRegistration: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var displayName: String
}

final class GlobalHotkeyListener {
    typealias Handler = () -> Void

    var onTrigger: Handler?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let primaryID = UInt32(1)
    private let signature: OSType = 0x57464745
    private var registration: HotkeyRegistration
    private var lastTriggerDate: Date = .distantPast
    private let minimumTriggerInterval: TimeInterval = 0.35
    private(set) var isRunning = false

    // Extra global hotkeys
    private struct ExtraHotkey {
        let id: UInt32
        let keyCode: UInt32
        let modifiers: UInt32
        let handler: Handler
        var ref: EventHotKeyRef?
    }

    private var extras: [ExtraHotkey] = []
    private var nextExtraID: UInt32 = 10

    init(registration: HotkeyRegistration) {
        self.registration = registration
    }

    func updateRegistration(_ registration: HotkeyRegistration) {
        guard self.registration != registration else {
            return
        }

        self.registration = registration
        if isRunning {
            stop()
            start()
        }
    }

    /// Register an additional global hotkey. Call before or after start().
    func registerExtra(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) {
        let id = nextExtraID
        nextExtraID += 1
        var extra = ExtraHotkey(id: id, keyCode: keyCode, modifiers: modifiers, handler: handler)

        if isRunning {
            var ref: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: signature, id: id)
            let status = RegisterEventHotKey(keyCode, modifiers, identifier, GetApplicationEventTarget(), 0, &ref)
            if status == noErr {
                extra.ref = ref
            }
        }

        extras.append(extra)
    }

    func start() {
        guard !isRunning else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }

                var pressedHotKeyID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedHotKeyID
                )

                guard parameterStatus == noErr else {
                    return parameterStatus
                }

                let listener = Unmanaged<GlobalHotkeyListener>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                guard pressedHotKeyID.signature == listener.signature else {
                    return noErr
                }

                let now = Date()
                guard now.timeIntervalSince(listener.lastTriggerDate) >= listener.minimumTriggerInterval else {
                    return noErr
                }
                listener.lastTriggerDate = now

                if pressedHotKeyID.id == listener.primaryID {
                    listener.onTrigger?()
                } else if let extra = listener.extras.first(where: { $0.id == pressedHotKeyID.id }) {
                    extra.handler()
                }

                return noErr
            },
            1,
            &eventSpec,
            userData,
            &eventHandler
        )

        guard installStatus == noErr else {
            stop()
            return
        }

        // Register primary hotkey
        let identifier = EventHotKeyID(signature: signature, id: primaryID)
        let registerStatus = RegisterEventHotKey(
            registration.keyCode,
            registration.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        isRunning = registerStatus == noErr

        if !isRunning {
            stop()
            return
        }

        // Register extra hotkeys
        for i in extras.indices {
            var ref: EventHotKeyRef?
            let extraID = EventHotKeyID(signature: signature, id: extras[i].id)
            let status = RegisterEventHotKey(
                extras[i].keyCode,
                extras[i].modifiers,
                extraID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr {
                extras[i].ref = ref
            }
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        for extra in extras {
            if let ref = extra.ref {
                UnregisterEventHotKey(ref)
            }
        }
        for i in extras.indices {
            extras[i].ref = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        isRunning = false
    }

    deinit {
        stop()
    }
}
