import SwiftUI
import MarkdownUI
import AppKit
import Splash

// 코드 블록 전용 뷰
struct SplashCodeBlockView: View {
    let configuration: CodeBlockConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- 상단 복사 버튼 바 (헤더) ---
            HStack {
                // 언어가 없을 때는 기본 라벨을 표시합니다.
                SwiftUI.Text(configuration.language ?? "Code")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                Spacer()
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(configuration.content, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                        SwiftUI.Text("복사")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SwiftUI.Color.white.opacity(0.2))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    if isHovered { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
            }
            .padding(8)
            .background(SwiftUI.Color.black.opacity(0.6))

            // --- 💻 코드 내용물 ---
            ScrollView(.horizontal, showsIndicators: true) {
                highlightedSwiftUIText(configuration.content)
                    .font(.system(size: 13, design: .monospaced))
                    .enableTextSelection()
                    .padding(12)
            }
            .background(SwiftUI.Color.black.opacity(0.3))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 10)
    }

    func highlightedSwiftUIText(_ code: String) -> SwiftUI.Text {
#if canImport(Splash)
        // Splash 하이라이터로 색상을 적용합니다.
        let highlighter = Splash.SyntaxHighlighter(format: SplashSwiftUITextFormat(theme: aidockDarkSplashTheme))
        return highlighter.highlight(code)
#else
        return SwiftUI.Text(code)
#endif
    }
}

// Splash 기반 텍스트 포맷터
struct SplashSwiftUITextFormat: Splash.OutputFormat {
    let theme: Splash.Theme
    func makeBuilder() -> Builder { Builder(theme: theme) }

    struct Builder: Splash.OutputBuilder {
        let theme: Splash.Theme
        var accumulatedText = SwiftUI.Text("")

        mutating func addToken(_ token: String, ofType type: Splash.TokenType) {
            let color = theme.tokenColors[type] ?? theme.plainTextColor
            let styledText = SwiftUI.Text(token).foregroundColor(SwiftUI.Color(nsColor: color))
            // 문자열 보간을 사용해 텍스트를 누적합니다.
            accumulatedText = SwiftUI.Text("\(accumulatedText)\(styledText)")
        }

        mutating func addPlainText(_ text: String) {
            let styledText = SwiftUI.Text(text).foregroundColor(SwiftUI.Color(nsColor: theme.plainTextColor))
            accumulatedText = SwiftUI.Text("\(accumulatedText)\(styledText)")
        }

        mutating func addWhitespace(_ whitespace: String) {
            let spaceText = SwiftUI.Text(whitespace)
            // 공백도 동일하게 누적합니다.
            accumulatedText = SwiftUI.Text("\(accumulatedText)\(spaceText)")
        }

        func build() -> SwiftUI.Text { accumulatedText }
    }
}

// 커스텀 Markdown 테마
extension MarkdownUI.Theme {
    static var aiDockTheme: MarkdownUI.Theme {
        // 기본 docC 테마를 기반으로 합니다.
        var theme = MarkdownUI.Theme.docC

        // 코드 블록만 커스텀 뷰로 교체합니다.
        theme.codeBlock = BlockStyle { configuration in
            SplashCodeBlockView(configuration: configuration)
        }

        return theme
    }
}
