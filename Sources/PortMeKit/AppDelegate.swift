import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    /// รีเฟรชเฉพาะตอน popover เปิด — ปิดแล้วต้องไม่มี timer ไหนทำงานค้างเบื้องหลัง
    private static let refreshInterval: TimeInterval = 3

    private let model = PortMeModel()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var refreshTimer: Timer?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusItem.button(title: "Port me", symbol: "powerplug.fill")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model, onQuit: { NSApp.terminate(nil) })
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // ต้อง activate ไม่งั้นปุ่มใน popover ไม่รับคลิกแรก
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    public func popoverDidShow(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.refresh() }
        }
    }

    public func popoverDidClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

private extension NSStatusItem {
    static func button(title: String, symbol: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        item.button?.image?.isTemplate = true
        return item
    }
}
