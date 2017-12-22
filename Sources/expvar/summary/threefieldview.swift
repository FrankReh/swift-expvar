// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// ThreeFieldView is the view used in the summary window's table.
// It holds one image and two text fields.

// |-------|---------------|
// |       |       1       |
// |   0   |---------------|
// |       |       2       |
// |-------|---------------|

private let x0Ratio: CGFloat = 0.10
private let x2Ratio: CGFloat = 0.14
private let y1Lower: CGFloat = 0.05

private let frameNull = NSRect(x: 0, y: 0, width: 0, height: 0)

// These origins and sizes won't be the final frames. The final frames are
// recomputed from the size of the cell in the table.

class ThreeFieldView: NSView {
    let image = NSImageView(frame: frameNull)
    let text1 = NSTextField(frame: frameNull)
    let text2 = NSTextField(frame: frameNull)
    init() {
        super.init(frame: frameNull)

        self.autoresizingMask = [.width, .height]

        setup(text1, 14)
        setup(text2, 12)

        self.addSubview(image)
        self.addSubview(text1)
        self.addSubview(text2)
    }
    required init?(coder decoder: NSCoder) {
        fatalError("not implemented")
    }
    override func resizeSubviews(withOldSize _: NSSize) {
        image.frame = self.bounds
        text2.frame = self.bounds

        image.frame.size.width *= x0Ratio
        text2.frame.size.width *= (1 - x2Ratio)

        // rightJustify
        text2.frame.origin.x += self.bounds.maxX - text2.frame.size.width

        text2.frame.size.height /= 2

        text1.frame = above(text2.frame)
        // The top text appears too close to top border, so lower it a smidge.
        text1.frame.origin.y -= (self.bounds.size.height * y1Lower)
        text1.frame.origin.y -= (self.bounds.size.height * y1Lower) // Do this twice
        text2.frame.origin.y += (self.bounds.size.height * y1Lower) // And even raise the second
    }

    func setValues(_ s0: String, _ s1: String, _ image: NSImage?) {
        self.image.image = image
        self.text1.stringValue = s0
        self.text2.stringValue = s1
    }
}

private func setup(_ view: NSTextField, _ ofSize: CGFloat) {
    view.isSelectable = false
    view.drawsBackground = false
    view.isBezeled = false
    view.isBordered = false
    view.font = NSFont.menuFont(ofSize: ofSize) // or menuFont
}

private func above(_ src: NSRect) -> NSRect {
    var r = src
    r.origin.y = src.maxY
    return r
}
