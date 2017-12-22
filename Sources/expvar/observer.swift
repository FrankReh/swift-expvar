// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// Not threadsafe. Intended to be called on main thread.

internal class Observer<T: AnyObject> {

    weak var observer: T?

    init(_ observer: T) {
        self.observer = observer
    }
}

class Observers<T: AnyObject> {
    // Would be nice to make this private to file.
    var array: [Observer<T>] = []

    func add(_ observer: T) {
        if contains(observer) {
            print("Observers: observer found in array")
            return
        }

        // Count number of empties
        var notempty = 0
        var empty = 0
        for o in array {
            if o.observer == nil {
                empty += 1
            } else {
                notempty += 1
            }
        }
        // print("Observers: before insertion notempty", notempty, "empty", empty)

        // Does mean update can be made out of add order.
        if !addToEmptySpot(observer) {
            array.append(Observer(observer))
        }
    }

    private func contains(_ observer: T) -> Bool {
        for o in array where o === observer {
            return true
        }
        return false
    }

    private func addToEmptySpot(_ observer: T) -> Bool {
        for o in array where o.observer == nil {
            // print("found empty")
            o.observer = observer
            return true
        }
        // print("empty not found")
        return false
    }
}

class ObserversOwner<T: AnyObject>: Observers<T> {
    typealias Fire = (_: T) -> Void
    func fire(_ fn: Fire) {
        for o in array {
            if let t = o.observer {
                fn(t)
            }
        }
    }
}
