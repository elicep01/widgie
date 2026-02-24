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
    private let hotKeyID = UInt32(1)
    private let signature: OSType = 0x57464745
    private var registration: HotkeyRegistration
    private var lastTriggerDate: Date = .distantPast
    private let minimumTriggerInterval: TimeInterval = 0.35
    private(set) var isRunning = false

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

                if pressedHotKeyID.signature == listener.signature,
                   pressedHotKeyID.id == listener.hotKeyID {
                    let now = Date()
                    guard now.timeIntervalSince(listener.lastTriggerDate) >= listener.minimumTriggerInterval else {
                        return noErr
                    }
                    listener.lastTriggerDate = now
                    listener.onTrigger?()
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

        let identifier = EventHotKeyID(signature: signature, id: hotKeyID)
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
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
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
