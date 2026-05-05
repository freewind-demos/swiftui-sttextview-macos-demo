import AppKit
import Foundation
import STTextViewSwiftUI
import SwiftUI
import SwiftParser
import SwiftSyntax

private let sampleText = """
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
    @State private var text = AttributedString(sampleText)
    @State private var selection: NSRange? = NSRange(location: 0, length: 0)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("加载示例") {
                    text = AttributedString(sampleText)
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
        selection = expandSelectionToParentSyntaxNode(in: plainText, selection: currentSelection)
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

private func expandSelectionToParentSyntaxNode(in text: String, selection: NSRange) -> NSRange {
    let root = Parser.parse(source: text)
    let clampedSelection = clamp(selection, to: text)
    let byteSelection = byteRange(in: text, nsRange: clampedSelection)
    let currentUpperBound = clampedSelection.location + clampedSelection.length
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

    let sortedCandidates = uniqueRanges(candidates)
        .filter { $0.location <= clampedSelection.location && $0.location + $0.length >= currentUpperBound }
        .sorted {
            if $0.length == $1.length {
                return $0.location < $1.location
            }
            return $0.length < $1.length
        }

    if let exactIndex = sortedCandidates.firstIndex(where: { NSEqualRanges($0, clampedSelection) }) {
        return sortedCandidates.dropFirst(exactIndex + 1).first ?? clampedSelection
    }

    return sortedCandidates.first(where: { !NSEqualRanges($0, clampedSelection) }) ?? clampedSelection
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
