// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

class PopoverTable: NSObject, NSPopoverDelegate {
    private var strong: PopoverTable? // keeps a strong pointer until popover is closed
    private var strongUser: Any?
    private let viewController: TableViewController
    private let myPopover: NSPopover

    init(tableview: NSTableView,
         strong strongUser: Any?,
         relativeTo: NSRect, of: NSView,
         size: CGSize,
         intercellSpacing: CGSize) {

        let viewController = TableViewController(tableview: tableview)

        viewController.view.frame.size = size
        viewController.scrollTableView.tableview.intercellSpacing = intercellSpacing

        self.viewController = viewController
        self.myPopover = NSPopover()
        self.myPopover.contentViewController = viewController
        self.myPopover.animates = true
        self.myPopover.behavior = NSPopover.Behavior.transient

        super.init()

        self.myPopover.delegate = self
        self.strong = self
        self.strongUser = strongUser

        self.show(relativeTo: relativeTo, of: of)
    }

    func show(relativeTo: NSRect, of: NSView) {
        self.myPopover.show(relativeTo: relativeTo, of: of, preferredEdge: NSRectEdge.maxX)
    }

    func popoverDidClose(_ notification: Notification) {
        // Invoked when the popover did close.
        //print("popoverDidClose, memory should be releasing now.")
        self.myPopover.contentViewController = nil
        self.myPopover.delegate = nil
        self.strong = nil // Release the memory.
        self.strongUser = nil
    }
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        // Returns a Boolean value that indicates whether a popover should
        // detach from its positioning view and become a separate window.
        //print("popoverShouldDetach")
        return true
    }
    /*
    func popoverDidDetach(_ popover: NSPopover) {
        // Indicates that a popover has been released while it's in an implicitly detached state.
        print("popoverDidDetach")
    }
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        // The popover invokes this method on its delegate whenever it is about
        // to close. This gives the delegate a chance to override the close.
        print("popoverShouldClose")
        return true
    }
    func popoverWillShow(_ notification: Notification) {
        // Invoked when the popover will show.
        print("popoverWillShow")
    }
    func popoverDidShow(_ notification: Notification) {
        // Invoked when the popover has been shown.
        print("popoverDidShow")
    }
    func popoverWillClose(_ notification: Notification) {
        // Invoked when the popover is about to close.
        print("popoverWillClose")
    }
    */
}
