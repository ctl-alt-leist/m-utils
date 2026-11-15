// Coffee: a menu bar switch that keeps the Mac from idling to sleep.
//
// Holds the same power assertions `caffeinate -di` takes (no idle display sleep,
// no idle system sleep) for as long as the user asks, then releases them.

import AppKit
import IOKit.pwr_mgt
import ServiceManagement

// ============================================================================
// Power assertion
// ============================================================================

final class SleepBlocker {
    private var assertions: [IOPMAssertionID] = []

    var isActive: Bool { !assertions.isEmpty }

    func start() {
        if !isActive {
            let types = [
                kIOPMAssertionTypePreventUserIdleDisplaySleep,
                kIOPMAssertionTypePreventUserIdleSystemSleep,
            ]
            for type in types {
                var id = IOPMAssertionID(0)
                let result = IOPMAssertionCreateWithName(
                    type as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "Coffee menu bar utility" as CFString,
                    &id
                )
                if result == kIOReturnSuccess {
                    assertions.append(id)
                }
            }
        }
    }

    func stop() {
        for id in assertions {
            IOPMAssertionRelease(id)
        }
        assertions.removeAll()
    }
}

// ============================================================================
// Time parsing and formatting
// ============================================================================

/// Parse a clock time such as "5pm", "5:30pm", "5:30 PM", or "17:00" into the next
/// future occurrence of that time.
func parseClockTime(_ text: String, now: Date = Date()) -> Date? {
    let cleaned = text.trimmingCharacters(in: .whitespaces).lowercased()
        .replacingOccurrences(of: " ", with: "")
    let formats = ["h:mma", "ha", "H:mm", "H"]
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.amSymbol = "am"
    formatter.pmSymbol = "pm"

    var target: Date? = nil
    for format in formats where target == nil {
        formatter.dateFormat = format
        if let parsed = formatter.date(from: cleaned) {
            let calendar = Calendar.current
            let parts = calendar.dateComponents([.hour, .minute], from: parsed)
            if let today = calendar.date(
                bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: now
            ) {
                target = today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
            }
        }
    }

    return target
}

func formatRemaining(_ seconds: TimeInterval) -> String {
    let minutes = Int((seconds / 60).rounded(.up))
    let hours = minutes / 60
    let text = hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"

    return text
}

func formatClock(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none

    return formatter.string(from: date)
}

// ============================================================================
// Menu bar app
// ============================================================================

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let blocker = SleepBlocker()
    private var statusItem: NSStatusItem!
    private var endDate: Date? = nil
    private var ticker: Timer? = nil

    private let showCountdownKey = "showCountdown"
    private var showCountdown: Bool {
        get { UserDefaults.standard.object(forKey: showCountdownKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showCountdownKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshButton()
    }

    func applicationWillTerminate(_ notification: Notification) {
        blocker.stop()
    }

    // ------------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------------

    private func activate(until end: Date?) {
        blocker.start()
        endDate = end
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.tick()
        }
        refreshButton()
    }

    private func deactivate() {
        blocker.stop()
        endDate = nil
        ticker?.invalidate()
        ticker = nil
        refreshButton()
    }

    private func tick() {
        if let end = endDate, end <= Date() {
            deactivate()
        } else {
            refreshButton()
        }
    }

    private func refreshButton() {
        if let button = statusItem.button {
            let symbol = blocker.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Coffee")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading

            var title = ""
            if let end = endDate, blocker.isActive, showCountdown {
                title = " " + formatRemaining(end.timeIntervalSinceNow)
            }
            button.title = title
        }
    }

    // ------------------------------------------------------------------------
    // Menu
    // ------------------------------------------------------------------------

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status: String
        if !blocker.isActive {
            status = "Not keeping awake"
        } else if let end = endDate {
            status = "Awake until \(formatClock(end)) (\(formatRemaining(end.timeIntervalSinceNow)))"
        } else {
            status = "Awake indefinitely"
        }
        let statusLine = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        menu.addItem(item("Indefinitely", #selector(startIndefinitely)))
        for hours in [1, 2, 3] {
            let entry = item(hours == 1 ? "1 hour" : "\(hours) hours", #selector(startForHours(_:)))
            entry.tag = hours
            menu.addItem(entry)
        }
        menu.addItem(item("Until…", #selector(startUntil)))
        if blocker.isActive {
            menu.addItem(item("Add 1 hour", #selector(addHour)))
            menu.addItem(.separator())
            menu.addItem(item("Stop", #selector(stop)))
        }
        menu.addItem(.separator())

        let countdown = item("Show Countdown", #selector(toggleCountdown))
        countdown.state = showCountdown ? .on : .off
        menu.addItem(countdown)
        let login = item("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self

        return entry
    }

    // ------------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------------

    @objc private func startIndefinitely() {
        activate(until: nil)
    }

    @objc private func startForHours(_ sender: NSMenuItem) {
        activate(until: Date().addingTimeInterval(TimeInterval(sender.tag) * 3600))
    }

    @objc private func startUntil() {
        let alert = NSAlert()
        alert.messageText = "Stay awake until"
        alert.informativeText = "A time such as 5pm, 5:30pm, or 17:00."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "5:00pm"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            // An empty field takes the placeholder as the answer.
            let typed = field.stringValue.trimmingCharacters(in: .whitespaces)
            let text = typed.isEmpty ? field.placeholderString ?? "" : typed
            if let end = parseClockTime(text) {
                activate(until: end)
            } else {
                let failure = NSAlert()
                failure.messageText = "Could not read “\(text)” as a time."
                failure.runModal()
            }
        }
    }

    @objc private func addHour() {
        if let end = endDate {
            endDate = end.addingTimeInterval(3600)
            refreshButton()
        } else {
            activate(until: Date().addingTimeInterval(3600))
        }
    }

    @objc private func stop() {
        deactivate()
    }

    @objc private func toggleCountdown() {
        showCountdown.toggle()
        refreshButton()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let failure = NSAlert(error: error)
            failure.runModal()
        }
    }
}

// ============================================================================
// Entry point
// ============================================================================

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
