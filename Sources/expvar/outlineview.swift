// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// JSON OutlineView DataSource

struct OutlineFn {
    typealias IsItemExpandable = (_ item: Any) -> Bool
    typealias NumberOfChildrenOfItem = (_ item: Any?) -> Int
    typealias Child = (_ index: Int, _ item: Any?) -> Any
    typealias ObjectValueFor = (_ tableColumn: NSTableColumn?, _ item: Any?) -> Any?

    let isItemExpandable: IsItemExpandable
    let numberOfChildrenOfItem: NumberOfChildrenOfItem
    let child: Child
    let objectValueFor: ObjectValueFor
}

class Outline: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource {

    let fn: OutlineFn

    init(outlineFn: OutlineFn) { self.fn = outlineFn }

    //
    // isItemExpandable (1 of 4 required)
    //
    func outlineView(_ outlineView: NSOutlineView,
                     isItemExpandable item: Any) -> Bool {

        let bool = self.fn.isItemExpandable(item)
        return bool
    }

    //
    // numberOfChildrenOfItem (2 of 4 required)
    //
    func outlineView(_ outlineView: NSOutlineView,
                     numberOfChildrenOfItem item: Any?) -> Int {

        let int = self.fn.numberOfChildrenOfItem(item)
        return int
    }

    //
    // child ofItem (3 of 4 required)
    //
    func outlineView(_ outlineView: NSOutlineView,
                     child index: Int, ofItem item: Any?) -> Any {

        let child = self.fn.child(index, item)
        return child
    }

    //
    // objectValueFor byItem (4 of 4 required)
    //
    func outlineView(_ outlineView: NSOutlineView,
                     objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        let result = self.fn.objectValueFor(tableColumn, item)
        return result
    }

    //
    // NSOutlineViewDelegate
    //
    // func outlineView(_ outlineView: NSOutlineView, shouldExpandItem any: Any) -> Bool
    // func outlineView(_ outlineView: NSOutlineView, shouldSelectItem any: Any) -> Bool
}
