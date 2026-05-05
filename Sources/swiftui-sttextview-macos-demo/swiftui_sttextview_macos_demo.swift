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

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("加载示例") {
                    text = AttributedString(sampleText)
                }

                Text("字符数 \(String(text.characters).count)")
                    .foregroundStyle(.secondary)

                Spacer()
            }

            STTextViewSwiftUI.TextView(
                text: $text,
                options: [.wrapLines, .highlightSelectedLine, .showLineNumbers]
            )
            .textViewFont(.monospacedSystemFont(ofSize: 14, weight: .regular))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }
}
