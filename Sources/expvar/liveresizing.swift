// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// LiveResizing tracks windows that should have the same size.
// The origins are adjusted to while the window is being manually resized.
// Pointers are boxed to allow them to be reclaimed.
//
// The most complicated aspect happens when a window has been created but then closed.
// In that case, changing its frame and then calling show yields such strange results,
// it seemed better to just set the size back to what the last resized window had finished at.
// Even though this means the window origin wasn't adjusted as it would have been had the window
// been visible.

private class Box {
    weak var window: NSWindow?
    init(_ window: NSWindow) {
        self.window = window
    }
}
class LiveResizing {
    private var windows: [Box] = []
    var lastFrame = NSRect(x: 0, y: 0, width: 0, height: 0)

    func track(window: NSWindow) {
        if alreadyTracking(window) {
            return
        }
        if lastFrame.size != CGSize(width: 0, height: 0) {
            // use window size that user may have changed on previous window already.
            var newframe = window.frame
            newframe.size =  lastFrame.size
            window.setFrame(newframe, display: false, animate: false)
        }
        if foundEmpty(window) {
            return
        }
        windows.append(Box(window))
    }
    private func alreadyTracking(_ window: NSWindow) -> Bool {
        for box in windows where box.window == window {
            return true
        }
        return false
    }
    private func foundEmpty(_ window: NSWindow) -> Bool {
        for box in windows where box.window == nil {
            box.window = window
            return true
        }
        return false
    }

    func show(_ windowOpt: NSWindow?, wasVisibleBeforeShow: Bool) {
        let screenframe = screenFrame()
        //print("screenFrame() within liveresizing.show()", screenFrame())
        guard let window = windowOpt else {
            return
        }
        if !wasVisibleBeforeShow,
           lastFrame.size != CGSize(width: 0, height: 0),
           window.frame.size != lastFrame.size {
                // set frame size
                var newframe = window.frame
                newframe.size = lastFrame.size

                window.setFrame(newframe, display: false, animate: false)
        }
        if !screenframe.contains(window.frame.origin) {
            let originalframe = window.frame
            //print("window not contained in screen")
            for oldscreen in NSScreen.screens where oldscreen.frame.contains(window.frame.origin) {
                // Move window from this oldscreen to screenframe.

                var newframe = window.frame

                newframe.origin.x -= oldscreen.frame.origin.x - screenframe.origin.x
                //print("window origin.x adjusted")
                // Don't handle screens above each other just yet.

                // Patch x.

                if newframe.maxX > screenframe.maxX {
                    // Have to move the frame back a bit, the oldscreen it is
                    // coming from is wider than the new screen.
                    newframe.origin.x -= oldscreen.frame.size.width - screenframe.size.width
                    //print("window origin.x adjusted again by shrinking to fit")
                } else if originalframe.maxX == oldscreen.frame.maxX {
                    // Special case if window was right at the right edge of
                    // the old screen.  Make it right at the  right edge of
                    // the new screen.
                    newframe.origin.x += screenframe.maxX - newframe.maxX
                    // This works.  But maybe the adjustment should be made
                    // by percentages and not absolutes.
                }

                window.setFrame(newframe, display: false, animate: false)
                return
            }
        }
    }
    func windowWillStartLiveResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            lastFrame = window.frame
        }
    }
    func windowDidResize(_ notification: Notification) {
        if let myself = notification.object as? NSWindow {
            guard myself.inLiveResize else {
                return
            }
            let myframe = myself.frame
            var diff = myframe
            diff.origin.x -= lastFrame.origin.x
            diff.origin.y -= lastFrame.origin.y
            diff.size.width -= lastFrame.size.width
            diff.size.height -= lastFrame.size.height

            for box in windows {
                if let window = box.window,
                !window.inLiveResize,
                window != myself,
                window.frame != myself.frame,
                window.isVisible {

                    var newframe = window.frame
                    if newframe.size.width != myframe.size.width {
                        newframe.origin.x += diff.origin.x
                        newframe.size.width += diff.size.width
                    }

                    if newframe.size.height != myframe.size.height {
                        newframe.origin.y += diff.origin.y
                        newframe.size.height += diff.size.height
                    }

                    window.setFrame(newframe, display: false, animate: true)
                }
            }

            lastFrame = myself.frame
        }
    }
}
