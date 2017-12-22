// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

func makeResizingView() -> NSView {
    let view = NSView() // The one raw call to NSView(), before autoresizingMask is set.
    // view.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
    view.autoresizingMask = [.width, .height]
    return view
}

extension NSViewController {
    // makeWindow: when the NSViewController should have its own window.
    func makeWindow(
            title: String,
            configName: String,
            contentRect: NSRect,
            delegate: NSWindowDelegate?) -> NSWindow {

        let window = NSWindow(contentRect: contentRect,
                              styleMask: [.resizable, .closable, .titled, .miniaturizable],
                              backing: NSWindow.BackingStoreType.buffered,
                              defer: false)
        window.title = title
        window.delegate = delegate

        // let debug = config.findBool("windows", configName, "frame", "debugCreation")

        // // When debugging, print the window frame and contentRect and the frame and bounds
        // // of viewController's view ancestery.
        // let printframes = {(_ label: String) in
        //     if debug {
        //         window.printframe(label: configName + "." + label)
        //         self.view.printframestack(label: configName + "." + label)
        //     }
        // }

        // printframes("1 init")

        self.view.frame.size = contentRect.size // why does contextRect even come with a point?

        // printframes("2 viewController.viewframe.size taken from contentRect")

        // This shrinks the contectRect.size from (800, 200) to (0,0). Maybe because viewController view was (0,0)?
        // This moves window.frame.pt.y from 4 to 204. Looks like content height was shrunk from 200 to 0
        // and the top left corner of the window was going to remain the same. So assigning a viewcontroller
        // appears to resize the window's contentRect, and that in turn changes the window's frameRect.
        window.contentViewController = self

        // printframes("3 set ViewController")

        if config.findBool("windows", configName, "frame", "center") {
            window.center()
        //     printframes("4 center")
        }

        return window
    }
}

// Sometimes we want a different background color for a view.
extension NSView {
    var backgroundColor: NSColor? {

        get {
            if let colorRef = self.layer?.backgroundColor {
                return NSColor(cgColor: colorRef)
            } else {
                return nil
            }
        }

        set {
            self.wantsLayer = true
            self.layer?.backgroundColor = newValue?.cgColor
        }
    }
}
