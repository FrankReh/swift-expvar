// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

class WeakBox {
    weak var ptr: AnyObject?
    init(_ ptr: AnyObject) {
        self.ptr = ptr
    }

}
class WeakLinks {
    private var boxes: [WeakBox] = []

    var count: Int {return boxes.reduce(0, {($1.ptr == nil) ? $0 : ($0 + 1)})}

    func add(_ ptrs: AnyObject?...) {
        for ptr in ptrs {
            self.addOne(ptr)
        }
    }
    func addOne(_ ptr: AnyObject?) {
        guard let ptr = ptr else {
            return // if already nil
        }
        var empty: WeakBox? = nil
        for box in boxes {
            if box.ptr === ptr {
                return // if already in list
            }
            if box.ptr == nil {
                empty = box // ends up using the last empty box found
            }
        }
        if let empty = empty {
            empty.ptr = ptr
            return // if an empty spot is found, use it
        }
        // Add a new box.
        boxes.append(WeakBox(ptr))
    }
}

let weakLinks = WeakLinks()
