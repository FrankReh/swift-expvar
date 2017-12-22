// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

protocol Frames {
    func windowFrame() -> NSRect
    func screenFrame() -> NSRect
    func frames() -> (NSRect, NSRect)
}

class WindowFrames: NSObject, Frames {
    private let window: NSRect
    private let screen: NSRect

    init(window: NSWindow?) {
        self.window = window?.frame ?? defaultContentRect
        // TBD use better screen backup
        self.screen = window?.screen?.frame ?? defaultContentRect
    }
    func windowFrame() -> NSRect {
        return window
    }
    func screenFrame() -> NSRect {
        return screen
    }
    func frames() -> (NSRect, NSRect) {
        return (windowFrame(), screenFrame())
    }
}

// screenframe returns the frame of the screen associated with the
// last NSEvent, else it returns the first screen's frame, else
// it returns all zeros.
func screenFrame() -> NSRect {
    let pt = NSEvent.mouseLocation
    for screen in NSScreen.screens where screen.frame.contains(pt) {
        return screen.frame
    }
    if let screen = NSScreen.screens.first {
        return screen.frame
    }
    return NSRect(x: 0, y: 0, width: 0, height: 0)
}
