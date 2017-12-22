// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

//
// Observing JSON data from endpoints.
//
// Define a protocol for the reloadData() method.
// This method is already used by NSTableView.
// Other classes just define it explicitly.
//
// Define the wrapper for the VarsHistory instance that
// lets it be subscribed to.
//
// And define the owner of the wrapper that can fire the
// action that had been subscribed to.

@objc protocol ReloadDataObserver: class {
    func reloadData()
}

extension NSTableView: ReloadDataObserver {
}

typealias JsonDict = [String: Any?]

class JsonVersions {
    let first: JsonDict
    var last: JsonDict
    var prev: JsonDict?
    init (first: JsonDict) {
        self.first = first
        self.last = first
        self.prev = nil
    }
    func setLast(_ newlast: JsonDict) {
        (self.prev, self.last) = (self.last, newlast)
    }
}

class VarsObservable {
    let varsHistory: VarsHistory
    let observers: Observers<ReloadDataObserver>
    var pollcount = 1
    let jsonVersions: JsonVersions

    init(_ vars: Vars, observers: Observers<ReloadDataObserver>) {
        self.varsHistory = VarsHistory(vars)
        self.observers = observers
        self.jsonVersions = JsonVersions(first: vars.jsonDict)
    }
}

class VarsObserversOwner {
    let observersOwner = ObserversOwner<ReloadDataObserver>()
    var share: VarsObservable

    init(vars: Vars) {
        self.share = VarsObservable(vars, observers: observersOwner)
    }
    func newVars(_ vars: Vars) {
        share.varsHistory.add(vars)
        share.pollcount += 1
        share.jsonVersions.setLast(vars.jsonDict)
        observersOwner.fire {(_ observer: ReloadDataObserver) in
            observer.reloadData()
        }
    }
}
