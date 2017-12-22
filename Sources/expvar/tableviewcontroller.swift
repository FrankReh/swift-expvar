// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

class TableViewController: SubviewViewController {
    var scrollTableView: ScrollTableView // the subview

    init(tableview: NSTableView) {
        self.scrollTableView = ScrollTableView(tableview: tableview)
        super.init(subview: self.scrollTableView)
    }
    required init?(coder decoder: NSCoder) { fatalError("not implemented") }
}

class SubviewViewController: NSViewController {
    var subview: NSView

    init(subview: NSView) {

        self.subview = subview

        // Purposely do nothing else with the subview in init,
        // allowing the owner to replace it before loadView() is called.

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    override func loadView() {
        self.view = NSView()
        self.view.frame.size = self.subview.frame.size
        self.view.autoresizesSubviews = true
        self.view.addSubview(self.subview)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        // Have subview use whole frame of super view.
        self.subview.frame = self.view.bounds
    }
}
