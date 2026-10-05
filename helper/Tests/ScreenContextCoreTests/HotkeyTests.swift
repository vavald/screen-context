import Testing
import ScreenContextCore

// Device-dependent modifier bits as macOS reports them in NSEvent.modifierFlags.rawValue.
let leftCommand: UInt = 0x0010_0008
let rightCommand: UInt = 0x0010_0010
let bothCommands: UInt = 0x0010_0018

@Test func firesWhenRightCommandJoinsAHeldLeftCommand() {
    var hotkey = HotkeyDetector()
    #expect(hotkey.handle(flags: leftCommand) == false)
    #expect(hotkey.handle(flags: bothCommands) == true)
}

@Test func firesOncePerPressAndAgainAfterRelease() {
    var hotkey = HotkeyDetector()
    #expect(hotkey.handle(flags: bothCommands) == true)
    #expect(hotkey.handle(flags: bothCommands) == false)
    #expect(hotkey.handle(flags: leftCommand) == false)
    #expect(hotkey.handle(flags: bothCommands) == true)
}

@Test func ignoresBothCommandsWhileShiftIsHeld() {
    var hotkey = HotkeyDetector()
    let shift: UInt = 0x0002_0002
    #expect(hotkey.handle(flags: bothCommands | shift) == false)
}
