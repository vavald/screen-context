/// Watches modifier-key changes for the Hotkey: left ⌘ and right ⌘ held down together.
public struct HotkeyDetector {
    // NX_DEVICELCMDKEYMASK | NX_DEVICERCMDKEYMASK
    private static let bothCommands: UInt = 0x08 | 0x10
    // NSEvent.ModifierFlags .shift | .control | .option
    private static let otherModifiers: UInt = 0x2_0000 | 0x4_0000 | 0x8_0000
    private var isHeld = false

    public init() {}

    /// Feed every modifier change (NSEvent.modifierFlags.rawValue); true means "take a Capture now".
    public mutating func handle(flags: UInt) -> Bool {
        let wasHeld = isHeld
        isHeld = flags & Self.bothCommands == Self.bothCommands && flags & Self.otherModifiers == 0
        return isHeld && !wasHeld
    }
}
