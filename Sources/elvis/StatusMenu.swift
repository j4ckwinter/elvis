import AppKit

final class StatusMenu: NSObject, NSMenuDelegate {
    struct Status {
        var caption: String
        var company: String?
        var soundsAreOn: Bool
        var isInHisCorner: Bool
    }

    struct Choices {
        var throwBall: () -> Void
        var toggleSounds: () -> Void
        var switchCorner: () -> Void
        var quit: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let captionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let companyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let soundsItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds), keyEquivalent: "")
    private let cornerItem = NSMenuItem(title: "", action: #selector(switchCorner), keyEquivalent: "")
    private let currentStatus: () -> Status
    private let choices: Choices

    init(version: String, status: @escaping () -> Status, choices: Choices) {
        self.currentStatus = status
        self.choices = choices
        super.init()
        if let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Elvis") {
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "🐾"
        }
        let menu = NSMenu()
        menu.delegate = self
        captionItem.isEnabled = false
        menu.addItem(captionItem)
        companyItem.isEnabled = false
        menu.addItem(companyItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Throw the Ball", action: #selector(throwBall), keyEquivalent: "").target = self
        soundsItem.target = self
        menu.addItem(soundsItem)
        cornerItem.target = self
        menu.addItem(cornerItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Version \(version)", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(withTitle: "Quit Elvis", action: #selector(quit), keyEquivalent: "").target = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let status = currentStatus()
        captionItem.title = "Elvis: \(status.caption)"
        companyItem.title = "Claude: \(status.company ?? "")"
        companyItem.isHidden = status.company == nil
        soundsItem.state = status.soundsAreOn ? .on : .off
        cornerItem.title = status.isInHisCorner ? "Move to the Other Corner" : "Back to His Corner"
    }

    @objc private func throwBall() { choices.throwBall() }

    @objc private func toggleSounds() { choices.toggleSounds() }

    @objc private func switchCorner() { choices.switchCorner() }

    @objc private func quit() { choices.quit() }
}
