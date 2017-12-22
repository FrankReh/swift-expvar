// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

class SummaryWindowController: NSWindowController {
    private var reloadTimer: Timer

    init() {
        // Make a view controller
        // Make a window
        // Init super window controller with window

        let contentRect = config.summaryFrame(top: false,
                                           screenFrame: NSScreen.main?.frame ?? defaultContentRect,
                                           size: defaultContentRect.size,
                                           offset: defaultContentRect.origin)

        let viewController = SummaryViewController(frame: contentRect)

        let window = viewController.makeWindow(title: "ExpVar Summary",
                                               configName: "Summary",
                                               contentRect: contentRect,
                                               delegate: nil)

        // Don't allow the summary window to be resized.
        window.styleMask = [.closable, .titled, .miniaturizable]

        // Update summary stats every second.

        self.reloadTimer = Timer(queuelabel: "Summary Reload Timer",
                                 repeating: 1.0) {[weak window, weak viewController] in
            if window?.isVisible ?? false {
                viewController?.reload()
            }
        }

        super.init(window: window)

        window.makeFirstResponder(viewController.tableview)

        window.delegate = self
    }
    required init(coder decoder: NSCoder) { fatalError("not implemented") }
}

extension  SummaryWindowController: NSWindowDelegate {
    //func windowWillClose(_: Notification) {
        //NSApplication.shared.stop(self)
    //}
}
