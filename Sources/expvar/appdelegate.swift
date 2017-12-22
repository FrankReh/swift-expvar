// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

let connectionObserversOwner = ConnectionObserversOwner()
let connectionsObservable = connectionObserversOwner.share

let summaryWindowController = SummaryWindowController()

class AppDelegate: NSObject, NSApplicationDelegate {
    private let searchPollStatus: SearchPollStatus
    private let appStatusItem: AppStatusItem

    override init() {
        self.searchPollStatus = SearchPollStatus(starts: .onWaitingForTimeout)
        self.appStatusItem = AppStatusItem(searchPollStatus: searchPollStatus) // Includes the quit mechanism.
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Setting the activation policy to regular allows
        // the keyboard to be attached to the app's windows.
        // The up and down arrow keys in the summary window work,
        // as an example.
        NSApplication.shared.setActivationPolicy(.regular)
        summaryWindowController.showWindow(self)
    }

    func summaryWindow() {
        summaryWindowController.showWindow(self)
    }
}

// The Registrar provides a background dispatchqueue the ability to register an
// endpoint for inclusion in the root table.  Calling the synchronous method
// when already on the main thread will deadlock.
extension AppDelegate: Registrar {
    func syncRegisterEndpoint(description: String) -> ID {
        var connectionOwner: ConnectionOwner?

        DispatchQueue.main.sync {
            connectionOwner = ConnectionOwner(description: description)
            weakLinks.add(connectionOwner)

            connectionObserversOwner.addConnection(connectionOwner!)
        }

        guard let c = connectionOwner else { fatalError("bug") }

        // The AppDelegate doesn't keep a reference to the ID, nor does it keep
        // a list of created IDs. They exist on their own, managed by their API
        // and the background thread that made this call.
        // The AppDelegate does keep the ConnectionObserversOwner list of connections.
        return ID(connectionOwner: c)
    }
    func syncStartAnotherPollRound() -> Bool {
        return self.searchPollStatus.mainSyncStartAnotherPollRound()
    }
    func asyncSetPollingFinished() {
        self.searchPollStatus.mainAsyncSetPollingFinished()
    }
}
