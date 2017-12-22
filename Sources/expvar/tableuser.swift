// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TableUser manages a configurable set of cells for display as a table
// Columns and rows are created as needed.

import AppKit

// Helper class.
class UserColumnDesciption {
    let headerAlignment: NSTextAlignment
    let title: String
    let headerToolTip: String?
    let identifier: NSUserInterfaceItemIdentifier
    init(headerAlignment: NSTextAlignment,
         title: String,
         headerToolTip: String?,
         identifier: NSUserInterfaceItemIdentifier) {
        self.headerAlignment = headerAlignment
        self.title = title
        self.headerToolTip = headerToolTip
        self.identifier = identifier
    }

    func matches(_ other: UserColumnDesciption) -> Bool {
        return
            self.headerAlignment == other.headerAlignment &&
            self.title == other.title &&
            self.headerToolTip == other.headerToolTip &&
            self.identifier == other.identifier
    }
    var hashValue: Int {
        // TBD add primes later
        return
            self.headerAlignment.hashValue ^
            self.title.hashValue ^
            (self.headerToolTip?.hashValue ?? 0) ^
            self.identifier.hashValue
    }
}

// Helper class.
class UserRowDesciption {
    let name: String
    init(name: String) {
        self.name = name
    }

    func matches(_ other: UserRowDesciption) -> Bool {
        return
            self.name == other.name
    }
    var hashValue: Int {
        return self.name.hashValue
    }
}

class TableUserCellDescription {
    let columnDescription: UserColumnDesciption
    let rowDescription: UserRowDesciption

    init(_ columnDescription: UserColumnDesciption,
         _ rowDescription: UserRowDesciption) {

        self.columnDescription = columnDescription
        self.rowDescription = rowDescription
    }
}

extension TableUserCellDescription: Hashable {
    var hashValue: Int {
        return columnDescription.hashValue ^ rowDescription.hashValue
    }
    static func == (lhs: TableUserCellDescription, rhs: TableUserCellDescription) -> Bool {
        return lhs.columnDescription.matches(rhs.columnDescription)
            && lhs.rowDescription.matches(rhs.rowDescription)
    }
}

class TableUserCell {
    typealias CellViewFn = (_ tableView: NSTableView) -> NSView?
    let description: TableUserCellDescription
    let cellViewFn: CellViewFn

    init(_ description: TableUserCellDescription, cellViewFn: @escaping CellViewFn) {
        self.description = description
        self.cellViewFn = cellViewFn
    }
}

class TableUserColumn: NSTableColumn {
    let columnDescription: UserColumnDesciption

    init(_ columnDescription: UserColumnDesciption) {
        self.columnDescription = columnDescription

        super.init(identifier: columnDescription.identifier)
        self.headerCell.alignment = columnDescription.headerAlignment
        self.title = columnDescription.title
        self.headerToolTip = columnDescription.headerToolTip
    }
    required init(coder decoder: NSCoder) {
        fatalError("not implemented")
    }
    func matches(_ columnDescription: UserColumnDesciption) -> Bool {
        return self.columnDescription.matches(columnDescription)
    }
}

class TableUserRow {
    let rowDescription: UserRowDesciption

    init(_ rowDescription: UserRowDesciption) {
        self.rowDescription = rowDescription
    }
    func matches(_ rowDescription: UserRowDesciption) -> Bool {
        return self.rowDescription.matches(rowDescription)
    }
}

class TableUser: NSObject {
    private var tableview: NSTableView
    private var rows: [TableUserRow] = []
    private var map: [TableUserCellDescription: TableUserCell] = [:]
    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("UserNameId"))

    init(_ tableview: NSTableView) {
        self.tableview = tableview

        super.init()

        tableview.delegate = self
        tableview.dataSource = self

        addNameColumn()
    }

    private func addNameColumn() {
        self.nameColumn.title = "Name"
        self.nameColumn.headerToolTip = "Name of rows user has selected from other tables"
        self.nameColumn.headerCell.alignment = .right
        self.nameColumn.width = 100

        // Bind in both directions.
        self.nameColumn.tableView = tableview
        tableview.addTableColumn(self.nameColumn)
    }

    func addCell(_ addcell: TableUserCell) -> String? {
        let cell = map[addcell.description]

        guard cell == nil else {
            return "row and column already exist"
        }

        let column = findOrCreateColumn(addcell.description.columnDescription)
        let row = findOrCreateRow(addcell.description.rowDescription)
        (_, _) = (column, row) // functions called for their side effects

        map[addcell.description] = addcell

        tableview.reloadData()

        return nil // success
    }

    private func findOrCreateColumn(_ columnDescription: UserColumnDesciption) -> TableUserColumn {

        // If found, just return it.
        if let column = findColumn(columnDescription) {
            return column
        }

        // Create and bind.
        let column = TableUserColumn(columnDescription)

        // config.adjust(column: tableColumn, forWindow: "user")

        // Bind in both directions.
        column.tableView = tableview
        tableview.addTableColumn(column)

        return column
    }
    private func findColumn(_ columnDescription: UserColumnDesciption) -> TableUserColumn? {

        for tableColumn in tableview.tableColumns {
            if let column = tableColumn as? TableUserColumn,
               column.matches(columnDescription) {
                   return column
            }
        }
        return nil
    }

    private func findOrCreateRow(_ rowDescription: UserRowDesciption) -> TableUserRow {

        // If found, just return it.
        if let row = findRow(rowDescription) {
            return row
        }
        
        // Create and append.
        let row = TableUserRow(rowDescription)

        rows.append(row)

        return row
    }

    private func findRow(_ rowDescription: UserRowDesciption) -> TableUserRow? {
        for row in rows {
            if row.matches(rowDescription) {
                   return row
            }
        }
        return nil
    }
}

extension TableUser: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor: NSTableColumn?, row rowIndex: Int) -> NSView? {
        guard rowIndex >= 0 && rowIndex < rows.count,
            let tableColumn = viewFor else {
            return nil
        }
        let row = rows[rowIndex]
        guard let column = tableColumn as? TableUserColumn else {

            guard tableColumn == self.nameColumn else {
                fatalError("bad column")
            }
            let id = tableColumn.identifier
            // It's the first column, pure NSTableColumn, not treated as user defined like the rest.
            let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField ?? NSTextField()

            cell.identifier = id
            cell.alignment = .right
            cell.stringValue = row.rowDescription.name
            return cell
        }

        let cellDesc = TableUserCellDescription(column.columnDescription, row.rowDescription)

        return map[cellDesc]?.cellViewFn(tableView)
    }
}

extension TableUser: NSTableViewDataSource {
    func numberOfRows(in: NSTableView) -> Int {
        return rows.count
    }
}

private var liveResizing = LiveResizing()

class TableUserController: NSObject {
    //private var strongSelf: TableUserController?
    let tableUser: TableUser
    private let viewController: TableViewController // TBD is this needed?
    private var controller: NSWindowController?

    init(description: String, instance: Int, frames: Frames, observable: VarsObservable?) {

        let newtableview = NSTableView()
        newtableview.columnAutoresizingStyle = .noColumnAutoresizing
        observable?.observers.add(newtableview)

        self.tableUser = TableUser(newtableview)

        let configName = config.userConfigName
        let contentRect = config.frame(
            windowName: configName,
            frames: frames,
            relativeScreen: true,
            top: false,
            size: CGSize(width: 450, height: 200),
            offset: CGPoint(x: 300, y: 0),
            instanceOffset: CGPoint(x: 40, y: 40),
            instance: instance)

        let viewController = TableViewController(tableview: newtableview)

        self.viewController = viewController
        super.init()

        let window = viewController.makeWindow(title: "User: " + description,
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
extension TableUserController: NSWindowDelegate {

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
