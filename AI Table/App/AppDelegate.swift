import SwiftUI
import AppKit
import KeyboardShortcuts

// 테두리 없는 창에서도 키보드 입력을 받을 수 있도록 하는 윈도우
class FocusableWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

// 두 개의 창을 관리하는 매니저
class AppDelegate: NSObject, NSApplicationDelegate {
    var dockWindow: NSWindow!
    var chatWindow: NSWindow!

    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupDockWindow()
        setupChatWindow()
        OrchestrationRuntime.shared.bootstrapIfNeeded()

        setupMenuBar()
        KeyboardShortcuts.onKeyUp(for: .toggleDock) { [weak self] in
            self?.handleGlobalShortcut()
        }

        // 알림에 담긴 에이전트 정보를 함께 받도록 셀렉터 시그니처를 사용
        NotificationCenter.default.addObserver(self, selector: #selector(toggleChatWindow(_:)), name: Notification.Name("ToggleChatWindow"), object: nil)

        // 앱 시작 시 이전 채팅창 표시 상태를 복원
        if UserDefaults.standard.bool(forKey: "is_chat_open") {
            chatWindow.alphaValue = 1.0
            chatWindow.makeKeyAndOrderFront(nil)
        }
    }

func setupDockWindow() {
        // 🚨 1. 원래 80이었던 넓이를 250으로 쫙 늘렸다 씨발! 🚨
        let dockWidth: CGFloat = 250 
        let dockHeight: CGFloat = 450
        
        dockWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: dockWidth, height: dockHeight),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        dockWindow.isOpaque = false
        dockWindow.backgroundColor = .clear
        dockWindow.level = .floating
        
        if let screen = NSScreen.main {
            // 늘어난 넓이만큼 화면 오른쪽 여백도 맞춰줌
            let xPos = screen.visibleFrame.maxX - dockWidth - 20
            let yPos = screen.visibleFrame.minY + 20
            dockWindow.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }
        
        dockWindow.contentView = NSHostingView(rootView: DockView())
        dockWindow.makeKeyAndOrderFront(nil)
    }

    func setupChatWindow() {
        let chatWidth: CGFloat = 350
        let chatHeight: CGFloat = 450

        chatWindow = FocusableWindow(
            contentRect: NSRect(x: 0, y: 0, width: chatWidth, height: chatHeight),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )

        chatWindow.isMovableByWindowBackground = true
        chatWindow.isOpaque = false
        chatWindow.backgroundColor = .clear
        chatWindow.level = .floating
        chatWindow.hasShadow = true
        chatWindow.minSize = NSSize(width: 300, height: 400)

        let saveName = "MyAIChatWindowSave"
        if !chatWindow.setFrameUsingName(saveName) {
            if let screen = NSScreen.main {
                let xPos = screen.visibleFrame.midX - (chatWidth / 2)
                let yPos = screen.visibleFrame.minY + 20
                chatWindow.setFrame(NSRect(x: xPos, y: yPos, width: chatWidth, height: chatHeight), display: true)
            }
        }
        chatWindow.setFrameAutosaveName(saveName)

        chatWindow.contentView = NSHostingView(rootView: ChatView())
        chatWindow.alphaValue = 0.0
    }

    // --- 1. 단축키 애니메이션 누락 방지 ---
    func handleGlobalShortcut() {
        let isChatVisible = chatWindow.isVisible && chatWindow.alphaValue > 0
        let isDockVisible = dockWindow.isVisible && dockWindow.alphaValue > 0

        if isChatVisible || isDockVisible {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.chatWindow.animator().alphaValue = 0.0
                self.dockWindow.animator().alphaValue = 0.0
            }) {
                self.chatWindow.orderOut(nil)
                self.dockWindow.orderOut(nil)
            }
            UserDefaults.standard.set(false, forKey: "is_chat_open")
        } else {
            // 앱을 맨 앞으로 활성화
            NSApp.activate(ignoringOtherApps: true)

            // 투명도를 0으로 두고 화면에 배치
            self.chatWindow.alphaValue = 0.0
            self.dockWindow.alphaValue = 0.0
            self.chatWindow.makeKeyAndOrderFront(nil)
            self.dockWindow.makeKeyAndOrderFront(nil)

            // 0.05초 지연으로 윈도우 서버가 투명 상태를 인식할 시간을 확보
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    self.chatWindow.animator().alphaValue = 1.0
                    self.dockWindow.animator().alphaValue = 1.0
                })
            }
            UserDefaults.standard.set(true, forKey: "is_chat_open")
        }
    }

    // --- 2. 메뉴바 애니메이션 누락 방지 ---
    @objc func toggleChatWindow(_ notification: Notification) {
        let newlySelectedAgent = notification.object as? String
        let currentAgent = UserDefaults.standard.string(forKey: "active_agent") ?? "Gemini"

        if chatWindow.isVisible && chatWindow.alphaValue > 0 {
            if let newAgent = newlySelectedAgent, newAgent != currentAgent {
                NSApp.activate(ignoringOtherApps: true)
                self.chatWindow.makeKeyAndOrderFront(nil)
                return
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.chatWindow.animator().alphaValue = 0.0
                self.dockWindow.animator().alphaValue = 0.0
            }) {
                self.chatWindow.orderOut(nil)
                self.dockWindow.orderOut(nil)
            }
            UserDefaults.standard.set(false, forKey: "is_chat_open")

        } else {
            NSApp.activate(ignoringOtherApps: true)

            self.chatWindow.alphaValue = 0.0
            self.dockWindow.alphaValue = 0.0
            self.chatWindow.makeKeyAndOrderFront(nil)
            self.dockWindow.makeKeyAndOrderFront(nil)

            // 여기에서도 동일하게 0.05초 지연을 적용
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    self.chatWindow.animator().alphaValue = 1.0
                    self.dockWindow.animator().alphaValue = 1.0
                })
            }
            UserDefaults.standard.set(true, forKey: "is_chat_open")
        }
    }

    func setupMenuBar() {
        // 메뉴바에 들어갈 사이즈만큼 공간 파기
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // 메뉴바 아이콘
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "AI Dock")
        }

        // 아이콘 눌렀을 때 표시될 메뉴 구성
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "채팅창 표시/숨기기", action: #selector(menuToggleChat), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "앱 종료", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func menuToggleChat() {
        // 알림을 보내서 창 표시/숨기기 토글
        NotificationCenter.default.post(name: Notification.Name("ToggleChatWindow"), object: nil)
    }

    @objc func quitApp() {
        // 메뉴바 앱은 Dock에서 종료가 불편하므로 메뉴로 종료 제공
        NSApplication.shared.terminate(nil)
    }
}
