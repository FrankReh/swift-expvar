// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// The modal mode of the summary window, implemented with the NSWindow.beginSheet method.
// When the user has initiated something from the summary window that requires completion before
// the summary window can again be used. The summary window can continue to show live updates.

// TBD Half baked example.
// TBD Fix size.
// TBD Add the command to the list as a CommandListItem or CommandSummaryRow.
func modalAddCommand(window: NSWindow, summaryViewController: SummaryViewController) {

    let size = CGSize(width: 300, height: 100)
    let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)

    // let color = NSColor(deviceCyan: 0.5, magenta: 0.5, yellow: 0.5, black: 0.5, alpha: 0.5)
    // userView.backgroundColor = color // just to see where it is when window scrolls down.

    // Create the custom view for the modal command at hand.
    // Reference any controls that it includes that should be captured by the done action.

    let userView = NSView(frame: frame)

    // Add text and input field to view.
    // Return the input field so its delegate can be set.
    // When the control is changed, the delegate is notified
    // and can determine whether the done button should be
    // enabled.
    let cmdField = setupAddCommandView(userView)

    let doneFn = { return cmdField.stringValue != "" }

    beginSheet(sheetParent: window,
        backgroundColor: nil, // TBD any color?
        viewFn: {(_ viewController: ModalViewController) -> NSView in
            cmdField.delegate = viewController

            viewController.enableDoneFn = doneFn

            return userView
        },
        cancelAction: {
            print("user cancel")
        },
        doneAction: {
            print("user done")
            let cmdValue = cmdField.stringValue
            print("command '\(cmdValue)'")
            // Don't accept being done if the done function fails.  This
            // shouldn't be necessary as the done button becomes disabled when
            // doneFn() fails but just to be on the safe side, it is checked
            // here anyway.
            if !doneFn() {
                return false
            }
            return true
        })
}

private func setupAddCommandView(_ view: NSView) -> NSTextField {

    let fontSize: CGFloat = 13
    let font = NSFont.labelFont(ofSize: fontSize)

    let pt = CGPoint(x: 20, y: 20)
    let gap: CGFloat = 10

    let cmdFrame = NSRect(x: pt.x, y: pt.y, width: 0, height: 0)

    let cmdLabel = {() -> NSTextField in
        let t = NSTextField(frame: cmdFrame)
        t.isEditable = false
        t.stringValue = "command:"
        t.alignment = .right
        t.isSelectable = false
        t.drawsBackground = false
        t.isBezeled = false
        t.isBordered = false
        t.font = font
        t.sizeToFit()
        view.addSubview(t)
        return t
    }()

    let cmdTextField = {() -> NSTextField in
        let t = NSTextField(frame: cmdFrame)
        t.isEditable = true
        // TBD figure out best way to set layout
        //cmdTextField.preferredMaxLayoutWidth = 200
        t.stringValue = "                       "
        t.alignment = .left
        t.font = font
        t.sizeToFit()
        t.stringValue = ""
        view.addSubview(t)
        return t
    }()

    fixRightOrigin(left: cmdLabel, gap: gap, right: cmdTextField)

    return cmdTextField
}

func fixRightOrigin(left: NSView, gap: CGFloat, right: NSView) {
    right.frame.origin.x = left.frame.maxX + gap
    right.frame.origin.y = left.frame.origin.y
}

func funModalExample(window: NSWindow) {

    let size = CGSize(width: 300, height: 300)
    let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)

    let color = NSColor(deviceCyan: 0.5, magenta: 0.5, yellow: 0.5, black: 0.5, alpha: 0.5)
    //userView.backgroundColor = color // just to see where it is when window scrolls down.
    beginSheet(sheetParent: window,
        backgroundColor: color,
        viewFn: {(_ viewController: ModalViewController) -> NSView in
            let userView = NSView(frame: frame)
            return userView
        },
        cancelAction: {
            print("user cancel")
        },
        doneAction: {
            print("user done")
            return true
        })
}

func beginSheet(sheetParent: NSWindow, 
                backgroundColor: NSColor?,
                viewFn userViewFn: (ModalViewController) -> NSView,
                cancelAction: @escaping () -> Void,
                doneAction: @escaping () -> Bool) {
    // Create NSView for Cancel and Done buttons
    // Create NSViewController
    // Create NSWindow
    // Bind to each other
    // Add Cancel and Done buttons to view, with appropriate actions
    // Begin the modal session on the window

    // The userView origin is adjusted to be above the buttons.
    // The modalView origin only makes sense as zero.
    // Only userView size plus the room for the buttons is what determines the size of the window being drawn.

    let viewController = ModalViewController()

    // Create the view with a reference to the viewController to allow the viewController to be used
    // as the delegate to things like NSTextFields that may be added to the view.
    let userView = userViewFn(viewController)

    let buttonY: CGFloat = 20
    let addedHeight: CGFloat = 2*buttonY + 20 // hack: +20 to account for button height themselves.
    userView.frame.origin = CGPoint(x: 0, y: addedHeight)
    let modalView = NSView(frame: CGRect(x: 0, y: 0, width: userView.frame.size.width,
                                         height: userView.frame.size.height + addedHeight))

    modalView.addSubview(userView)

    let sheet = NSWindow(contentRect: modalView.frame,
                         styleMask: [.closable, .titled], // include .titled so window is allowed to become key
                         backing: NSWindow.BackingStoreType.buffered,
                         defer: false)

    viewController.view = modalView

    sheet.contentViewController = viewController

    let doneButton = addCancelDoneButtons(view: modalView, sheet: sheet, y: buttonY,
        cancelAction: {
            print("lib cancel")
            cancelAction()
            sheetParent.endSheet(sheet)
        },
        doneAction: {
            print("lib done")
            if doneAction() {
                sheetParent.endSheet(sheet)
            }
            // else don't end the sheet and user can fix things or hit cancel.
        })

    viewController.doneButton = doneButton

    // Setting the background color works if done after adding the buttons.
    if backgroundColor != nil {
        print("setting background color")
        modalView.backgroundColor = backgroundColor
    }

    sheetParent.beginSheet(sheet) // ignoring the completionHandler: option
}

// ModalViewController provides the glue for the bindings between controls that have been added to
// its view and the Done button that would have also been added to its view.
// When the controls are built, their delegates are set to this controller.
// When the done button is created, the doneButton property is set within this controller.
// Both when the controllers view will first appear and when controls are changed,
// the done button's isEnabled property gets recomputed.
// One piece of the glue not observed here is is property enableDoneFn closure.
// It is created when the controls are created so a programmatic evaluation of the state of the controls
// can be created and the results passed to the done button's isEnabled property as a boolean.
//
// This glue takes three steps:
//  assign this view controller as the delegate to any controls that may change related to enabling done,
//  assign the enableDoneFn property of this view controller,
//  and assign the done button property of this view controller.
class ModalViewController: NSViewController, NSTextFieldDelegate {
    var enableDoneFn: (() -> Bool)?
    weak var doneButton: NSButton?
    init() {
        self.enableDoneFn = nil
        self.doneButton = nil
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    // viewWillAppear can be called more than once, for example again after a summary window deminiaturization.
    override func viewWillAppear() {
        self.dodone()
    }

    override func controlTextDidChange(_ obj: Notification) {
        self.dodone()
    }

    private func dodone() {
        guard let enableDoneFn = self.enableDoneFn,
              let doneButton = self.doneButton else {
            return
        }
        doneButton.isEnabled = enableDoneFn()
    }
}

private func addCancelDoneButtons(view: NSView, sheet: NSWindow,
                                  y: CGFloat,
                                  cancelAction: @escaping SimpleButtonClickAction,
                                  doneAction: @escaping SimpleButtonClickAction) -> NSButton {
    let configName = "modal"

    // Keep the Buttons just long enough to create the buttons along with their callbacks and
    // the positions between the buttons.
    // Once the buttons are added as subviews, they get retained.

    // TBD After buttons are in place, use difference between right side and right button
    // to adjust the left (first) button's x position, and have the buttons readjusted
    // in order to get them on the lower right of the view. Now they are on the lower left.
    let buttons = Buttons(origin: CGPoint(x: 18, y: y), spacing: 12)

    view.backgroundColor = configSummaryColors(name: configName)

    let font = NSFont.systemFont(ofSize: 13)

    _ = addButton(view: view, buttons: buttons, sheet: sheet, title: " Cancel  ", font: font, key: "\u{1b}", cancelAction)
    return addButton(view: view, buttons: buttons, sheet: sheet, title: "  Done   ", font: font, key: "\r", doneAction)
}

private func addButton(view: NSView, buttons: Buttons, sheet: NSWindow, title: String, font: NSFont,
                       key: String, _ action: @escaping SimpleButtonClickAction) -> NSButton {
    let button = buttons.add(title: title, font: font, action)
    button.keyEquivalent = key

    if !sheet.makeFirstResponder(button) {
        fatalError("bug") // button not made first responder
    }
    view.addSubview(button)

    return button
}
