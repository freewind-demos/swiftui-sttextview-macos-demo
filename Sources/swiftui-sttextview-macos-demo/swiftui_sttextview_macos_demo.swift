import AppKit
import Foundation
import STTextViewSwiftUI
import SwiftUI
import SwiftParser
import SwiftSyntax

private enum CodeSampleKind: String, CaseIterable, Identifiable {
    case swift = "Swift"
    case javascript = "JavaScript"

    var id: String { rawValue }

    var sampleText: String {
        switch self {
        case .swift:
            swiftSampleText
        case .javascript:
            javaScriptSampleText
        }
    }
}

private let swiftSampleText = """
import Foundation

struct NoteFormatter {
    let prefix: String

    func render(_ title: String) -> String {
        "\\(prefix)-\\(title)"
    }
}

let summary = ["STTextView", "SwiftUI", "Selection"]
    .map(NoteFormatter(prefix: "item").render)
    .filter { $0.contains("i") }
    .joined(separator: " / ")
    .uppercased()

print(summary)
"""

private let javaScriptSampleText = """
const toLabel = (value) => `item-${value}`

const summary = ["sttextview", "swiftui", "selection"]
  .map(toLabel)
  .filter((value) => value.includes("i"))
  .join(" / ")
  .toUpperCase()

console.log(summary)
"""

@main
struct STTextViewDemoApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1000, height: 720)
    }
}

private struct ContentView: View {
    @State private var sampleKind: CodeSampleKind = .swift
    @State private var text = AttributedString(swiftSampleText)
    @State private var selection: NSRange? = NSRange(location: 0, length: 0)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("代码", selection: $sampleKind) {
                    ForEach(CodeSampleKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .frame(width: 150)
                .onChange(of: sampleKind) { _, newValue in
                    text = AttributedString(newValue.sampleText)
                    selection = NSRange(location: 0, length: 0)
                }

                Button("加载示例") {
                    text = AttributedString(sampleKind.sampleText)
                    selection = NSRange(location: 0, length: 0)
                }

                Button("Duplicate 当前行 (⌘D)") {
                    duplicateCurrentLine()
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button("扩选父节点 (⌘E)") {
                    expandSelection()
                }
                .keyboardShortcut("e", modifiers: [.command])

                Text("字符数 \(String(text.characters).count)")
                    .foregroundStyle(.secondary)

                Spacer()
            }

            STTextViewSwiftUI.TextView(
                text: $text,
                selection: $selection,
                options: [.wrapLines, .highlightSelectedLine, .showLineNumbers]
            )
            .textViewFont(.monospacedSystemFont(ofSize: 14, weight: .regular))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }

    private func duplicateCurrentLine() {
        let result = duplicateCurrentLineInText(
            in: String(text.characters),
            selection: selection ?? NSRange(location: 0, length: 0)
        )
        text = AttributedString(result.text)
        selection = result.selection
    }

    private func expandSelection() {
        let plainText = String(text.characters)
        let currentSelection = selection ?? NSRange(location: 0, length: 0)
        selection = expandedSelectionRange(
            in: plainText,
            selection: currentSelection,
            sampleKind: sampleKind
        )
    }
}

private func duplicateCurrentLineInText(in text: String, selection: NSRange) -> (text: String, selection: NSRange) {
    let nsText = text as NSString
    let location = min(selection.location, nsText.length)
    let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
    let lineText = nsText.substring(with: lineRange)
    let insertionText =
        lineRange.upperBound == nsText.length && !lineText.hasSuffix("\n")
        ? "\n" + lineText
        : lineText
    let insertedLength = (insertionText as NSString).length
    let updatedText = nsText.replacingCharacters(
        in: NSRange(location: lineRange.upperBound, length: 0),
        with: insertionText
    )

    return (
        text: updatedText,
        selection: NSRange(location: location + insertedLength, length: selection.length)
    )
}

private func expandedSelectionRange(in text: String, selection: NSRange, sampleKind: CodeSampleKind) -> NSRange {
    switch sampleKind {
    case .swift:
        expandSelectionToSwiftSyntaxNode(in: text, selection: selection)
    case .javascript:
        expandSelectionHeuristically(in: text, selection: selection)
    }
}

private func expandSelectionToSwiftSyntaxNode(in text: String, selection: NSRange) -> NSRange {
    let root = Parser.parse(source: text)
    let clampedSelection = clamp(selection, to: text)
    let byteSelection = byteRange(in: text, nsRange: clampedSelection)
    let normalizedByteSelection =
        byteSelection.lowerBound == byteSelection.upperBound
        ? byteSelection.lowerBound..<byteSelection.lowerBound
        : byteSelection
    var candidates: [NSRange] = []
    collectParentSyntaxSelections(
        in: Syntax(root),
        text: text,
        byteSelection: normalizedByteSelection,
        candidates: &candidates
    )

    return nextExpandedRange(
        current: clampedSelection,
        candidates: candidates,
        text: text
    )
}

private func expandSelectionHeuristically(in text: String, selection: NSRange) -> NSRange {
    let clampedSelection = clamp(selection, to: text)
    let nsText = text as NSString
    var candidates: [NSRange] = []

    if let wordRange = wordRange(in: text, location: clampedSelection.location) {
        candidates.append(wordRange)
    }

    candidates.append(nsText.lineRange(for: clampedSelection))
    candidates.append(paragraphBlockRange(in: text, around: clampedSelection))
    candidates.append(contentsOf: enclosingDelimiterRanges(in: text, around: clampedSelection))
    candidates.append(NSRange(location: 0, length: nsText.length))

    return nextExpandedRange(
        current: clampedSelection,
        candidates: candidates,
        text: text
    )
}

private func collectParentSyntaxSelections(
    in node: Syntax,
    text: String,
    byteSelection: Range<Int>,
    candidates: inout [NSRange]
) {
    let nodeByteRange = node.positionAfterSkippingLeadingTrivia.utf8Offset..<node.endPositionBeforeTrailingTrivia.utf8Offset
    guard nodeByteRange.lowerBound <= byteSelection.lowerBound,
          nodeByteRange.upperBound >= byteSelection.upperBound,
          nodeByteRange.upperBound > nodeByteRange.lowerBound
    else {
        return
    }

    candidates.append(nsRange(in: text, byteRange: nodeByteRange))

    for child in node.children(viewMode: .sourceAccurate) {
        collectParentSyntaxSelections(
            in: child,
            text: text,
            byteSelection: byteSelection,
            candidates: &candidates
        )
    }
}

private func nextExpandedRange(current: NSRange, candidates: [NSRange], text: String) -> NSRange {
    let currentUpperBound = current.location + current.length
    let sortedCandidates = uniqueRanges(candidates)
        .map { clamp($0, to: text) }
        .filter { $0.location <= current.location && $0.location + $0.length >= currentUpperBound }
        .sorted {
            if $0.length == $1.length {
                return $0.location < $1.location
            }
            return $0.length < $1.length
        }

    if let exactIndex = sortedCandidates.firstIndex(where: { NSEqualRanges($0, current) }) {
        return sortedCandidates.dropFirst(exactIndex + 1).first ?? current
    }

    return sortedCandidates.first(where: { !NSEqualRanges($0, current) }) ?? current
}

private func wordRange(in text: String, location: Int) -> NSRange? {
    let nsText = text as NSString
    guard nsText.length > 0 else {
        return nil
    }

    let clampedLocation = min(max(location, 0), nsText.length - 1)
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
    var lowerBound = clampedLocation
    var upperBound = clampedLocation

    while lowerBound > 0,
          let scalar = UnicodeScalar(nsText.character(at: lowerBound - 1)),
          allowed.contains(scalar)
    {
        lowerBound -= 1
    }

    while upperBound < nsText.length,
          let scalar = UnicodeScalar(nsText.character(at: upperBound)),
          allowed.contains(scalar)
    {
        upperBound += 1
    }

    guard upperBound > lowerBound else {
        return nil
    }

    return NSRange(location: lowerBound, length: upperBound - lowerBound)
}

private func paragraphBlockRange(in text: String, around selection: NSRange) -> NSRange {
    let nsText = text as NSString
    let lines = text.components(separatedBy: "\n")
    var currentLocation = 0
    var selectedLine = 0

    for (index, line) in lines.enumerated() {
        let nextLocation = currentLocation + (line as NSString).length + (index == lines.count - 1 ? 0 : 1)
        if selection.location < nextLocation || index == lines.count - 1 {
            selectedLine = index
            break
        }
        currentLocation = nextLocation
    }

    var startLine = selectedLine
    while startLine > 0, !lines[startLine - 1].trimmingCharacters(in: .whitespaces).isEmpty {
        startLine -= 1
    }

    var endLine = selectedLine
    while endLine < lines.count - 1, !lines[endLine + 1].trimmingCharacters(in: .whitespaces).isEmpty {
        endLine += 1
    }

    let startOffset = lines.prefix(startLine).reduce(0) { partial, line in
        partial + (line as NSString).length + 1
    }
    let endOffset = lines.prefix(endLine + 1).reduce(0) { partial, line in
        partial + (line as NSString).length + 1
    }

    return NSRange(location: startOffset, length: max(min(endOffset, nsText.length) - startOffset, 0))
}

private func enclosingDelimiterRanges(in text: String, around selection: NSRange) -> [NSRange] {
    let pairs: [(Character, Character)] = [("(", ")"), ("[", "]"), ("{", "}")]
    let characters = Array(text)
    let lowerUTF16 = selection.location
    let upperUTF16 = selection.location + selection.length
    var ranges: [NSRange] = []

    for (open, close) in pairs {
        var stack: [(characterIndex: Int, utf16Offset: Int)] = []
        var utf16Offset = 0

        for (index, character) in characters.enumerated() {
            if character == open {
                stack.append((index, utf16Offset))
            } else if character == close, let last = stack.popLast() {
                let closeOffset = utf16Offset + String(character).utf16.count
                if last.utf16Offset <= lowerUTF16, closeOffset >= upperUTF16 {
                    ranges.append(NSRange(location: last.utf16Offset, length: closeOffset - last.utf16Offset))
                }
            }

            utf16Offset += String(character).utf16.count
        }
    }

    return ranges
}

private func clamp(_ range: NSRange, to text: String) -> NSRange {
    let length = (text as NSString).length
    let location = min(max(range.location, 0), length)
    let upperBound = min(max(range.location + range.length, location), length)
    return NSRange(location: location, length: upperBound - location)
}

private func byteRange(in text: String, nsRange: NSRange) -> Range<Int> {
    let lowerBound = byteOffset(in: text, utf16Offset: nsRange.location)
    let upperBound = byteOffset(in: text, utf16Offset: nsRange.location + nsRange.length)
    return lowerBound..<upperBound
}

private func byteOffset(in text: String, utf16Offset: Int) -> Int {
    let length = (text as NSString).length
    let clampedOffset = min(max(utf16Offset, 0), length)
    let index = String.Index(utf16Offset: clampedOffset, in: text)
    let utf8Index = index.samePosition(in: text.utf8) ?? text.utf8.endIndex
    return text.utf8.distance(from: text.utf8.startIndex, to: utf8Index)
}

private func nsRange(in text: String, byteRange: Range<Int>) -> NSRange {
    let location = utf16Offset(in: text, byteOffset: byteRange.lowerBound)
    let upperBound = utf16Offset(in: text, byteOffset: byteRange.upperBound)
    return NSRange(location: location, length: upperBound - location)
}

private func utf16Offset(in text: String, byteOffset: Int) -> Int {
    let clampedOffset = min(max(byteOffset, 0), text.utf8.count)
    let utf8Index = text.utf8.index(text.utf8.startIndex, offsetBy: clampedOffset)
    let index = utf8Index.samePosition(in: text) ?? text.endIndex
    return index.utf16Offset(in: text)
}

private func uniqueRanges(_ ranges: [NSRange]) -> [NSRange] {
    var seen = Set<String>()
    return ranges.filter { range in
        let key = "\(range.location)-\(range.length)"
        return seen.insert(key).inserted
    }
}
