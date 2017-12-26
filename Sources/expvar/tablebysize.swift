// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TableBySize manages a particular data set and for it, it builds columns, and
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
// Delegate and DataSource
//  tableView(_: NSTableView, viewFor: NSTableColumn?, row: Int) -> NSView?
//  numberOfRows(in: NSTableView) -> Int
//  tableView(_: NSTableView, sortDescriptorsDidChange: [NSSortDescriptor])

import AppKit

// Helper class.
class TableBySizeColumn: NSTableColumn {
    typealias StringValueFn = (_ memStatsHistory: MemStatsHistory, _ row: Int) -> String
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

// Box a weak pointer that will be kept in a dictionary.
class TableBySizeBox {
    weak var handle: PopoverTable?
    init(_ handle: PopoverTable) {
        self.handle = handle
    }
}

class TableBySize: NSObject {
    private static let columns: [TableBySizeColumn] = [
        TableBySizeColumn(title: "Size",
                        tooltip: "/debug/vars top level dictionary name",
                        alignment: .right,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            guard row >= 0 && row < m.bySize.count else { return "" }
                            return "\(m.bySize[row].size)" // TBD store string in MySizeHistory
                        }),
        /*
         * First set doesn't look as nice as the third set, so commented out for now.
        TableBySizeColumn(title: "Malloc - Free",
                        tooltip: "For a given size, total mallocs, total frees, and their difference",
                        alignment: .right,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            return m.bySize[row].mallocsFrees.historyCurrentDescription() // TBD hack
                        }),
        TableBySizeColumn(title: "Change",
                        tooltip: "For a given size, last poll's change to mallocs, frees, and their difference",
                        alignment: .left,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            return m.bySize[row].mallocsFrees.historyDeltaDescription() // TBD hack
                        }),
        */
        /*
         * An intermediate build up that doesn't seem as good as either the first choice or the third.
        TableBySizeColumn(title: "Mallocs",
                        tooltip: "For a given size, total mallocs",
                        alignment: .right,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            return toStringInt(m.bySize[row].mallocsFrees.top().mallocs, .current)
                        }),
        TableBySizeColumn(title: "- Frees",
                        tooltip: "For a given size, total frees",
                        alignment: .left,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            return "- " + toStringInt(m.bySize[row].mallocsFrees.top().frees, .current)
                        }),
        TableBySizeColumn(title: "= Difference",
                        tooltip: "For a given size, total mallocs - frees",
                        alignment: .left,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            let top = m.bySize[row].mallocsFrees.top()
                            return "= " + toStringInt(top.mallocs - top.frees, .current)
                        }),
        */
        TableBySizeColumn(title: "Mallocs (delta)",
                        tooltip: "For a given size, total mallocs (and delta from last poll)",
                        alignment: .right,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            guard row >= 0 && row < m.bySize.count else { return "" }
                            let mf = m.bySize[row].mallocsFrees
                            let (delta, found, occurrences) = mf.reportIfLastDelta()
                            let current =  toStringInt(mf.top().mallocs, .current)
                            if found {
                                let deltaPart = delta.mallocs
                                var deltaPartStr = toStringInt(deltaPart, .delta)
                                if deltaPart > 0 {
                                    deltaPartStr = "+" + deltaPartStr
                                }
                                return "\(current) (\(deltaPartStr))"
                            }
                            return current
                        }),
        TableBySizeColumn(title: "- Frees (delta)",
                        tooltip: "For a given size, total frees (and delta from last poll)",
                        alignment: .left,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            guard row >= 0 && row < m.bySize.count else { return "" }
                            let mf = m.bySize[row].mallocsFrees
                            let (delta, found, occurrences) = mf.reportIfLastDelta()
                            var current = "- " + toStringInt(mf.top().frees, .current)
                            if found {
                                let deltaPart = delta.frees
                                var deltaPartStr = toStringInt(deltaPart, .delta)
                                if deltaPart > 0 {
                                    deltaPartStr = "+" + deltaPartStr
                                }
                                current += " (\(deltaPartStr))"
                            }
                            return current
                        }),
        TableBySizeColumn(title: "= Difference (delta)",
                        tooltip: "For a given size, total mallocs - frees (and delta from last poll)",
                        alignment: .left,
                        sort: nil,
                        stringValueFn: { (_ m: MemStatsHistory, _ row: Int) -> String in
                            guard row >= 0 && row < m.bySize.count else { return "" }
                            let mf = m.bySize[row].mallocsFrees
                            let top = mf.top()
                            let (delta, found, occurrences) = mf.reportIfLastDelta()
                            var current = "= " + toStringInt(top.mallocs - top.frees, .current)
                            if found {
                                let deltaPart = delta.mallocs - delta.frees
                                var deltaPartStr = toStringInt(deltaPart, .delta)
                                if deltaPart > 0 {
                                    deltaPartStr = "+" + deltaPartStr
                                }
                                current += " (\(deltaPartStr))"
                            } else {
                                let deltaPartStr = deltaDescriptionWhenNotFound(count: mf.array.count,
                                                                                occurrences: occurrences)
                                current += " (\(deltaPartStr))"
                            }
                            return current
                        })
    ]

    private weak var connection: Connection?
    private let observable: VarsObservable
    private weak var tableview: NSTableView?

    init(connection: Connection, observable: VarsObservable) {
        self.connection = connection
        self.observable = observable
    }

    // Bind NSTableColumn and tableview with each other.
    func bindWith(_ tableview: NSTableView) {
        tableview.delegate = self
        tableview.dataSource = self

        self.tableview = tableview // TBD remove this variable

        for tableColumn in TableBySize.columns {

            // Bind in both directions.
            tableColumn.tableView = tableview
            tableview.addTableColumn(tableColumn)
        }
        config.setColumnWidths(tableview.tableColumns,
                               forWindow: config.bySizeConfigName, defaultWidths: [55, 100, 100, 160])

        tableview.target = self
        tableview.action = #selector(singleClick(_:))
        tableview.doubleAction = #selector(doubleClick(_:))
    }

    var handles: [UInt32: TableBySizeBox] = [:]

    @objc func singleClick(_ sender: AnyObject) {
        guard let bysizetableview = self.tableview else {
            return
        }
        let row = bysizetableview.selectedRow

        guard row >= 0 && row < observable.varsHistory.memstats.bySize.count else { return }
        let bySizeHistory = observable.varsHistory.memstats.bySize[row]
        let rect = (bysizetableview.rowView(atRow: row, makeIfNecessary: false) ?? bysizetableview).frame

        if let box = handles[bySizeHistory.size],
           let handle = box.handle {
               handle.show(relativeTo: rect, of: bysizetableview)
           } else {

               // could make a title out of the bySizeHistory.size UInt32.

               let newtableview = NSTableView()
               observable.observers.add(newtableview)
               let table = bySizeHistory.mallocsFrees.historyTable()
               // Technically the table could be bound to multiple tableviews but the UI doesn't take
               // advantage of that yet. Just one for now.
               table.bindWith(newtableview)

               // No need to retain reference to popover.
               handles[bySizeHistory.size] = TableBySizeBox(PopoverTable(tableview: newtableview,
                   strong: table,
                   relativeTo: rect,
                   of: bysizetableview,
                   size: config.popoverSize(forWindow: "bysize", defaultSize: CGSize(width: 400, height: 0)),
                   intercellSpacing: config.popoverIntercellSpacing(forWindow: "bysize")
                   ))
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
        guard let column = tableview.tableColumns[clickedColumn] as? TableBySizeColumn else {
            fatalError("bad tableColumn type")
        }
        guard let connection = self.connection else {
            print("connection has been closed") // endpoint was deleted, but user hasn't closed window.
            return
        }

        // clickedRow is -1 when column header is clicked
        let clickedRow = tableview.clickedRow
        let observable = self.observable
        let m = observable.varsHistory.memstats
        guard clickedRow >= 0 && clickedRow < m.bySize.count else { return }
        let name = "\(m.bySize[clickedRow].size)"

        let addcell = TableUserCell(
            TableUserCellDescription(
                UserColumnDesciption(
                        headerAlignment: column.alignment,
                        title: column.title,
                        headerToolTip: column.headerToolTip,
                        identifier: column.identifier),
                UserRowDesciption(name: name)),
            cellViewFn: { (_ tableView: NSTableView) -> NSView? in
                return cellFn(tableView, column, clickedRow, observable)
            })
        let errormsg = connection.addCell(addcell)
        if errormsg != nil {
            print("addCell error: ", errormsg!)
        }
    }
}

private func cellFn(_ tableView: NSTableView, _ column: TableBySizeColumn, _ row: Int,
                    _ observable: VarsObservable) -> NSView? {
    let id = column.identifier

    let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField ?? NSTextField()

    cell.identifier = id
    cell.alignment = column.alignment
    cell.stringValue = column.stringValueFn(observable.varsHistory.memstats, row)
    return cell
}

extension TableBySize: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn as? TableBySizeColumn else {
            fatalError("bad tableColumn type")
        }
        return cellFn(tableView, column, row, observable)
    }
}

extension TableBySize: NSTableViewDataSource {

    func numberOfRows(in: NSTableView) -> Int {
        return self.observable.varsHistory.memstats.bySize.count
    }

    func tableView(_: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        print("TableBySize.tableView(_,sortDescriptorsDidChange)")
        self.tableview?.reloadData()
    }
}

private var liveResizing = LiveResizing()

class TableBySizeController: NSObject {
    //private var strongSelf: TableBySizeController?
    private let tableBySize: TableBySize // Need this one strong pointer.
    private let viewController: TableViewController // TBD is this needed?
    private var controller: NSWindowController?

    init(description: String, frames: Frames, connection: Connection, observable: VarsObservable) {

        let newtableview = NSTableView()
        newtableview.columnAutoresizingStyle = .noColumnAutoresizing
        observable.observers.add(newtableview)

        self.tableBySize = TableBySize(connection: connection, observable: observable)
        self.tableBySize.bindWith(newtableview)

        let configName = config.bySizeConfigName
        let contentRect = config.frame(
            windowName: configName,
            frames: frames,
            relativeScreen: true,
            top: false,
            size: CGSize(width: 450, height: 780),
            offset: CGPoint(x: 200, y: 0),
            instanceOffset: CGPoint(x: 40, y: 40),
            instance: connection.id)

        let viewController = TableViewController(tableview: newtableview)

        self.viewController = viewController
        super.init()

        let window = viewController.makeWindow(title: "BySize: " + description,
                                               configName: configName,
                                               contentRect: contentRect,
                                               delegate: self)
        liveResizing.track(window: window)
        self.controller = NSWindowController(window: window)
        //self.strongSelf = self
    }

    func show() {
        guard let controller = self.controller else {
            fatalError("controller lost")
        }
        let wasVisible = controller.window?.isVisible ?? false
        controller.showWindow(self)
        liveResizing.show(controller.window, wasVisibleBeforeShow: wasVisible)
    }
}
extension TableBySizeController: NSWindowDelegate {

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
