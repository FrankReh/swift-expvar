// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TableMemStats manages a particular data set and for it, it builds columns, and
// binds those columns with an NSTableView, and is the delegate and dataSource
// for the data to the NSTableView.
//
// It is expected that calls to this class are done on the main thread as it
// iteracts with an NSTableView when data has changed.
//
// It is initialized with a reference to data, and has full knowledge of the type of data
// to allow it to create the columns necessary. Once an NSTableView has been
// created by the caller and passed in, the NSTableView is retained and columns
// from the data fields are bound with the view.
//
// It can also initiate an action per a user double click on a table row.
//
// Delegate and DataSource
//  tableView(_: NSTableView, viewFor: NSTableColumn?, row: Int) -> NSView?
//  numberOfRows(in: NSTableView) -> Int
//  tableView(_: NSTableView, objectValueFor: NSTableColumn?, row: Int) -> Any?
//  tableView(_: NSTableView, sortDescriptorsDidChange: [NSSortDescriptor])

import AppKit

// Define History protocol that each of these rows can return.

class MemStatsRow {
    let name: String
    let history: HistoryProtocol
    weak var handle: AnyObject?
    init (_ name: String, _ history: HistoryProtocol) {
        self.name = name
        self.history = history
    }
}

// TBD probably use later again.
func boolString(_ b: Bool) -> String {
    return b ? "true" : "false"
}

// Helper class.
class TableMemStatsColumn: NSTableColumn {
    typealias StringValueFn = (MemStatsRow) -> String
    let alignment: NSTextAlignment
    let stringValueFn: StringValueFn

    init(title: String, tooltip: String?, alignment: NSTextAlignment,
         sort: NSSortDescriptor?, stringValueFn: @escaping StringValueFn) {
        self.alignment = alignment
        self.stringValueFn = stringValueFn
        super.init(identifier: NSUserInterfaceItemIdentifier(title))
        self.title = title
        self.headerToolTip = tooltip
        self.sortDescriptorPrototype = sort
        self.headerCell.alignment = alignment
    }
    required init(coder decoder: NSCoder) {
        fatalError("not implemented")
    }
}

class TableMemStats: NSObject {
    private static let columns: [TableMemStatsColumn] = [
            // maybe make closure for each column, given TableMemStats, and index -> String
        TableMemStatsColumn(title: "MemStats Field",
                        tooltip: "/debug/vars top level dictionary name",
                        alignment: .right,
                        sort: nil,
                        stringValueFn: {(_ row: MemStatsRow) -> String in return row.name }),
        TableMemStatsColumn(title: "Current",
                        tooltip: "/debug/vars top level dictionary value",
                        alignment: .right,
                        sort: nil,
                        stringValueFn: {(_ row: MemStatsRow) -> String in return row.history.historyCurrentDescription() }),
        TableMemStatsColumn(title: "Delta",
                        tooltip: "/debug/vars top level dictionary value",
                        alignment: .left,
                        sort: nil,
                        stringValueFn: {(_ row: MemStatsRow) -> String in return row.history.historyDeltaDescription() })
    ]

    private let endpointDescription: String
    private weak var connection: Connection?
    private var observable: VarsObservable
    private let rows: [MemStatsRow]
    private weak var tableview: NSTableView?

    init(description: String, connection: Connection, observable: VarsObservable) {
        self.endpointDescription = description
        self.connection = connection
        self.observable = observable

        var r: [MemStatsRow] = []
        r.append(MemStatsRow("Alloc", observable.varsHistory.memstats.alloc))
        r.append(MemStatsRow("TotalAlloc", observable.varsHistory.memstats.totalAlloc))
        r.append(MemStatsRow("Sys", observable.varsHistory.memstats.sys))
        r.append(MemStatsRow("Lookups", observable.varsHistory.memstats.lookups))
        r.append(MemStatsRow("Mallocs", observable.varsHistory.memstats.mallocs))
        r.append(MemStatsRow("Frees", observable.varsHistory.memstats.frees))
        r.append(MemStatsRow("HeapAlloc", observable.varsHistory.memstats.heapAlloc))
        r.append(MemStatsRow("HeapSys", observable.varsHistory.memstats.heapSys))
        r.append(MemStatsRow("HeapIdle", observable.varsHistory.memstats.heapIdle))
        r.append(MemStatsRow("HeapInuse", observable.varsHistory.memstats.heapInuse))
        r.append(MemStatsRow("HeapReleased", observable.varsHistory.memstats.heapReleased))
        r.append(MemStatsRow("HeapObjects", observable.varsHistory.memstats.heapObjects))
        r.append(MemStatsRow("StackInuse", observable.varsHistory.memstats.stackInuse))
        r.append(MemStatsRow("StackSys", observable.varsHistory.memstats.stackSys))
        r.append(MemStatsRow("MSpanInuse", observable.varsHistory.memstats.mSpanInuse))
        r.append(MemStatsRow("MSpanSys", observable.varsHistory.memstats.mSpanSys))
        r.append(MemStatsRow("MCacheInuse", observable.varsHistory.memstats.mCacheInuse))
        r.append(MemStatsRow("MCacheSys", observable.varsHistory.memstats.mCacheSys))
        r.append(MemStatsRow("BuckHashSys", observable.varsHistory.memstats.buckHashSys))
        r.append(MemStatsRow("GCSys", observable.varsHistory.memstats.gCSys))
        r.append(MemStatsRow("OtherSys", observable.varsHistory.memstats.otherSys))
        r.append(MemStatsRow("NextGC", observable.varsHistory.memstats.nextGC))
        r.append(MemStatsRow("LastGC", observable.varsHistory.memstats.lastGC))
        r.append(MemStatsRow("PauseTotalNs", observable.varsHistory.memstats.pauseTotalNs))
        r.append(MemStatsRow("PauseNs", observable.varsHistory.memstats.pauseNs))
        r.append(MemStatsRow("PauseEnd", observable.varsHistory.memstats.pauseEnd))
        r.append(MemStatsRow("Pause", observable.varsHistory.memstats.pause)) // redundant, just an experiment
        r.append(MemStatsRow("NumGC", observable.varsHistory.memstats.numGC))
        r.append(MemStatsRow("NumForcedGC", observable.varsHistory.memstats.numForcedGC))
        r.append(MemStatsRow("GCCPUFraction", observable.varsHistory.memstats.gCCPUFraction))
        // TBD Figure out later
        //rows.append(MemStatsRowBool("enableGC", observable.varsHistory.memstats.enableGC))
        //rows.append(MemStatsRowBool("debugGC", observable.varsHistory.memstats.debugGC))

        // Sort the rows based on the user's config.

        let ordering = config.jsonOrdering()

        r.sort {
            return (ordering[$0.name] ?? Int.min) < (ordering[$1.name] ?? Int.min)
        }

        self.rows = r
    }

    // Bind NSTableColumn and tableview with each other.
    func bindWith(_ tableview: NSTableView) {
        tableview.delegate = self
        tableview.dataSource = self

        self.tableview = tableview

        for tableColumn in TableMemStats.columns {

            config.adjust(column: tableColumn, forWindow: "memstats")

            // Bind in both directions.
            tableColumn.tableView = tableview
            tableview.addTableColumn(tableColumn)

        }
        // For single click.
        tableview.target = self
        tableview.action = #selector(singleClick(_:))
        tableview.doubleAction = #selector(doubleClick(_:))
    }

    // singleClick on tableview. Call the appropriate column with the given row.
    // The row index may be -1 indicating the colummn header as clicked.
    @objc func singleClick(_ sender: AnyObject) {
        guard let tableview = sender as? NSTableView else {
            print("sender expected to be NSTableView")
            return
        }
        /*
        let clickedColumn = tableview.clickedColumn
        // columns can be reordered.
        guard clickedColumn >= 0, clickedColumn < tableview.tableColumns.count else {
              return
        }
        let tableColumn = tableview.tableColumns[clickedColumn]
        guard let column = tableColumn as? TableMemStatsColumn else {
            fatalError("bad tableColumn type")
        }
        */

        // clickedRow is -1 when column header is clicked
        let clickedRow = tableview.clickedRow
        if clickedRow >= 0, clickedRow < rows.count {
            let row = rows[clickedRow]

            if row.handle == nil {
                let history = row.history

                let newtableview = NSTableView()
                observable.observers.add(newtableview)
                let table = history.historyTable()
                table.bindWith(newtableview)
                let rect = (tableview.rowView(atRow: clickedRow, makeIfNecessary: false) ?? tableview).frame

                // No need to retain reference to popover, but keep a weak reference to keep from showing redundant popovers.
                row.handle = PopoverTable(tableview: newtableview,
                    strong: table,
                    relativeTo: rect,
                    of: tableview,
                    size: config.popoverSize(forWindow: "memstats", defaultSize: CGSize(width: 400, height: 0)),
                    intercellSpacing: config.popoverIntercellSpacing(forWindow: "memstats")
                    )
            }
        }
    }
    @objc func doubleClick(_ sender: AnyObject) {
        guard let tableview = sender as? NSTableView else {
            print("sender expected to be NSTableView")
            return
        }
        let clickedColumn = tableview.clickedColumn
        // columns can be reordered.
        guard clickedColumn >= 0, clickedColumn < tableview.tableColumns.count else {
              return
        }
        guard let column = tableview.tableColumns[clickedColumn] as? TableMemStatsColumn else {
            fatalError("bad tableColumn type")
        }
        guard let connection = self.connection else {
            print("connection has been closed") // endpoint was deleted, but user hasn't closed window.
            return
        }

        // clickedRow is -1 when column header is clicked
        let clickedRow = tableview.clickedRow
        guard clickedRow >= 0, clickedRow < rows.count else {
            return
        }
        let row = rows[clickedRow]

        let addcell = TableUserCell(
            TableUserCellDescription(
                UserColumnDesciption(
                        headerAlignment: column.alignment,
                        title: column.title,
                        headerToolTip: column.headerToolTip,
                        identifier: column.identifier),
                UserRowDesciption(name: row.name)),
            cellViewFn: { (_ tableView: NSTableView) -> NSView? in
                return cellFn(tableView, column, row)
            })
        let errormsg = connection.addCell(addcell)
        if errormsg != nil {
            print("addCell error: ", errormsg!)
        }
    }
}

private func cellFn(_ tableView: NSTableView, _ column: TableMemStatsColumn, _ row: MemStatsRow) -> NSView? {
    let id = column.identifier

    let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField ?? NSTextField()

    cell.identifier = id
    cell.alignment = column.alignment
    cell.stringValue = column.stringValueFn(row)
    return cell
}

extension TableMemStats: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rows.count else {
            return nil
        }
        guard let column = tableColumn as? TableMemStatsColumn else {
            fatalError("bad tableColumn type")
        }
        return cellFn(tableView, column, rows[row])
    }
}

extension TableMemStats: NSTableViewDataSource {

    func numberOfRows(in: NSTableView) -> Int {
        return rows.count
    }

    func tableView(_: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        print("TableMemStats.tableView(_,sortDescriptorsDidChange)")
        self.tableview?.reloadData()
    }
}

class TableMemStatsController: NSObject {
    //private var strongSelf: TableMemStatsController?
    private let tableMemStats: TableMemStats
    private var controller: NSWindowController?

    init(description: String, frames: Frames, connection: Connection, observable: VarsObservable) {

        let newtableview = NSTableView()
        newtableview.columnAutoresizingStyle = .noColumnAutoresizing
        observable.observers.add(newtableview)

        self.tableMemStats = TableMemStats(description: description, connection: connection, observable: observable)
        self.tableMemStats.bindWith(newtableview)
        super.init()

        let configName = config.memStatsConfigName
        let contentRect = config.frame(
            windowName: configName,
            frames: frames,
            relativeScreen: true,
            top: false,
            size: CGSize(width: 300, height: 780),
            offset: CGPoint(x: 100, y: 0),
            instanceOffset: CGPoint(x: 40, y: 40),
            instance: connection.id)

        let viewController = TableViewController(tableview: newtableview)

        observable.observers.add(viewController.scrollTableView.tableview)

        let window = viewController.makeWindow(title: "MemStats: " + description,
                                               configName: configName,
                                               contentRect: contentRect,
                                               delegate: self)

        liveResizing.track(window: window)

        self.controller = NSWindowController(window: window)
        //self.strongSelf = self
    }

    func show() {
        guard let controller = self.controller else {
            print("controller lost")
            exit(1)
        }
        let wasVisible = controller.window?.isVisible ?? false
        controller.showWindow(self)
        liveResizing.show(controller.window, wasVisibleBeforeShow: wasVisible)
    }
}

private var liveResizing = LiveResizing()

extension TableMemStatsController: NSWindowDelegate {

    //func windowWillClose(_ notification: Notification) {
    //    self.strongSelf = nil // Let ARC have at it.
    //}
    func windowDidResize(_ notification: Notification) {
        liveResizing.windowDidResize(notification)
    }
    func windowWillStartLiveResize(_ notification: Notification) {
        liveResizing.windowWillStartLiveResize(notification)
    }
}
