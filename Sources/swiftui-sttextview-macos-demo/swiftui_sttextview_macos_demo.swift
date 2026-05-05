import AppKit
import Foundation
import STTextViewSwiftUI
import SwiftUI

private let sampleText = """
import Foundation

struct Note {
    let title: String
    let body: String
}

let notes = [
    Note(title: "STTextView", body: "Line numbers"),
    Note(title: "SwiftUI", body: "Native host"),
]

for note in notes {
    print("\\(note.title): \\(note.body)")
}
"""

@main
struct STTextViewDemoApp: App {
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
