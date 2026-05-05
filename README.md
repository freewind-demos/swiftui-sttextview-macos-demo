# SwiftUI + STTextView

## 简介

这个 Demo 演示如何在 `SwiftUI` 中直接使用 `STTextView` 的 SwiftUI wrapper。

目标很小：

- 原生 macOS editor
- 行号
- 当前行高亮
- `AttributedString` 双向绑定

## 快速开始

### 环境要求

- macOS 14+
- Xcode.app 已安装

### 运行

```bash
cd /Volumes/SN550-2T/freewind-demos/swiftui-sttextview-macos-demo
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

## 概念讲解

### 第一部分：最小 SwiftUI 接入

这里直接用 `STTextViewSwiftUI.TextView`：

```swift
STTextViewSwiftUI.TextView(
    text: $text,
    options: [.wrapLines, .highlightSelectedLine, .showLineNumbers]
)
.textViewFont(.monospacedSystemFont(ofSize: 14, weight: .regular))
```

它已经把底层 `STTextView` 包装成可放进 `SwiftUI` 的 view。

### 第二部分：状态模型

内容绑定是 `AttributedString`：

```swift
@State private var text = AttributedString(sampleText)
```

这点很重要。  
如果你后面要做高亮、诊断下划线、富文本标注，`AttributedString` 比纯 `String` 更顺手。

### 第三部分：为什么它适合做原生宿主

这个库本身就是 TextKit 2 路线的原生 editor 组件，重点是：

- 原生滚动与选择
- 行号
- 多光标能力底座
- 可继续接 plugin

## 完整示例

完整入口在 `Sources/swiftui-sttextview-macos-demo/swiftui_sttextview_macos_demo.swift`。

运行后你会得到一个很干净的窗口：

- 顶部“加载示例”
- 编辑区显示行号
- 当前选中行高亮
- 文本变动会立刻回写 SwiftUI 状态

## 注意事项

- 这个 demo 只演示原生 editor view，不含 syntax highlight
- 也不含 completion / diagnostics / jump-to-definition
- 若你要 IDE 级体验，后续还得接 plugin 或 LSP

## 完整讲解

这个方案适合“你明确要纯原生，不想把 WebView 塞进 App”那类场景。  
它的核心价值不是功能爆炸，而是宿主干净：

- `SwiftUI` 管界面与状态
- `STTextView` 管编辑行为

这样分工很稳。  
你先拿它做一个能打字、能滚动、能行号、能高亮当前行的基础 editor，再决定要不要往上叠：

1. syntax highlight
2. completion
3. diagnostics
4. LSP

也就是说，它更像“原生 editor 底盘”，不是开箱即用 IDE。  
如果你的目标是自己控制编辑体验，这种底盘很合适。
