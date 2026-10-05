/// One accessibility element as the Helper read it from the focused window.
public struct AXNode: Equatable, Sendable {
    public var role: String
    public var title: String?
    public var value: String?
    public var description: String?
    public var children: [AXNode]

    public init(role: String, title: String? = nil, value: String? = nil, description: String? = nil, children: [AXNode] = []) {
        self.role = role
        self.title = title
        self.value = value
        self.description = description
        self.children = children
    }
}

private let labels = ["AXButton": "button", "AXLink": "link", "AXTextField": "text field"]

/// The Screen text of a window: its text in reading order, one element per line.
public func screenText(of window: AXNode, limit: Int = 100_000) -> String {
    var lines: [String] = []
    func add(_ line: String?) {
        if let line, line != lines.last { lines.append(line) }
    }
    func walk(_ node: AXNode) {
        if node.role == "AXSecureTextField" { return }
        if let label = labels[node.role] {
            add(name(node).map { "[\(label)] \($0)" })
            return
        }
        add(node.value?.nonBlank ?? node.title?.nonBlank)
        node.children.forEach(walk)
    }
    walk(window)
    let text = lines.joined(separator: "\n")
    return text.count > limit ? text.prefix(limit) + "\n[truncated]" : text
}

/// What a button, link or field says: its own text, or the text inside it.
private func name(_ node: AXNode) -> String? {
    node.value?.nonBlank ?? node.title?.nonBlank ?? node.description?.nonBlank
        ?? node.children.compactMap(name).joined(separator: " ").nonBlank
}

private extension String {
    var nonBlank: String? { allSatisfy(\.isWhitespace) ? nil : self }
}
