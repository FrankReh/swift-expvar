// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

class DetailPanel: NSView {
    weak var connection: Connection?
    let split: CGFloat
    let fontSize: CGFloat
    var reloadFns: [() -> Void] = []
    let windowButtons: Buttons
    private let flowingTextPanel: FlowingTextPanel
    override var isFlipped: Bool { return true }

    init(frame: NSRect, configName: String, connection: Connection) {
        self.connection = connection

        let detailCfg = config.find("windows", "Summary", configName) as? [String: Any?] ?? [:]

        let split = detailCfg["split"] as? CGFloat ?? 0.22
        self.split = split

        let fontSize = detailCfg["fontSize"] as? CGFloat ?? 12
        self.fontSize = fontSize

        self.windowButtons = {
            let cfg = detailCfg["windowButtons"] as? [String: Any?] ?? [:]

            let buttonsOrigin = CGPoint(x: cfg["x"] as? CGFloat ?? 20,
                                        y: cfg["y"] as? CGFloat ?? 372)

            let buttonsSpacing = cfg["spacing"] as? CGFloat ?? 8

            let buttons = Buttons(origin: buttonsOrigin, spacing: buttonsSpacing)

            let size = cfg["fontSize"] as? CGFloat ?? 13
            let font = NSFont.systemFont(ofSize: size)

            _ = buttons.add(title: "JSON", font: font) {[weak connection] in
                connection?.windowCompareWithPrev()
            }
            _ = buttons.add(title: "MemStats", font: font) {[weak connection] in
                connection?.windowMemStats()
            }
            _ = buttons.add(title: "BySize", font: font) {[weak connection] in
                connection?.windowBySize()
            }
            _ = buttons.add(title: "User", font: font) {[weak connection] in
                connection?.windowUser()
            }
            return buttons
        }()

        self.flowingTextPanel = {
            var panelframe = frame // make whole bounds for now, despite buttons
            panelframe.origin = CGPoint(x: 0, y: 0)
            return FlowingTextPanel(frame: panelframe, split: split, fontSize: fontSize)
        }()

        super.init(frame: frame)

        self.backgroundColor = configSummaryColors(name: configName)

        let (leftPolls, rightPolls) = labelCounterFields(bounds: self.bounds, leftLabel: "Polls:",
                                               initialCount: self.connection?.varsObservable?.pollcount ?? 0)
        self.addSubview(leftPolls)
        self.addSubview(rightPolls)
        self.reloadFns.append({ [weak rightPolls, weak self] in
            rightPolls?.integerValue = self?.connection?.varsObservable?.pollcount ?? 0
        })

        // Add the buttons to the view.
        for button in self.windowButtons.list {
            // TBD Don't like the transparent look of the buttons but haven't found
            // a solution yet.
            //button.isTransparent = false
            //button.backgroundColor = NSColor.white // makes a white rectangle though

            self.addSubview(button)
        }
        self.addSubview(self.flowingTextPanel)
    }

    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    override func viewWillDraw() {
        super.viewWillDraw()
        self.reload()
    }

    func reload() {
        for reloadFn in reloadFns {
            reloadFn()
        }
        if let connection = connection {
            self.flowingTextPanel.update(connection: connection)
        }
    }
}

class FlowingTextPanel: NSView {
    private let split: CGFloat
    private let font: NSFont

    private var endpointDescription: String?
    private var cmdline: [String]?

    // Don't bother keeping the last status, it is not equatable, because of its error.
    // But keep the string describing the last status because that is equatable.
    private var statusDescription: String?

    override var isFlipped: Bool { return true }

    init(frame: NSRect, split: CGFloat, fontSize: CGFloat) {
        self.split = split
        self.font = NSFont.systemFont(ofSize: fontSize)
        super.init(frame: frame)
    }

    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    // update calls redraw if something about the connection has changed.
    func update(connection: Connection) {
        var needsRedraw = false

        if endpointDescription != connection.description {
            endpointDescription = connection.description
            needsRedraw = true
        }

        let newcmdline = connection.varsObservable?.varsHistory.cmdline
        if !equal(cmdline, newcmdline) {
            cmdline = newcmdline
            needsRedraw = true
        }

        let newStatusDescription = String(describing: connection.pollObservable.status)
        if statusDescription != newStatusDescription {
            statusDescription = newStatusDescription
            needsRedraw = true
        }

        if needsRedraw {
            self.redraw(self.keyValues(connection: connection))
        }
    }

    // keyValues returns the array of key/value pairs to be drawn.
    private func keyValues(connection: Connection) -> [(String, String)] {
        var r: [(String, String)] = []
        if let endpointDescription = endpointDescription {
            r.append(("Endpoint:", endpointDescription))
        }
        if let cmdline = cmdline {
            r.append(("Cmdline:", String(describing: cmdline)))
        }

        r += connection.pollObservable.status.keyValues()
        return r
    }

    // addAnotherSubview creates an NSTextView and adds it as a subview.
    private func addAnotherSubview() {
        let t = NSTextView()
        t.drawsBackground = false
        t.isEditable = false
        t.isSelectable = false
        t.isFieldEditor = false
        t.isRichText = false
        t.importsGraphics = false
        t.usesFontPanel = false
        t.font = self.font
        t.isVerticallyResizable = true
        t.isHidden = true

        self.addSubview(t)
    }

    // redraw draws the key/value pairs that are passed in.
    // For each key/value pair, another pair of subviews is used,
    // which will appear below the last pair. The key is drawn in
    // the left view, the value drawn in the right.
    private func redraw(_ keyValues: [(String, String)]) {
        // Hide any subviews already created.

        for subview in subviews {
            subview.isHidden = true
        }

        // Closure for getting next subview along with the index for knowing
        // what the next subview is.

        var nextSubviewIndex = 0
        let nextSubview = {[unowned self] (_ string: String, _ alignment: NSTextAlignment,
                                           _ frame: NSRect, _ nextY: CGFloat) -> NSTextView in
            // This type of simple iteration through the subviews works because no other type
            // of subview is used by self.
            while nextSubviewIndex >= self.subviews.count {
                self.addAnotherSubview()
            }
            let subview = self.subviews[nextSubviewIndex]
            nextSubviewIndex += 1

            guard let t = subview as? NSTextView else {
                fatalError("bad view type")
            }
            t.isHidden = false
            t.string = string
            t.alignment = alignment
            t.frame = frame
            t.frame.origin.y = nextY
            t.sizeToFit()
            return t
        }

        // Create starting frames for the left and right views.

        let leftframe: NSRect = {[unowned self] in
            var f = self.bounds
            f.size.width *= self.split
            f.size.height = 0 // resizeToFit() takes care of this
            return f
        }()

        let rightframe: NSRect = {[unowned self] in
            var f = self.bounds
            f.origin.x = leftframe.maxX
            f.size.width -= leftframe.size.width
            f.size.height = 0 // resizeToFit() takes care of this
            return f
        }()

        // Define the closure for getting two more NSTextViews displayed,
        // below the last two.

        var nextY: CGFloat = 10
        let nextSubviewPair = {(lString: String, rString: String) -> Void in
            let left = nextSubview(lString, .right, leftframe, nextY)
            let right = nextSubview(rString, .left, rightframe, nextY)

            nextY = max(nextY, max(left.frame.maxY, right.frame.maxY))
            nextY += 6 // pad between vertical fields
        }

        // Display a pair of NSTextViews for each key/value tuple.
        for (key, value) in keyValues {
            nextSubviewPair(key, value)
        }
    }
}
// Test for equality of two optional arrays of String.
// Odd that the compiler doesn't just allow a == b.
private func equal(_ a: [String]?, _ b: [String]?) -> Bool {
    if let a = a,
       let b = b {
        return a == b
    }
    // At least one was nil.
    return a == nil && b == nil // True if both were nil.
}
