// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// The ID is created on the main thread but it exists to bridge
// the background/main thread barrier.

class ID {
    // ConnectionObserversOwner really owns this connection.
    // The ID is just given permission to make these two calls to
    // it while it exists.
    // A suble point: the property is weak, not to avoid a memory leak
    // but to allow the background thread to recognized when the connection
    // has been deleted, so the endpoint cyclic timer gets shutdown
    // and the endpoint can be resubmitted to the first background polling
    // thread - maybe the endpoint will come back to life.
    //
    // If something else in the app causes the connection not to be freed
    // and this weak pointer is not set back to nil, the endpoint will not
    // be resubmitted to first background thread.
    private weak var connectionOwner: ConnectionOwner?

    init(connectionOwner: ConnectionOwner) {
        self.connectionOwner = connectionOwner
    }

    func asyncPolledDataAvailable(vars: Vars) -> Bool {
        if let connectionOwner = self.connectionOwner {
            DispatchQueue.main.async {
                connectionOwner.polledDataAvailable(vars)
            }
            return true
        }
        return false
    }
    func asyncPolledDataFailure(status: EndpointStatus) {
        DispatchQueue.main.async {
            self.connectionOwner?.polledDataFailure(status)
        }
    }
}
