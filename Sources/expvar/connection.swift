// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

//
// The Connection structures live on the main thread.
// They are created on the main thread. They are used on the main thread.
//

//
// The Connection and Observing the Connections.
// And a distinction is made between a Connection that program parts
// can use, and the owner of the Connection that updates the kind
// state that can be observed.
//

private var connectionCounter = 0

class Connection {
    let description: String
    let id: Int

    let pollObservable: PollObservable
    var varsObservable: VarsObservable?

    init(description: String,
         pollObservable: PollObservable) {

        self.description = description
        self.id = connectionCounter
        connectionCounter += 1

        self.pollObservable = pollObservable
    }

    func close() {
        connectionObserversOwner.connectionClosed(connection: self)
    }

    // Windows created per connection.

    private var memstatsController: TableMemStatsController?
    func windowMemStats() {
        if let observable = varsObservable {
            if memstatsController == nil {
                memstatsController = TableMemStatsController(description: description,
                    frames: WindowFrames(window: summaryWindowController.window),
                    connection: self,
                    observable: observable)
            }
            memstatsController!.show()
        }
    }

    private var bySizeController: TableBySizeController?
    func windowBySize() {
        if let observable = varsObservable {
            if bySizeController == nil {
                bySizeController = TableBySizeController(description: description,
                    frames: WindowFrames(window: summaryWindowController.window),
                    connection: self,
                    observable: observable)
            }
            bySizeController!.show()
        }
    }

    // The user window machinery is slightly more involved than the others above because we want to be able to
    // use the window to add cells to it, even before the user might have asked for it to be displayed.
    // So it acts like a lazy reference. Actually, it might become a lazy property given the other changes.
    func windowUser() {
        tableUserController.show()
    }

    private var tableUserControllerI: TableUserController?
    var tableUserController: TableUserController {
        if let t = self.tableUserControllerI {
            return t
        }
        // Else it was never created or it was already reclaimed, so create one now.
        let t = TableUserController(
                    description: self.description,
                    instance: self.id,
                    frames: WindowFrames(window: summaryWindowController.window),
                    observable: varsObservable)
        self.tableUserControllerI = t
        return t
    }

    func addCell(_ addcell: TableUserCell) -> String? {
        return tableUserController.tableUser.addCell(addcell)
    }

    private var compareWithPrevController: JsonCompareController?
    func windowCompareWithPrev() {
        if let v = varsObservable {
            let prev = v.jsonVersions.prev ?? v.jsonVersions.first

            if compareWithPrevController == nil {
                compareWithPrevController = JsonCompareController(description: description,
                    instance: self.id,
                    frames: WindowFrames(window: summaryWindowController.window),
                    connection: self,
                    observable: v,
                    nodes: [prev, v.jsonVersions.last]
                    )
            }
            compareWithPrevController!.show()
        }
    }
}

// The ID has a reference to this, as does the ConnectionObserversOwner.
class ConnectionOwner: Connection {
    private let pollObserversOwner = PollObserversOwner()
    private var varsObserversOwner: VarsObserversOwner?

    init(description: String) {

        super.init(description: description,
                   pollObservable: pollObserversOwner.share)
    }

    // Two methods the ID calls.

    func polledDataFailure(_ status: EndpointStatus) {
        pollObserversOwner.polledDataFailure(status)
    }

    func polledDataAvailable(_ vars: Vars) {
        if let f = self.varsObserversOwner {
            f.newVars(vars)
        } else {
            let f = VarsObserversOwner(vars: vars)
            self.varsObserversOwner = f
            self.varsObservable = f.share

            // Perform after self.varsObservable has been set.
            self.pollObserversOwner.polledDataAvailable()
        }
    }
}

// @objc needed because of a tricky bug in swift
// that still hasn't been resolved as of swift 4.
// See https://bugs.swift.org/browse/SR-55.

@objc protocol ConnectionsObserver: class {
    func updateConnectionAppended()
    func updateConnectionRemoved(withId: Int)
}

class ConnectionsObservable {
    let observers: Observers<ConnectionsObserver>
    var connections: [Connection] = []
    // Not ideal that the connections array is open to all,
    // but it is just an app, not a library, or an OS.

    init(_ observers: Observers<ConnectionsObserver>) {
        self.observers = observers
    }
}

class ConnectionObserversOwner {
    // These two arrays are kept in sync.
    private var connectionOwners: [ConnectionOwner] = []

    let observersOwner = ObserversOwner<ConnectionsObserver>()
    let share: ConnectionsObservable

    init() {
        self.share = ConnectionsObservable(observersOwner)
    }

    // Three methods that the owner of the connections list
    // has for manipulating the list.
    // One form of addition, and two forms of removal.

    func addConnection(_ connectionOwner: ConnectionOwner) {
        self.connectionOwners.append(connectionOwner)
        self.share.connections.append(connectionOwner)

        observersOwner.fire {(_ observer: ConnectionsObserver) in
            observer.updateConnectionAppended()
        }
    }

    func connectionClosed(connection: Connection) {
        for index in 0..<share.connections.count
            where connectionOwners[index].id == connection.id {

            removeConnection(index: index)
            break
        }
        observersOwner.fire {(_ observer: ConnectionsObserver) in
            observer.updateConnectionRemoved(withId: connection.id)
        }
    }

    private func removeConnection(index: Int) {
        guard index >= 0 && index < self.connectionOwners.count else {
            return
        }
        _ = self.connectionOwners.remove(at: index)
        _ = self.share.connections.remove(at: index)
    }
}
