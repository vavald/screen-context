import Testing
import ScreenContextCore

func text(_ s: String) -> AXNode { AXNode(role: "AXStaticText", value: s) }

@Test func readsTextInDocumentOrder() {
    let window = AXNode(role: "AXWindow", children: [
        AXNode(role: "AXGroup", children: [
            text("Pricing"),
            AXNode(role: "AXGroup", children: [text("Free")]),
            text("Pro"),
        ]),
    ])
    #expect(screenText(of: window) == "Pricing\nFree\nPro")
}

@Test func labelsWhatYouCanClickOrTypeInto() {
    let window = AXNode(role: "AXWindow", children: [
        AXNode(role: "AXButton", title: "Save"),
        AXNode(role: "AXLink", children: [text("Docs")]),
        AXNode(role: "AXTextField", value: "hello"),
    ])
    #expect(screenText(of: window) == "[button] Save\n[link] Docs\n[text field] hello")
}

@Test func neverReadsPasswordFields() {
    let window = AXNode(role: "AXWindow", children: [
        text("Password"),
        AXNode(role: "AXSecureTextField", value: "hunter2"),
    ])
    #expect(screenText(of: window) == "Password")
}

@Test func dropsEmptyAndRepeatedLines() {
    let window = AXNode(role: "AXWindow", title: "Pricing · Linear", children: [
        AXNode(role: "AXWebArea", title: "Pricing · Linear", children: [
            AXNode(role: "AXHeading", title: "Plans", children: [text("Plans")]),
            text("  "),
            AXNode(role: "AXLink", title: "", children: [text("Docs")]),
        ]),
    ])
    #expect(screenText(of: window) == "Pricing · Linear\nPlans\n[link] Docs")
}

@Test func cutsOffAfter100kCharacters() {
    let window = AXNode(role: "AXWindow", children: [
        AXNode(role: "AXTextArea", value: String(repeating: "a", count: 150_000)),
    ])
    #expect(screenText(of: window) == String(repeating: "a", count: 100_000) + "\n[truncated]")
}
