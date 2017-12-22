// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

enum PollState {
    case off
    case onActivePolling
    case onWaitingForTimeout
}

// SearchPollStatus holds the state of the background search poll.
// This can be reflected in one of the menu's items.
class SearchPollStatus {

    public private(set)  var state: PollState
    weak var mainmenu: MainMenu? // would be nice to make this private to the file

    init (starts state: PollState) {
        self.state = state
    }
    func menuToggle() {
        if state == .off {
            state = .onWaitingForTimeout
            self.mainmenu?.resetMenuItemTitles()
        } else {
            state = .off
            self.mainmenu?.resetMenuItemTitles()
        }
    }

    func mainSyncStartAnotherPollRound() -> Bool {
        var result = false
        DispatchQueue.main.sync { [unowned self] in
            if self.state == .off {
                result = false
                return
            }
            self.state = .onActivePolling
            self.mainmenu?.resetMenuItemTitles()
            result = true
        }
        return result
    }
    func mainAsyncSetPollingFinished() {
        DispatchQueue.main.async { [unowned self] in
            if self.state == .off {
                // The back has finished but we've already
                // turned polling off so no change. 
                return
            }
            self.state = .onWaitingForTimeout
            self.mainmenu?.resetMenuItemTitles()
        }
    }
}

class AppStatusItem {
    let mainMenu: MainMenu
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(searchPollStatus: SearchPollStatus) {
        // Create the NSStatusBar item image
        // Create the NSStatusBar item main menu

        // Use image from config file if possible. Default to a system image.
        statusItem.button?.image = imageNone()
        //statusItem.button?.image = configStatusItemImage() ?? imageOk()

        let mainMenu = MainMenu(searchPollStatus: searchPollStatus, statusItem: statusItem)
        statusItem.menu = mainMenu
        self.mainMenu = mainMenu
    }
}

class EndpointMenuItem: NSMenuItem, ReloadDataObserver, PolledDataObserver {
    weak var connection: Connection? // set after init
    var lastHealth: String = ""

    init(connection: Connection) {
        self.connection = connection

        super.init(title: "new EndPoint", action: nil, keyEquivalent: "")

        connection.pollObservable.observers.add(self)
    }
    required init(coder decoder: NSCoder) { fatalError("not implemented") }

    func polledDataAvailable() {
        guard let connection = self.connection else {
            fatalError("bug")
        }
        guard let varsObservable = connection.varsObservable else {
            fatalError("bug")
        }
        // Endpoint data has arrived and been parsed successfully for first time.

        // Watch for updates to data, fix our title and health status.
        varsObservable.observers.add(self)

        self.checkOnTitle()
        self.checkOnHealth()

        // Create endpoint submenu.
        self.submenu = EndpointMenu(connection: connection)
    }

    func reloadData() {
        self.checkOnTitle()
    }

    func polledDataFailure() {
        self.checkOnHealth()
    }

    private func checkOnTitle() {
        guard let observable = connection?.varsObservable else {
            return
        }
        let cmdline = observable.varsHistory.cmdline
        guard cmdline.count > 0 else {
            return
        }
        if self.title != cmdline[0] {
            self.title = cmdline[0]
        }
    }
    private func checkOnHealth() {
        guard let pollObservable = connection?.pollObservable else {
            return
        }
        let (newHealth, image) = pollObservable.health()
        if newHealth != self.lastHealth {
            self.lastHealth = newHealth
            self.image = image

            if let mainmenu = self.menu as? MainMenu {
                mainmenu.overallHealthCheck()
            }
        }
    }
}

class MainMenu: NSMenu, ConnectionsObserver {
    let searchPollStatus: SearchPollStatus
    let statusItem: NSStatusItem
    var overallHealth: EndpointStatus.HealthScore
    let healthImages: [EndpointStatus.HealthScore: NSImage?]
    var insertionPoint: Int

    let itemStatus = NSMenuItem(title: "status", action: nil, keyEquivalent: "")
    var itemToggleStatus: NSMenuItem?

    init(searchPollStatus: SearchPollStatus, statusItem: NSStatusItem) {
        self.searchPollStatus = searchPollStatus
        self.statusItem = statusItem
        self.overallHealth = EndpointStatus.HealthScore.none
        self.healthImages = [
            .none: imageNone(),
            .normal: configStatusItemImage() ?? imageOk(),
            .warning: imageWarning(),
            .failed: imageStopped()
        ]

        self.insertionPoint = 3
        super.init(title: "MainMenu Title")

        let itemToggleStatus = self.createMenuItem("turn", #selector(toggleStatus))
        self.itemToggleStatus = itemToggleStatus

        self.resetMenuItemTitles()

        self.addItem(itemStatus)
        self.addItem(itemToggleStatus)

        self.addItem(NSMenuItem.separator())

        self.addItem(NSMenuItem.separator())

        self.addItem(self.createMenuItem("Summary Window", #selector(summaryWindow)))

        self.addItem(NSMenuItem.separator())

        self.addItem(self.createMenuItem("Quit", #selector(quit)))

        searchPollStatus.mainmenu = self

        connectionsObservable.observers.add(self)
        self.updateHealthImage()
        self.overallHealthCheck()
    }
    required init(coder decoder: NSCoder) { fatalError("not implemented") }

    func updateConnectionAppended() {
        guard let last = connectionsObservable.connections.last else {
            return
        }

        let menuItem = EndpointMenuItem(connection: last)
        self.addEndpointMenuItem(menuItem)
        self.overallHealthCheck()
    }

    func updateConnectionRemoved(withId: Int) {
        for (index, item) in self.items.enumerated().reversed() {
            if let menuItem = item as? EndpointMenuItem,
                   menuItem.connection?.id == withId {
                self.removeItem(at: index)
                self.insertionPoint -= 1
            }
        }
        self.overallHealthCheck()
    }

    private func addEndpointMenuItem(_ newMenuItem: EndpointMenuItem) {
        self.insertItem(newMenuItem, at: self.insertionPoint)
        self.insertionPoint += 1
    }

    func createMenuItem(_ title: String, _ action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: title,
                              action: action,
                              keyEquivalent: "")
        if action != nil {
            item.target = self
        } else {
            item.isEnabled = false
        }
        return item
    }
    func overallHealthCheck() {
        // Could track which items are EndpointMenuItems.
        var overall = EndpointStatus.HealthScore.none
        for item in self.items {
            if let endpointmenuitem = item as? EndpointMenuItem,
               let pollObservable = endpointmenuitem.connection?.pollObservable {
                let healthscore = pollObservable.status.healthScore()
                if overall.rawValue < healthscore.rawValue {
                    overall = healthscore
                }
            }
        }
        if self.overallHealth != overall {
            self.overallHealth = overall
            self.updateHealthImage()
        }
    }
    private func updateHealthImage() {
        if let image = self.healthImages[self.overallHealth] {
            self.statusItem.button?.image = image
        }
        // TBD could print a warning one time if a health enum value didn't result in an image.
        // Would indicate the dictionary hadn't been initialized properly.
    }

    @objc func toggleStatus(_ sender: NSMenuItem) {
        searchPollStatus.menuToggle()
    }

    @objc func summaryWindow(_ sender: NSMenuItem) {
        // Reach back to the top.
        (NSApplication.shared.delegate as? AppDelegate)?.summaryWindow()
    }

    @objc func quit(_ sender: NSMenuItem) {
        NSApplication.shared.stop(self)
    }

    func resetMenuItemTitles() {
        switch searchPollStatus.state {
        case .off:
            itemStatus.title = "Search: off"
            itemToggleStatus?.title = "Turn Search On"
        case .onActivePolling:
            itemStatus.title = "Search: on, polling"
            itemToggleStatus?.title = "Turn Search Off"
        case .onWaitingForTimeout:
            itemStatus.title = "Search: on, timer"
            itemToggleStatus?.title = "Turn Search Off"
        }
    }
}
class EndpointMenu: NSMenu {
    private weak var connection: Connection?
    init(connection: Connection) {
        self.connection = connection

        super.init(title: "Endpoint Title")

        self.addItem(self.createMenuItem("Windows", nil))
        self.addItem(NSMenuItem.separator())
        self.addItem(self.createMenuItem("JSON", #selector(jsonTable)))
        self.addItem(self.createMenuItem("MemStats", #selector(memStatsTable)))
        self.addItem(self.createMenuItem("BySize", #selector(bySizeTable)))
        self.addItem(self.createMenuItem("User", #selector(userTable)))

        self.addItem(NSMenuItem.separator())
    }
    @objc func jsonTable(_ sender: NSMenuItem) {
        connection?.windowCompareWithPrev()
    }
    @objc func memStatsTable(_ sender: NSMenuItem) {
        connection?.windowMemStats()
    }
    @objc func bySizeTable(_ sender: NSMenuItem) {
        connection?.windowBySize()
    }
    @objc func userTable(_ sender: NSMenuItem) {
        connection?.windowUser()
    }
    required init(coder decoder: NSCoder) { fatalError("not implemented") }

    func createMenuItem(_ title: String, _ action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: title,
                              action: action,
                              keyEquivalent: "")
        if action != nil {
            item.target = self
        } else {
            item.isEnabled = false
        }
        return item
    }
}

private func configStatusItemImage() -> NSImage? {
    guard let s = config.find("StatusBarImageBase64") as? String,
          let data = Data(base64Encoded: s, options: []) else {
        return nil
    }
    return NSImage(data: data)
}
