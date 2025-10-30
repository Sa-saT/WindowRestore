import Cocoa
import Foundation

final class QuitWindow: NSWindow, NSWindowDelegate {
    private var quitButton: NSButton!

    init() {
        let rect = NSRect(x: 0, y: 0, width: 260, height: 120)
        super.init(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.title = "Window Restore"
        self.center()
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.delegate = self
        setupUI()
    }

    private func setupUI() {
        guard let contentView = self.contentView else { return }

        let label = NSTextField(labelWithString: "× を押すとアプリを終了します")
        label.alignment = .center
        label.frame = NSRect(x: 20, y: 70, width: 220, height: 20)
        contentView.addSubview(label)

        quitButton = NSButton(title: "終了", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.frame = NSRect(x: 95, y: 25, width: 70, height: 30)
        contentView.addSubview(quitButton)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // 赤い×で閉じた場合も終了
        NSApplication.shared.terminate(nil)
    }

    func show() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
