// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// Observing poll state changes for an individual endpoint.

@objc protocol PolledDataObserver: class {
    func polledDataAvailable()
    func polledDataFailure()
}

class PollObservable {
    var status: EndpointStatus
    let observers: Observers<PolledDataObserver>

    init(_ observers: Observers<PolledDataObserver>) {
        self.observers = observers

        self.status = EndpointStatus(
                            continuing: true,
                            error: nil,
                            stderr: nil)
    }

    func health() -> (String, NSImage?) {
        return status.health()
    }
}

class PollObserversOwner {
    let observers = ObserversOwner<PolledDataObserver>()
    var share: PollObservable

    init() {
        self.share = PollObservable(observers)
    }
    func polledDataAvailable() {
        observers.fire {(_ observer: PolledDataObserver) in
            observer.polledDataAvailable()
        }
    }
    func polledDataFailure(_ status: EndpointStatus) {
        share.status = status
        observers.fire {(_ observer: PolledDataObserver) in
            observer.polledDataFailure()
        }
    }
}
