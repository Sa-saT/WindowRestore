import Cocoa
import Foundation

/// 複数ディスプレイにメニューバー相当の小さなアイコンを表示する補助マネージャ
/// - 目的: セカンダリディスプレイにもステータスアイコン相当のボタンを表示し、同一メニューを開く
final class SecondaryStatusIcons {
    private var windows: [NSWindow] = []
    private let iconProvider: () -> NSImage?
    private let menuProvider: () -> NSMenu?

    init(iconProvider: @escaping () -> NSImage?, menuProvider: @escaping () -> NSMenu?) {
        self.iconProvider = iconProvider
        self.menuProvider = menuProvider

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenParametersChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        rebuild()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        destroyAll()
    }

    @objc private func screenParametersChanged() {
        rebuild()
    }

    func rebuild() {
        destroyAll()
        guard let primary = NSScreen.main else { return }
        let primaryId = (primary.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value

        for screen in NSScreen.screens {
            let sid = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            if sid == primaryId { continue } // メインは本物のNSStatusItemが出るので除外
            createIconWindow(for: screen)
        }
    }

    private func destroyAll() {
        for w in windows { w.close() }
        windows.removeAll()
    }

    private func createIconWindow(for screen: NSScreen) {
        let size: CGFloat = 22
        let margin: CGFloat = 8
        let vf = screen.visibleFrame
        let rect = NSRect(x: vf.maxX - size - margin, y: vf.maxY - size - margin, width: size, height: size)

        let window = NSWindow(contentRect: rect,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false,
                              screen: screen)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let button = NSButton(frame: NSRect(x: 0, y: 0, width: size, height: size))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.image = iconProvider()?.copy() as? NSImage
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(didTapProxyButton(_:))

        let content = NSView(frame: button.frame)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        content.addSubview(button)
        window.contentView = content

        window.orderFrontRegardless()
        windows.append(window)
    }

    @objc private func didTapProxyButton(_ sender: NSButton) {
        guard let menu = menuProvider() else { return }
        let point = NSPoint(x: 0, y: sender.bounds.height - 2)
        menu.popUp(positioning: nil, at: point, in: sender)
    }
}


