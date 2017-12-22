// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// Create two NSTextFields, the first acting as a label and the second
// acting to display a value, typically a counter.
// TBD add alignment option and origin parameter.
func labelCounterFields(bounds: NSRect, leftLabel: String, initialCount: Int) -> (NSTextField, NSTextField) {
    let l = NSTextField(frame: NSRect())
    l.drawsBackground = false
    l.isEditable = false
    l.isBordered = false
    l.stringValue = leftLabel
    l.sizeToFit()
    l.frame.origin = CGPoint(x: 10, y: bounds.maxY - 30)

    let f = NSTextField(frame: NSRect())
    f.drawsBackground = false
    f.isEditable = false
    f.isBordered = false
    f.integerValue = 99999
    f.sizeToFit()
    f.integerValue = initialCount
    f.frame.origin = CGPoint(x: l.frame.maxX, y: l.frame.minY)

    // Now right justify

    let shiftX = bounds.maxX - f.frame.maxX - l.frame.minX
    l.frame.origin.x += shiftX
    f.frame.origin.x += shiftX

    return (l, f)
}
