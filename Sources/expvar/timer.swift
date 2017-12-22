// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// Timer creates a serial dispatch queue and repeatedly invokes
// a job on it.
// Synchronous and asynchronous jobs can also be invoked on the queue.
class Timer {
    typealias Job = () -> Void

    private var repeating: Double
    private var job: Job // strong pointer to closure, is it needed? TBD
    private var queue: DispatchQueue?
    private var timer: DispatchSourceTimer?

    init(queuelabel: String, repeating: Double, _ job: @escaping Job) {
        self.repeating = repeating
        self.job = job
        let queue = DispatchQueue(label: queuelabel) // not attributes: .concurrent
        self.queue = queue

        self.timer?.cancel() // cancel previous timer if any

        let timer = DispatchSource.makeTimerSource(queue: queue) // seems to be strong pointer

        timer.schedule(deadline: .now(), repeating: self.repeating, leeway: .milliseconds(100))

        timer.setEventHandler(handler: job)

        timer.resume()

        self.timer = timer

        //weakLinks.add(self, self.queue, self.timer)
    }
    // sync invokes onetime callback on own queue.
    func sync(onetime: @escaping Job) {
        self.queue?.sync(execute: onetime)
    }
    // aync invokes onetime callback on own queue.
    func async(onetime: @escaping Job) {
        self.queue?.async(execute: onetime)
    }
    func cancel() {
        self.timer?.cancel()
        self.timer = nil
    }
}
