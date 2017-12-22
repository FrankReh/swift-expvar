// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

class MyTableView: NSTableView {
    /*
     * Works but is uninteresting.
     *
    override func drawBackground(inClipRect clipRect: NSRect) {
    }
    */
}

class SummaryViewController: NSViewController, ConnectionsObserver, NSTableViewDelegate, NSTableViewDataSource {
    var summaryView: SummaryView // the primary subview
    let itemsPanel: NSView
    var currentDetailPanel: DetailPanel?
    let scrollTableView: ScrollTableView
    let tableview: NSTableView
    let tableColumn: NSTableColumn
    var rows: [SummaryRow] = []
    let heightOfRow: CGFloat
    let rightFrame: NSRect
    let rightConfigName: String
    let buttons: Buttons
    private weak var deleteSelectionButton: NSButton?
    var reloadFns: [() -> Void] = []

    func reload() {
        // Called by the SummaryWindowController timer with the window is visible.
        for fn in self.reloadFns {
            fn()
        }
    }

    // NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else {
            return nil
        }
        guard row >= 0 && row < rows.count else {
            return nil
        }
        let id = column.identifier
        guard let connection = rows[row].connection else {
            return nil
        }

        let (healthString, healthImage) = connection.pollObservable.health()

        var cell = tableView.makeView(withIdentifier: id, owner: self) as? ThreeFieldView

        if cell == nil {
            cell = ThreeFieldView()
            cell?.identifier = id
        }
        let name = connection.varsObservable?.varsHistory.cmdline.first ?? "awaiting poll"
        cell?.setValues(name, healthString, healthImage)
        return cell
    }

    // NSTableViewDelegate
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return self.heightOfRow
    }

    // NSTableViewDelegate
    func tableViewSelectionDidChange(_ notification: Notification) {
        self.processSelection()
    }

    // NSTableViewDataSource
    func numberOfRows(in: NSTableView) -> Int {
        return self.count()
    }
    private func count() -> Int {
        return rows.count
    }

    init(frame summaryFrame: NSRect) {
        let (configNameLeft, configNameRight) = ("left", "right")

        let (leftFrame, rightFrame) =
            configSummaryFrames(boundSize: summaryFrame.size, name1: configNameLeft, name2: configNameRight)

        let summaryView = SummaryView(frame: summaryFrame,
                                      leftSubName: configNameLeft,
                                      leftSubFrame: leftFrame, // TBD for drawing border which makes it too big
                                      rightSubFrame: rightFrame)

        self.summaryView = summaryView

        self.tableview = MyTableView()
        self.tableview.headerView = nil // no header, no title
        self.tableview.selectionHighlightStyle = .sourceList
        self.tableview.intercellSpacing = NSSize(width: 15.0, height: 0.0)
        self.tableview.allowsColumnReordering = false
        self.tableview.allowsColumnResizing = false
        self.tableview.allowsMultipleSelection = false
        self.tableview.allowsEmptySelection = false
        self.tableview.allowsColumnSelection = false

        self.tableColumn =  NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Summary"))
        //self.tableColumn.width = 100

        let itemsPanel = NSView(frame: leftFrame)
        //itemsPanel.backgroundColor = configSummaryColors(name: configNameLeft)
        self.currentDetailPanel = nil

        // TBD might get this from summaryView.rightSubFrame with lineWidth adjust having been made.
        self.rightFrame = rightFrame
        self.rightConfigName = configNameRight

        self.itemsPanel = itemsPanel

        self.scrollTableView = ScrollTableView(tableview: self.tableview)

        self.heightOfRow = config.find("windows", "Summary", "heightOfRow") as? CGFloat ?? 50

        self.buttons = Buttons(origin: CGPoint(
            x: config.find("windows", "Summary", "buttons", "x") as? CGFloat ?? 10,
            y: config.find("windows", "Summary", "buttons", "y") as? CGFloat ?? 10),
        spacing: config.find("windows", "Summary", "buttons", "spacing") as? CGFloat ?? 10)
        self.deleteSelectionButton = nil

        super.init(nibName: nil, bundle: nil)

        connectionsObservable.observers.add(self)

        self.bindWith() // Setup table aspect

        let size = config.find("windows", "Summary", "buttons", "fontSize") as? CGFloat ?? 13
        let font = NSFont.systemFont(ofSize: size)

        self.deleteSelectionButton = self.buttons.add(title: "Delete Selection", font: font) { [weak self] in
            self?.deleteSelection()
        }
        self.deleteSelectionButton?.isEnabled = false

        if config.dict.findBool("experimental", "funModal") {
            // very experimental, doesn't do anything
            _ = self.buttons.add(title: "Fun Modal...", font: font) { (_ button: NSButton) -> Void in
                // Use the callback version that takes the button as input to be able to pull out the window
                // over which to begin the modal sheet.
                if let window = button.window {
                    funModalExample(window: window)
                } else {
                    print("button didn't have a window - strange")
                }
            }
        }

        if config.dict.findBool("experimental", "addCommand") {
            // also experimental. Does not really add a command yet. Doesn't even allow for arguments yet.
            _ = self.buttons.add(title: "Add Command...", font: font) { (_ button: NSButton) -> Void in
                if let window = button.window {
                    modalAddCommand(window: window, summaryViewController: self)
                } else {
                    print("button didn't have a window - strange")
                }
            }
        }

        // Add the buttons to the view.
        self.summaryView.addSubviews(self.buttons.list)

        // Show the WeakLinks counter if configured. More of a debug field anyway.
        if config.dict.findBool("experimental", "weaklinks") {
            let (left, right) = labelCounterFields(bounds: self.summaryView.bounds, leftLabel: "WeakLinks:",
        initialCount: weakLinks.count)
            self.summaryView.addSubview(left)
            self.summaryView.addSubview(right)
            self.reloadFns.append({ [weak right] in
                right?.integerValue = weakLinks.count
            })
        }
    }

    func updateConnectionAppended() {
        guard let last = connectionsObservable.connections.last else {
            return
        }

        let summaryRow = SummaryRow(summaryViewController: self, connection: last)

        rows.append(summaryRow)
        // Did not work. Maybe because row index is new.
        // tableview.reloadData(forRowIndexes: IndexSet(integer: rows.count-1), columnIndexes: IndexSet(integer: 0))
        //tableview.reloadData()
        tableview.insertRows(at: IndexSet(integer: rows.count-1))
    }

    func updateConnectionRemoved(withId: Int) {
        for (index, row) in rows.enumerated().reversed() where row.connection?.id == withId {
            rows.remove(at: index)
        }
        tableview.reloadData() // Will cause selection to jump to top.
    }

    func reloadRow(_ summaryRow: SummaryRow) {
        // Have table update just for this row.
        for rowIndex in 0..<rows.count where rows[rowIndex] === summaryRow {
            tableview.reloadData(forRowIndexes: IndexSet(integer: rowIndex), columnIndexes: IndexSet(integer: 0))
            break
        }
        let detailPanel = summaryRow.detailPanel
        if detailPanel == self.currentDetailPanel {
            detailPanel.needsDisplay = true // gets it reloaded()
        }
    }

    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    override func loadView() {
        // Setup the summary view (the main view) and the items subview.
        self.view = NSView()
        self.view.frame.size = self.summaryView.frame.size
        self.view.autoresizesSubviews = true
        self.view.addSubview(self.summaryView)

        summaryView.addSubview(itemsPanel)

        self.scrollTableView.frame.size = itemsPanel.frame.size
        itemsPanel.autoresizesSubviews = true
        itemsPanel.addSubview(self.scrollTableView)
    }

    private func selectRow(_ row: SummaryRow) {
        // Setup the details view, cleanup any previous details view.

        currentDetailPanel?.removeFromSuperview()
        currentDetailPanel = row.detailPanel
        summaryView.addSubview(row.detailPanel)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        // Have summaryView use whole frame of super view.
        self.summaryView.frame = self.view.bounds

        // Have scrollTableView use whole frame of its super view.
        self.scrollTableView.frame = self.itemsPanel.bounds
    }
    //override func viewDidAppear() {
    //    super.viewDidAppear()
    //}

    private func bindWith() {
        self.tableview.delegate = self
        self.tableview.dataSource = self

        let tableColumn = self.tableColumn

        // config.adjust(column: tableColumn, forWindow: "root")

        // Bind in both directions.
        tableColumn.tableView = self.tableview
        self.tableview.addTableColumn(tableColumn)

        self.tableview.target = self
        self.tableview.action = #selector(singleClick(_:))
    }

    @objc func singleClick(_ : AnyObject) {
        self.processSelection()
    }

    private func processSelection() {
        let rowIndex = self.tableview.selectedRow

        guard rowIndex >= 0 && rowIndex < self.count()  else {
            // No selection
            self.deleteSelectionButton?.isEnabled = false
            self.currentDetailPanel?.removeFromSuperview()
            self.currentDetailPanel = nil
            return
        }
        self.deleteSelectionButton?.isEnabled = true

        let row = rows[rowIndex]

        self.selectRow(row)
    }

    func deleteSelection() {
        // The user has requested that the selected row be removed.

        let rowIndex = self.tableview.selectedRow

        guard rowIndex >= 0 && rowIndex < self.count()  else {
            // Somehow the button was clicked when there was no valid selection available.
            // Just disable the button.
            self.deleteSelectionButton?.isEnabled = false
            return
        }

        let row = rows[rowIndex]

        self.rows.remove(at: rowIndex)
        self.tableview.removeRows(at: IndexSet(integer: rowIndex), withAnimation: [.effectFade, .slideUp])
        row.connection?.close()
    }
}

struct Subframe { // maybe BorderedSubframe
    let name: String
    let frame: NSRect
    let color: NSColor

    var bPath: NSBezierPath

    init(name: String, frame: NSRect) {
        let (color, lineWidth) = configBorder(name: name)

        self.name = name
        self.frame = frame
        self.color = color

        self.bPath = NSBezierPath(rect: frame)
        self.bPath.lineWidth = lineWidth
    }
}

class SummaryView: NSView {
    let left: Subframe
    let rightSubFrame: NSRect

    init(frame: NSRect,
         leftSubName: String,
         leftSubFrame: NSRect,
         rightSubFrame: NSRect) {

        self.left = Subframe(name: leftSubName, frame: leftSubFrame)
        self.rightSubFrame = rightSubFrame
        super.init(frame: frame)
        self.autoresizingMask = [.width, .height]
    }

    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    override func draw(_ dirtyRect: NSRect) {
        //left.fillColor.set()
        //left.bPath.fill()

        left.color.set()
        left.bPath.stroke()
    }
}

private func configSummaryFrames(boundSize: CGSize, name1: String, name2: String) -> (NSRect, NSRect) {
    let x = config.find("windows", "Summary", name1, "origin", "x") as? CGFloat ?? 24
    let y = config.find("windows", "Summary", name1, "origin", "y") as? CGFloat ?? 63
    let widthRatio = config.find("windows", "Summary", name1, "width-ratio") as? CGFloat ?? 0.25
    let gap = config.find("windows", "Summary", name2, "gap") as? CGFloat ?? 8

    let frame1 = NSRect(x: x, y: y, width: (widthRatio * boundSize.width), height: (boundSize.height - 2*y))
    var frame2 = frame1
    frame2.origin.x = frame1.maxX + gap
    frame2.size.width = boundSize.width - frame2.minX - x

    return (frame1, frame2)
}

private func configBorder(name: String) -> (NSColor, CGFloat) {
    let bordercfg = config.find("windows", "Summary", name, "border") as? [String: Any?] ?? [:]

    let colorcfg = bordercfg.find("color") as? [String: Any?] ?? [:]
    let lineWidth = bordercfg.find("lineWidth") as? CGFloat ?? 3.0
    return (configColor(cfg: colorcfg), lineWidth)
}

func configSummaryColors(name: String) -> NSColor {
    let cfg = config.find("windows", "Summary", name, "color") as? [String: Any?] ?? [:]
    return configColor(cfg: cfg)
}

private func configColor(cfg: [String: Any?]) -> NSColor {
    return NSColor(deviceCyan: cfg["cyan"] as? CGFloat ?? 0.0,
                   magenta: cfg["magenta"] as? CGFloat ?? 0.0,
                   yellow: cfg["yellow"] as? CGFloat ?? 0.0,
                   black: cfg["black"] as? CGFloat ?? 0.0,
                   alpha: cfg["alpha"] as? CGFloat ?? 0.5)
}
