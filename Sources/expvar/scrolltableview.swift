// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// ScrollTableView is an NSScrollView with an NSTable view automatically created.
// Set the delegate and dataSource of the NSTableView to the init parameters
// provided. Have the NSScrollView always resize when it's parent resizes.
// Enable both scroll bars by default.
class ScrollTableView: NSScrollView {

    let tableview: NSTableView // one strong pointer maintained

    init(tableview: NSTableView) {
        self.tableview = tableview

        super.init(frame: tableview.frame)

        //autoresizingMask = [.minXMargin, .width, .maxXMargin, .minYMargin, .height, .maxYMargin]
        autoresizingMask = [.width, .height]

        documentView = tableview

        hasHorizontalScroller = true
        hasVerticalScroller = true

        tableview.rowSizeStyle = .medium
    }

    required init?(coder decoder: NSCoder) {
        fatalError("not implemented")
    }
}
