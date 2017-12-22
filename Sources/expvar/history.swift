// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

protocol Diffable {
    static var Zero: Self { get }
    static func - (lhs: Self, rhs: Self) -> Self
}

extension Int: Diffable {
    static var Zero: Int { return 0 }
}
extension Int32: Diffable {
    static var Zero: Int32 { return 0 }
}
extension UInt32: Diffable {
    static var Zero: UInt32 { return 0 }
}
extension Int64: Diffable {
    static var Zero: Int64 { return 0 }
}
extension UInt64: Diffable {
    static var Zero: UInt64 { return 0 }
}
extension Double: Diffable {
    static var Zero: Double { return 0 }
}

class HistoryStats {
    var depth: Int = 512 // was 4, keep small while debugging
}

// Occurrences tracks a value and how many consecutive additions
// were for the same value.
struct Occurrences<T: Equatable&Comparable&Diffable> {
    let value: T
    var occurrences: Int64
    init(_ v: T) {
        value = v
        occurrences = 0
    }
}

// Helper class.
class TableHistoryColumn<T: Equatable&Comparable&Diffable> {
    typealias StringValueFn = (_ history: History<T>, _ row: Int) -> String
    typealias IncludeMeFn = (_ history: History<T>, _ column: TableHistoryColumn<T>) -> Bool
    let title: String
    let tooltip: String?
    let headerAlignment: NSTextAlignment
    let alignment: NSTextAlignment
    let sort: NSSortDescriptor?
    let stringValueFn: StringValueFn
    let includeMeFn: IncludeMeFn

    let id: NSUserInterfaceItemIdentifier

    init(title: String, tooltip: String?,
         headerAlignment: NSTextAlignment,
         alignment: NSTextAlignment,
         sort: NSSortDescriptor?,
         stringValueFn: @escaping StringValueFn,
         includeMeFn: @escaping IncludeMeFn) {
        self.title = title
        self.tooltip = tooltip
        self.headerAlignment = headerAlignment
        self.alignment = alignment
        self.sort = sort
        self.stringValueFn = stringValueFn
        self.includeMeFn = includeMeFn
        self.id = NSUserInterfaceItemIdentifier(title)
    }
}

protocol HistoryTableProtocol: NSTableViewDelegate, NSTableViewDataSource {
    func bindWith(_ tableview: NSTableView)
}

protocol HistoryProtocol {
    func historyCurrentDescription() -> String
    func historyDeltaDescription() -> String
    func historyTable() -> HistoryTableProtocol
}

class HistoryTable<T: Equatable&Comparable&Diffable>: NSObject,
                            NSTableViewDelegate, NSTableViewDataSource, HistoryTableProtocol {
    private static var columns: [TableHistoryColumn<T>] {
        return [
            TableHistoryColumn<T>(title: "ReplaceMe", // Replace with history.name
                    tooltip: "Value of History Field",
                    headerAlignment: .center,
                    alignment: .right,
                    sort: nil,
                    stringValueFn: { (_ h: History<T>, _ row: Int) -> String in
                        guard row < h.array.count else { return "" }
                        return h.toString(h.array[row].value, .current)
                    },
                    includeMeFn: { (_ h: History<T>, _ column: TableHistoryColumn<T>) -> Bool in
                        return true
                    }),
            TableHistoryColumn<T>(title: "Times",
                    tooltip: "Occurrences of said value",
                    headerAlignment: .left,
                    alignment: .left,
                    sort: nil,
                    stringValueFn: { (_ h: History<T>, _ row: Int) -> String in
                        guard row < h.array.count else { return "" }
                        return "\(h.array[row].occurrences)"
                    },
                    // NB get this signature right or the compiler throws an error about another closure earlier in this structure.
                    includeMeFn: { (_ h: History<T>, _ column: TableHistoryColumn<T>) -> Bool in
                        // Include this column if there are any "rows" with a nonzero value.
                        for a in h.array where a.occurrences != 0 {
                            return true
                        }
                        return false
                    }),
            TableHistoryColumn<T>(title: "Delta",
                    tooltip: "Difference from previous value",
                    headerAlignment: .left,
                    alignment: .left,
                    sort: nil,
                    stringValueFn: { (_ h: History<T>, _ row: Int) -> String in
                        guard row > 0 && row < h.array.count else { return "" }
                        return h.toString(h.array[row].value - h.array[row-1].value, .delta)
                    },
                    includeMeFn: { (_ h: History<T>, _ column: TableHistoryColumn<T>) -> Bool in
                        return h.array.count > 1
                    })
        ]
    }
    private var columnMap: [NSUserInterfaceItemIdentifier: TableHistoryColumn<T>] = [:]
    // TBD can next history be made private too?
    let history: History<T> // TBD make weak and check

    init(_ history: History<T>) {
        self.history = history
        super.init()
    }
    func bindWith(_ tableview: NSTableView) {
        tableview.delegate = self
        tableview.dataSource = self

        for tableColumn in HistoryTable<T>.columns {

            // The occurrences column is superfluous for some history types.
            if !tableColumn.includeMeFn(history, tableColumn) {
                continue
            }

            // Dictionary install.
            columnMap[tableColumn.id] = tableColumn

            // Create NSTableColumn and bind it and tableview with each other.
            let column = NSTableColumn(identifier: tableColumn.id)
            column.headerCell.alignment = tableColumn.headerAlignment

            // Setting the Header
            column.title = (tableColumn.title == "ReplaceMe") ? history.name : tableColumn.title

            // Could use image and text table cell view
            // column.headerCell: NSTableHeaderCell // The cell used to draw the table column’s header.

            // Sorting

            column.sortDescriptorPrototype = tableColumn.sort // The table column’s sort descriptor prototype.
            // Setting Column Visibility
            // column.isHidden: Bool // A Boolean that indicates whether the table column is hidden.
            // Setting Tooltips
            // The string that’s displayed in a help tag over the table column header.
            column.headerToolTip = tableColumn.tooltip

            column.width = 185
            // TBD can this be specified by config file?
            // config.adjust(column: column, forWindow: "bysize")

            // Bind in both directions.
            column.tableView = tableview
            tableview.addTableColumn(column)
        }
    }
    // NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier,
            let column = columnMap[id] else {
            return nil
        }

        if let anycell = tableView.makeView(withIdentifier: id, owner: self) {
            if let cell = anycell as? NSTextField {
                cell.alignment = column.alignment
                cell.stringValue = column.stringValueFn(history, row)
                //print("cell reused")
                return cell
            } else {
                fatalError("anycell found but wrong type")
            }
        }
        let cell = NSTextField()
        cell.identifier = id
        cell.alignment = column.alignment
        cell.stringValue = column.stringValueFn(history, row)
        //print("cell \(cellCreationCount) created")
        //cellCreationCount += 1
        return cell
    }

    // NSTableViewDataSource
    func numberOfRows(in: NSTableView) -> Int {
        return self.history.array.count
    }

    // The least of my concerns - sorting history.
    // func tableView(_: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
    //     print("TableBySize.tableView(_,sortDescriptorsDidChange)")
    //     self.tableview?.reloadData()
    // }
}

enum HistoryDimension {
    case current
    case delta
}
class History<T: Equatable&Comparable&Diffable>: HistoryProtocol {
    typealias ToStringFn = (T, HistoryDimension) -> String

    let toString: ToStringFn
    let name: String
    var array = Array<Occurrences<T>>()
    var max: T
    var min: T

    var descriptionCurrent: String? // gets reset with each add
    var descriptionDelta: String? // gets reset with each add

    func historyTable() -> HistoryTableProtocol {
        return HistoryTable<T>(self)
    }

    init(_ stats: HistoryStats, _ value: T, name: String, toString: @escaping ToStringFn) {
        self.toString = toString
        self.name = name
        array.reserveCapacity(2 * stats.depth)
        array.append(Occurrences(value))
        max = value
        min = value
    }
    func add(_ stats: HistoryStats, _ value: T) {
        if value < min {
            min = value
        } else if max < value {
            max = value
        }
        descriptionCurrent = nil
        descriptionDelta = nil
        if array.count >= stats.depth && !array.isEmpty {
            array.removeFirst(1)
        }
        if array.capacity == array.count {
            var n = Array<Occurrences<T>>()
            // The trade-off.  How much reserve space to allocate
            // versus many many times are copies made.
            n.reserveCapacity(2 * stats.depth)
            //copy(n, array)
            //for i in array {
            for index in (array.count/2)..<array.count {
                let i = array[index]
                n.append(i)
            }
            array = n
        }
        assert(array.count > 0)
        let i = array.count-1
        if array[i].value == value {
            array[i].occurrences += 1
        } else {
            array.append(Occurrences(value))
        }
    }
    func top() -> T {
        guard array.count > 0 else {
            return T.Zero
        }
        let i = array.count-1
        return array[i].value
    }
    func reportIfLastDelta() -> (T, found: Bool, occurrences: Int64) {
        var value: T = T.Zero
        guard array.count > 0 else {
            return (value, false, 0)
        }
        let i = array.count-1
        let occurrences = array[i].occurrences

        guard array.count > 1 else { // need two for a difference
            return (value, false, occurrences)
        }
        if occurrences > 0 {
            return (value, false, occurrences)
        }
         value = array[i].value - array[i-1].value // Hence Diffable
         return (value, true, occurrences)
    }
    func printLastDelta(_ name: String) -> [Pair] {
        let (value, diffFound, _) = self.reportIfLastDelta()
        if diffFound {
            return [Pair(name, value)]
        }
        return []
    }
    private func computeDescriptions() {
        if array.count == 0 {
            descriptionCurrent = "no data"
            descriptionDelta = ""
            return
        }
        let i = array.count-1
        let (diffValue, diffFound, occurrences) = self.reportIfLastDelta()
        if diffFound {
            descriptionCurrent = toString(array[i].value, .current)
            descriptionDelta = toString(diffValue, .delta)
            return
        }
        descriptionCurrent = toString(array[i].value, .current)
        descriptionDelta = deltaDescriptionWhenNotFound(count: array.count, occurrences: occurrences)
    }
    func historyCurrentDescription() -> String {
        if descriptionCurrent == nil {
            self.computeDescriptions()
        }
        return descriptionCurrent!
    }
    func historyDeltaDescription() -> String {
        if descriptionDelta == nil {
            self.computeDescriptions()
        }
        return descriptionDelta!
    }
}
func deltaDescriptionWhenNotFound(count: Int, occurrences: Int64) -> String {
    if count == 1 {
        return "no change since first poll"
    }
    if occurrences == 1 {
        return "1 poll unchanged"
    }
    return "\(occurrences) polls unchanged"
}
