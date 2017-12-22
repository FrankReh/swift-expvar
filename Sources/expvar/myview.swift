// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// Things to figure out the view hierarchy and frames.
// Entry is myview() below.

func labelView(title: String) -> NSTextField {
    let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
    label.stringValue = title
    label.isBezeled = false
    label.isBordered = false
    label.drawsBackground = false
    label.isEditable = false
    label.isSelectable = false
    label.sizeToFit()
    return label
}

extension NSView {
    func addSubviews(_ views: [NSView]) {
        for view in views {
            self.addSubview(view)
        }
    }
}

extension NSSplitView {
    func smartAddSubviews(_ views: [NSView]) {
        if self.frame.size == CGSize(width: 0, height: 0) {
            var size = self.frame.size
            for view in views {
                let viewSize = view.frame.size
                if self.isVertical {
                    size.width += viewSize.width + self.dividerThickness
                    if size.height < viewSize.height {
                        size.height = viewSize.height
                    }
                } else {
                    size.height += viewSize.height + self.dividerThickness
                    if size.width < viewSize.width {
                        size.width = viewSize.width
                    }
                }
            }
            self.frame.size = size
        }

        for view in views {
            self.addSubview(view)
        }
    }
}

func container(title: String) -> NSView {
    // TBD why doesn't the split view resize to wider when super view gets wider?
    let container = NSSplitView()
    container.isVertical = true
    let label1 = labelView(title: title)
    let label2 = labelView(title: title+"2")
    let label3 = labelView(title: title+"3")
    label1.printframe(label: "label1")
    label2.printframe(label: "label2")
    label3.printframe(label: "label3")

    //container.frame.size = CGSize(width: 100, height: 100)

    //container.autoresizesSubviews = true
    container.smartAddSubviews([label1, label2, label3])

    print("after")
    label1.printframe(label: "label1")
    label2.printframe(label: "label2")
    label3.printframe(label: "label3")
    container.printframe(label: "container")

    return container
}

#if false
// 10.12 or higher
func label2(title: String) -> NSTextField {
    return NSTextField(labelWithString: title)
}
func label3(title: String) -> NSTextField {
    //return NSTextField(labelWithAttributedString: NSAttributedString)
    return NSTextField(wrappingLabelWithString: title)
}
#endif

func myview() -> NSView {
    return container(title: "Container Title")
}
