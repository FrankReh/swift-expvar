// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

typealias SimpleButtonClickAction = () -> Void
typealias NormalButtonClickAction = (NSButton) -> Void
typealias ThreeButtonClickAction = (NSButton, NSButton, NSButton) -> Void

// StdButton is one you click for an action.

class SimpleButton: NSButton {
    var callback: SimpleButtonClickAction

    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    init(_ callback: @escaping SimpleButtonClickAction) {
        self.callback = callback
        super.init(frame: NSRect())
        self.target = self
        self.action = #selector(self.click)
    }

    @objc func click(_ sender: NSButton) {
        self.callback()
    }
}

class NormalButton: NSButton {
    let callback: NormalButtonClickAction

    required init?(coder decoder: NSCoder) {
        fatalError("not implemented")
    }

    init(_ callback: @escaping NormalButtonClickAction) {
        self.callback = callback
        super.init(frame: NSRect())
        self.target = self
        self.action = #selector(self.click)
    }

    @objc func click(_ sender: NSButton) {
        self.callback(sender)
    }
}

enum ButtonOptions {
    case vertical // horizontal considered the default so no option defined
    // could have rightjustify (implies bottomjustify if vertical)
}
class Buttons {
    var list: [NSButton] = []

    var vertical: Bool // false for horizontal
    var origin: CGPoint
    var spacing: CGFloat

    init(origin: CGPoint = CGPoint(x: 10, y: 5), spacing: CGFloat = -1, options: [ButtonOptions] = []) {
        self.vertical = options.contains(ButtonOptions.vertical)
        self.origin = origin
        self.spacing = (spacing >= 0) ? spacing : (self.vertical ? origin.y : origin.x)
    }

    // respace will rebuilt the space between buttons.
    // Useful when one or more buttons may have had a size change
    // or when a different amount of pad spacing is desired
    // or when the first has a different origin.
    func respace(spacing: CGFloat = -1) {
        let s = (spacing >= 0) ? spacing : self.spacing
        for i in 1..<list.count {
            list[i].frame.origin = self.skipCalculation(frame: list[i-1].frame, spacing: s)
        }
    }

    // add creates a button for the action, 
    // sets its title and bezelStyle, and then has the button added to
    // the list. Adding to the list has the side effect of setting the frame.
    func add(title: String, font: NSFont? = nil, _ action: @escaping SimpleButtonClickAction) -> SimpleButton {
        let b = SimpleButton(action)
        _ = self.setup(b, title: title, font: font)
        self.add(button: b)
        return b
    }

    // add works like the previous add but for an action where the callback wants
    // to see the NSButton reference.
    func add(title: String, font: NSFont? = nil, _ action: @escaping NormalButtonClickAction) -> NormalButton {
        let b = NormalButton(action)
        _ = self.setup(b, title: title, font: font)
        self.add(button: b)
        return b
    }

    private func setup(_ button: NSButton, title: String, font: NSFont?) -> NSButton {
        button.title = title
        button.bezelStyle = NSButton.BezelStyle.roundRect
        if let f = font {
            button.font = f
        }
        return button
    }

    // add a created NSButton calculates the frame needed if it wasn't already set
    // and then appends it to the internal list.
    func add(button: NSButton) {
        // button.printframe(label: "button before adjustments")
        if hasZeroSize(button.frame) {
            button.sizeToFit()
            // button.printframe(label: "button after sizeToFit")
        }
        if hasZeroPoint(button.frame) {
            button.frame.origin = self.nextPoint()
            // button.printframe(label: "button after setting origin")
        }

        list.append(button)
        // button.printframe(label: "button appended to Buttons list")
    }

    func addCheckManual(title: String,
                        checkTitle: String,
                        manualTitle: String,
                        font: NSFont? = nil,
                        check checkAction: @escaping ThreeButtonClickAction,
                        manual manualAction: @escaping ThreeButtonClickAction)
    -> (SimpleButton, SimpleButton, SimpleButton) {

        // Create three buttons but the first will not be selectable and will not have a border.
        // It acts as a label.
        // The second will have a checkbox.
        // The third will be the manual version of the check function and has its own
        // action associated with the user pressing it.

        // The two active buttons are created first and then their action closures are set so that
        // both can have closures that refer to all three buttons.

        let label = self.add(title: title, font: font) {} // noop for the label
        label.isBordered = false

        let check = self.add(title: checkTitle, font: font) {}
        check.setButtonType(.switch) // .switch creates a checkbox next to the title
        check.frame.size.width += 10 // adjust width because of extra checkbox

        let manual = self.add(title: manualTitle, font: font) {}

        check.callback = { [weak label, weak check, weak manual] in
            if let label = label,
               let check = check,
               let manual = manual {
                checkAction(label, check, manual)
               }
        }

        manual.callback = { [weak label, weak check, weak manual] in
            if let label = label,
               let check = check,
               let manual = manual {
                manualAction(label, check, manual)
               }
        }

        return (label, check, manual)
    }

    func nextPoint() -> CGPoint {
        if list.count == 0 {
            // First point.
            return self.origin
        }

        return self.skipCalculation(frame: list[list.count-1].frame, spacing: self.spacing)
    }

    func skipCalculation(frame: NSRect, spacing: CGFloat) -> CGPoint {
        var origin = frame.origin
        if self.vertical {
            origin.y = frame.maxY + self.spacing
        } else {
            // Horizontal layout
            origin.x = frame.maxX + self.spacing
        }
        return origin
    }
}

func compilertest() {
    // check that various forms compile
    var listOfButtons = [
        Buttons(),
        Buttons(options: [.vertical]),
        Buttons(origin: CGPoint(x: 15, y: 25)),
        Buttons(spacing: 20) ]

    let h = listOfButtons[0]
    h.add(button: NSButton())
    _ = h.add(title: "Hello World!") {}
    _ = h.add(title: "Hello another World!") { (_ b: NSButton) in }

    let v = listOfButtons[1]
    v.add(button: NSButton())
    _ = v.add(title: "Hello World!") {}
    _ = v.add(title: "Hello another World!") { (_ b: NSButton) in }
}
