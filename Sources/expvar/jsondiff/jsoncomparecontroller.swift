// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// This outline table presents information for two JSON node trees at a time.
// We call the first the subtrahend and the second the minuend because
// we also show the difference of subtracting the subtrahend from the minuend.
//
// Generally, the subtrahend is shown first and the minuend second, and only when
// the value differs from the subtrahend.
//
// Four column types are defined, one for each column of the outline table.
// The order of the components within these two enums is not important, nor the
// fact that the names subtrahend and minuend appear in both.

enum NodeType {
    case subtrahend
    case minuend
}

enum ColumnStringValueType {
    case name
    case subtrahend
    case minuend
    case diff
}

// A skeleton of the first JSON node tree is built for traversal by the outline table.
// The actual JSON trees being received start off as the minuend, then essentially slide
// down to become the subtrahend, then slide off the scale and get reclaimed by the GC.
//
// The skeleton is built to allow traversal down as new nodes are placed in the minuend
// and subtrahend positions, and to allow traversal up as the outline table wants to
// display info and the stringValues have to be computed for whichever nodes are currently
// defined as the two in play.
//
// NodeParents and ParentBonds are accessed by their children, they allow traversing up
// the skeleton tree.

protocol NodeParent: class {
    var name: String { get }
    func node(_: NodeType) -> Any?      // Ask parent for their minuend or subtrahend node
}

// The ParentBond protocol is what lets us differentiate between two types of Child,
// the Child or an array and the Child of a dictionary. The two classes that use this
// protocol manage the detail differences.

protocol ParentBond {
    var parentName: String { get }
    var ownName: String { get }
    func node(_: NodeType) -> Any?      // Ask parent for their minuend or subtrahend node
}

// The OutlineItem protocol is required for the four outline table columns to pull the necessary
// information for any particular row. The rows are OutlineItems, by the definition in this file.
// Aside from the four stringValues available for any row, all the other outline table needs are
// served by having access to the children array for the row. The outline table doesn't care what
// type is for the children anyway, so an array of Any? can be returned.
protocol OutlineItem {
    func stringValue(_: ColumnStringValueType) -> String

    func outlineChildren() -> [Any]?
}

// class CanHaveChildren, used by the RootNode class and the Child class, defines the optional
// children array and the method for creating the children from a JSON node.
// The children are created either as children of an array or a dictionary, the only two JSON collections.
class CanHaveChildren {
    var children: [Child]?

    func createChildren(forParent: NodeParent, subtrahend: Any?) {
        switch subtrahend {
        case let array as [Any?]:
            self.initArrayChildren(forParent: forParent, array)

        case let dictionary as [String: Any?]:
            self.initDictionaryChildren(forParent: forParent, dictionary)

        default:
            // Other types of json node are containers, no children. Leave the children reference nil.
            break
        }
    }

    private func initArrayChildren(forParent: NodeParent, _ array: [Any?]) {
        children = []

        for i in 0..<array.count {
            // Even a value of nil, if coming from an array entry, is worthy of a child entry.
            let child = Child(subtrahend: array[i],
                              parentBond: ArrayParentBond(parent: forParent, index: i))
            children!.append(child)
        }
    }

    private func initDictionaryChildren(forParent: NodeParent, _ dictionary: [String: Any?]) {
        children = []

        for (key, value) in dictionary {
            // Even a value of nil, if coming from the dictionary, is worthy of a child entry.

            let child = Child(subtrahend: value,
                              parentBond: DictionaryParentBond(parent: forParent, key: key))
            children!.append(child)
        }

        // Sort the children by name, mapping their names to ordering values gotten from config.

        let ordering = config.jsonOrdering()

        children!.sort {
            return (ordering[$0.name] ?? Int.min) < (ordering[$1.name] ?? Int.min)
        }
    }
}

struct NodeString {
    var node: Any?
    var string: String?
    mutating func clear() {
        node = nil
        string = nil
    }
    mutating func computeString(name: String) {
        if string == nil {
            string = (node == nil) ? "missing node" : jsonConfig.format(name: name, json: node)
        }
    }
}

// A Child is used for every node in the skeleton except the top node, the RootNode.
// A Child node will represent an array or a dictionary if it is not a leaf of the tree.
// Leaves, for the strings, numbers, booleans and nils of the JSON tree are also Child instances.
class Child: CanHaveChildren, OutlineItem, NodeParent {
    private let parentBond: ParentBond
    lazy var name: String = { return parentBond.ownName }()
    private var subtrahend: NodeString
    private var minuend: NodeString
    private var diff: String?

    init(subtrahend: Any?, parentBond: ParentBond) {
        self.parentBond = parentBond
        self.minuend = NodeString(node: nil, string: nil)
        self.subtrahend = NodeString(node: subtrahend, string: nil)
        super.init()
        self.createChildren(forParent: self, subtrahend: subtrahend)
    }

    // clearCache clears own cache and its children caches.
    // A small efficiencty, it does not clear children if own is already clear.
    // It is expected that most nodes in the skeleton will not be visible in the outline table
    // and hence will not require detious tree traversals.
    func clearCache(_ type: NodeType) {
        switch type {
        case .subtrahend:
            if self.subtrahend.node == nil {
                return
            }
            self.subtrahend.clear()
            self.diff = nil

        case .minuend:
            if self.minuend.node == nil {
                return
            }
            self.minuend.clear()
            self.diff = nil
        }
        if let children = self.children {
            for child in children {
                child.clearCache(type)
            }
        }
    }

    // stringValue returns the string used for a particular row in the outline table.
    // The outline controller and columns do not interprete the data, that is left
    // for this class.
    func stringValue(_ stringValueType: ColumnStringValueType) -> String {
        switch stringValueType {
        case .name:
            return self.name
        case .subtrahend:
            loadCache()
            return subtrahend.string!
        case .minuend:
            loadCache()
            // Return the miuend string unless it is the same as the subtrahend string.
            return (minuend.string == subtrahend.string) ? "" : minuend.string!
        case .diff:
            loadCache()
            return diff!
        }
    }

    // The outline view has requirest a row/column value but we expect all the columns will
    // be requested so it doesn't matter which was requested first, we compute all of them at once.
    private func loadCache() {
        if subtrahend.string == nil ||
           minuend.string == nil ||
           diff == nil {

            let name = self.name

            _ = self.node(.subtrahend)
            subtrahend.computeString(name: name)

            _ = self.node(.minuend)
            minuend.computeString(name: name)

            if minuend.string != subtrahend.string &&
                subtrahend.node != nil &&
                minuend.node != nil {
                diff = jsonConfig.diff(name: self.name, minuend: minuend.node, subtrahend: subtrahend.node)
            } else {
                diff = ""
            }
        }
    }

    // Convenient that we can return an optional array of Child as an optional array of optional Any.
    // Doesn't really matter what the types are here. They are counted and given individually as opaque
    // references to the outline view. We cast them back when the any item is given us by the outline view.
    func outlineChildren() -> [Any]? {
        return self.children
    }

    // Ask parent, via the bond we have with the parent, for their subtrahend or minuend node.
    func node(_ type: NodeType) -> Any? {
        switch type {
        case .minuend:
            if minuend.node == nil {
                minuend.node = parentBond.node(type)
            }
            return minuend.node
        case .subtrahend:
            if subtrahend.node == nil {
                subtrahend.node = parentBond.node(type)
            }
            return subtrahend.node
        }
    }
}

// RootNode is not a child, but conforms to the other necessary protocols to be
// used as the root of the outline table.
class RootNode: CanHaveChildren, OutlineItem, NodeParent {
    init(subtrahend: Any?) {
        self.subtrahend = subtrahend
        super.init()
        self.createChildren(forParent: self, subtrahend: subtrahend)
    }
    var name: String { return "root" } // Is not displayed anywhere anyway.
    var subtrahend: Any? {
        didSet {
            if let children = self.children {
                for child in children {
                    child.clearCache(.subtrahend)
                }
            }
        }
    }
    var minuend: Any? {
        didSet {
            if let children = self.children {
                for child in children {
                    child.clearCache(.minuend)
                }
            }
        }
    }

    func node(_ type: NodeType) -> Any? {
        switch type {
        case .subtrahend:
            return subtrahend
        case .minuend:
            return minuend
        }
    }

    func stringValue(_ stringValueType: ColumnStringValueType) -> String {
        switch stringValueType {
        case .name:
            return self.name
        case .minuend:
            return "root minuend"
        case .subtrahend:
            return "root subtrahend"
        case .diff:
            return "root diff"
        }
    }

    func outlineChildren() -> [Any]? {
        return self.children
    }
}

class ArrayParentBond: ParentBond {
    private weak var parent: NodeParent?
    private let index: Int
    private var nameI: String?

    init(parent: NodeParent, index: Int) {
        self.parent = parent
        self.index = index
    }

    var parentName: String { return parent?.name ?? "" }
    var ownName: String {
        guard let parent = parent else {
            return ""
        }
        if nameI == nil {
            nameI = "\(parent.name)[\(index)]"
        }
        return nameI!
    }
    // Get the node of the given type from parent.
    func node(_ type: NodeType) -> Any? {
        return self.indexed(parent?.node(type))
    }

    // Extract node from the array given the index this bond was created with.
    private func indexed(_ json: Any?) -> Any? {
        if let array = json as? [Any?],
            index >= 0 && index < array.count {
                return array[index]
        }
        return nil
    }
}

class DictionaryParentBond: ParentBond {
    private weak var parent: NodeParent?
    private let key: String

    init(parent: NodeParent, key: String) {
        self.parent = parent
        self.key = key
    }

    var parentName: String { return parent?.name ?? "" }
    var ownName: String { return key }

    // Get the node of the given type from parent.
    func node(_ type: NodeType) -> Any? {
        return self.keyed(parent?.node(type))
    }

    // Extract node from the dictionary given the key this bond was created with.
    private func keyed(_ json: Any?) -> Any? {
        if let dictionary = json as? [String: Any?] {
            return dictionary[self.key] ?? nil
        }
        return nil
    }
}

private class JsonConfig {
    typealias FormatFn = (String, Any?) -> String?
    typealias DiffFn = (String, Any?, Any?) -> String?

    var formatMap: [String: FormatFn] = [:]
    var diffMap: [String: DiffFn] = [:]

    private var done = false

    func setup() {
        if done {
            return
        }
        done = true

        let dateFields = config.find("windows", "json", "date-fields") as? [String] ?? []
        let boolFields = config.find("windows", "json", "bool-fields") as? [String] ?? []
        let doubleFields = config.find("windows", "json", "double-fields") as? [String] ?? []

        let doubleFormatFn = { (_ name: String, _ json: Any?) -> String? in
            if let double = json as? Double {
                return toStringDouble(double)
            }
            return nil
        }

        let doubleDiffFn = { (_ name: String, _ minuend: Any?, _ subtrahend: Any?) -> String? in
            if let minuendD = minuend as? Double,
               let subtrahendD = subtrahend as? Double {
                return toStringDouble(minuendD - subtrahendD)
            }
            return nil
        }

        let boolFormatFn = { (_ name: String, _ json: Any?) -> String? in
            if let bool = json as? Bool {
                return String(describing: bool)
            }
            return nil
        }

        let boolDiffFn = { (_ name: String, _ minuend: Any?, _ subtrahend: Any?) -> String? in
            if let minuendB = minuend as? Bool {
                return String(describing: minuendB)
            }
            return nil
        }

        let dateFormatFn = { (_ name: String, _ json: Any?) -> String? in
            if let int64 = json as? Int64 {
                return toStringDate(int64)
            }
            return nil
        }

        let dateDiffFn = { (_ name: String, _ minuend: Any?, _ subtrahend: Any?) -> String? in
            if let minuendDate = minuend as? Int64,
               let subtrahendDate = subtrahend as? Int64 {
                return toStringDuration(minuendDate - subtrahendDate)
            }
            return nil
        }

        for field in doubleFields {
            formatMap[field] = doubleFormatFn
            diffMap[field] = doubleDiffFn
        }
        for field in boolFields {
            formatMap[field] = boolFormatFn
            diffMap[field] = boolDiffFn
        }
        for field in dateFields {
            formatMap[field] = dateFormatFn
            diffMap[field] = dateDiffFn
        }
    }

    func format(name: String, json: Any?) -> String {
        switch json {
        case let array as [Any?]:
            return "array[\(array.count)]"
        case let dictionary as [String: Any?]:
            return "dictionary[\(dictionary.count)]"
        case let string as String:
            return string
        case let number as NSNumber:
            // Look up field name and try to convert.
            if let fn = formatMap[name],
               let result = fn(name, json) {
                return result
            }

            // Else try to treat as Int64.
            if let int64 = number as? Int64 {
                return toStringInt64(int64)
            }

            // Else most generically.
            return String(describing: number)
        case let bool as Bool:
            return String(describing: bool)
        case nil:
            return "nil"
        default:
            return "unknown type " + String(describing: json)
        }
    }

    func diff(name: String, minuend: Any?, subtrahend: Any?) -> String {
        switch minuend {
        case is [Any?]:
            return "" // Don't try to show differences between arrays.
        case is [String: Any?]:
            return "" // Don't try to show differences between dictionaries.
        case is String:
            return "" // Don't try to create a difference when the type is String, user will see difference.
        case is NSNumber:
            // Look up field name and try to convert.
            if let fn = diffMap[name],
               let result = fn(name, minuend, subtrahend) {
                return result
            }

            // Else try to treat as Int64.
            if let minuendI = minuend as? Int64,
               let subtrahendI = subtrahend as? Int64 {
                return toStringInt64(minuendI - subtrahendI)
            }

            // Else most generically.
            if let minuendF = minuend as? Float,
               let subtrahendF = subtrahend as? Float {
                return String(describing: (minuendF - subtrahendF))
            }

            return "" // Just give up and don't show a difference.
        case let bool as Bool:
            return String(describing: bool) // Show the second value again.
        case nil:
            return "nil"
        default:
            return "unknown type " + String(describing: minuend)
        }
    }
}

private var jsonConfig = JsonConfig()

class TableJsonCompare: Outline {
    private weak var connection: Connection? // Weak, so if endpoint is deleted, connection is reclaimed. Window can survive but gets no more updates.
    let root: RootNode
    init(connection: Connection, nodes: [JsonDict]) {
        jsonConfig.setup()

        self.connection = connection

        guard nodes.count == 2 else {
            fatalError("expected two nodes")
        }
        let root = RootNode(subtrahend: nodes[0])
        root.minuend = nodes[1]

        self.root = root // root also captured in closures

        super.init(outlineFn: OutlineFn(
            isItemExpandable: {(any: Any) -> Bool in
                // TBD was
                // guard let item = any as? CompareTableItem else { fatalError("bad type") }
                // return item.isItemExpandable()

                guard let item = any as? OutlineItem else { fatalError("bad type") }

                // Return true, when there is an array and the number is nonzero.
                return (item.outlineChildren()?.count ?? 0) > 0
            },

            numberOfChildrenOfItem: {(any: Any?) -> Int in
                //guard let item = (any ?? root) as? CompareTableItem else { fatalError("bad type") }
                //guard let children = item.children else {
                //    fatalError("call numberOfChildrenOfItem not expected")
                //}
                //return children.count

                guard let item = (any ?? root)  as? OutlineItem else { fatalError("bad type") }

                return item.outlineChildren()?.count ?? 0
            },

            child: {(index: Int, any: Any?) -> Any in
                //guard let item = (any ?? root) as? CompareTableItem else { fatalError("bad type") }
                guard let item = (any ?? root)  as? OutlineItem else { fatalError("bad type") }
                guard let children = item.outlineChildren() else {
                    fatalError("call child not expected")
                }
                guard index >= 0 && index < children.count else {
                    fatalError("child index out of range")
                }
                return children[index]
            },

            objectValueFor: {(tableColumn: NSTableColumn?, any: Any?) -> Any? in
                // guard let item = (any ?? root) as? CompareTableItem else { fatalError("bad type") }

                // // TBD could have different column types and do something different for each.

                // guard let tableJsonColumn = tableColumn as? TableCompareColumn else {
                //     fatalError("bad column type")
                // }
                // let result = tableJsonColumn.stringValueFn(item)
                // return result
                guard let item = (any ?? root) as? OutlineItem else { fatalError("bad type") }
                guard let tableJsonColumn = tableColumn as? TableCompareColumn else {
                    fatalError("bad column type")
                }
                return item.stringValue(tableJsonColumn.stringValueType)
            }
            ))
        //weakLinks.add(self, self.root)
    }

    private static let columnDescs: [TableCompareColumnDesc] = [
        TableCompareColumnDesc(title: "JSON Field",
                        tooltip: "The field within the JSON data",
                        alignment: .right,
                        stringValueType: .name),
        TableCompareColumnDesc(title: "Prev Value",
                        tooltip: "The JSON value from the previous of the JSON node being compared",
                        alignment: .left,
                        stringValueType: .subtrahend),
        TableCompareColumnDesc(title: "Next Value (if different)",
                        tooltip: "The JSON value from the next version of the JSON node being compared",
                        alignment: .left,
                        stringValueType: .minuend),
        TableCompareColumnDesc(title: "Delta",
                        tooltip: "The difference between the two JSON versions being compared",
                        alignment: .left,
                        stringValueType: .diff)
        ]
    //var outlineview: NSOutlineView?
    func bindWith(_ outlineview: NSOutlineView) {
        //outlineview.delegate = self
        outlineview.dataSource = self

        var index = 0
        for desc in TableJsonCompare.columnDescs {
            let tableColumn = TableCompareColumn(desc: desc)

            if index == 1 {
                // Pick the second column to put the outline arrays on.
                outlineview.outlineTableColumn = tableColumn
            }
            index += 1

            config.adjust(column: tableColumn, forWindow: "json")

            // Bind in both directions.
            tableColumn.tableView = outlineview
            outlineview.addTableColumn(tableColumn)
        }

        outlineview.target = self
        outlineview.doubleAction = #selector(doubleClick(_:))
    }
    @objc func doubleClick(_ sender: AnyObject) {
        click(sender, single: false)
    }

    private func click(_ sender: AnyObject, single: Bool) {
        guard let outlineview = sender as? NSOutlineView else {
            print("sender expected to be NSOutlineView")
            return
        }

        // clickedRow is -1 when column header is clicked
        let clickedRow = outlineview.clickedRow

        guard let row = outlineview.item(atRow: clickedRow) as? OutlineItem else {
            return
        }

        let clickedColumn = outlineview.clickedColumn
        // columns can be reordered.
        guard clickedColumn >= 0, clickedColumn < outlineview.tableColumns.count else {
              return
        }
        guard let column = outlineview.tableColumns[clickedColumn] as? TableCompareColumn else {
            fatalError("bad tableColumn type")
        }
        guard let connection = self.connection else {
            print("connection has been closed") // endpoint was deleted, but user hasn't closed window.
            return
        }

        // create closure for column and row
        // that performs the makeView call for the user NSTableView

        let addcell = TableUserCell(
            TableUserCellDescription(
                UserColumnDesciption(
                        headerAlignment: column.headerCell.alignment,
                        title: column.title,
                        headerToolTip: column.headerToolTip,
                        identifier: column.identifier),
                UserRowDesciption(name: row.stringValue(.name))),
            cellViewFn: { (_ tableView: NSTableView) -> NSView? in
                let id = column.identifier

                let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField ?? NSTextField()

                cell.identifier = id
                cell.alignment = column.headerCell.alignment
                cell.stringValue = row.stringValue(column.stringValueType)
                return cell
            })
        // NB This cell stops seeing new values if the controller responsible for updating the subtrahend or
        // minuend is reclaimed. This could be averted by storing the controller's reference along with the
        // addcell, but then the controller doesn't get reclaimed when the user closes the window.
        // So to keep things more consistent for the user (who doesn't want to know about references being retained),
        // the controller is retained by the connection again, like it was in the beginning.
        // But that means the windows disappear when the endpoint is deleted.
        let errormsg = connection.addCell(addcell)
        if errormsg != nil {
            print("addCell error: ", errormsg!)
        }
    }
}

// Helper struct and class.
// TableCompareColumnDesc acts as the descriptor for a column to be created.
// This provides that each endpoint's JSON table uses its own columns and when a columns's
// property, such as its isHidden, is changed, it doesn't affect the other JSON tables.
struct TableCompareColumnDesc {
    let title: String
    let tooltip: String?
    let alignment: NSTextAlignment
    let stringValueType: ColumnStringValueType
}

class TableCompareColumn: NSTableColumn {
    //typealias StringValueFn = (_ item: CompareTableItem) -> String
    //let stringValueFn: StringValueFn
    let stringValueType: ColumnStringValueType

    init(desc: TableCompareColumnDesc) {
        self.stringValueType = desc.stringValueType
        super.init(identifier: NSUserInterfaceItemIdentifier(desc.title))
        self.title = desc.title
        self.headerToolTip = desc.tooltip
        self.headerCell.alignment = desc.alignment
    }
    required init(coder decoder: NSCoder) {
        fatalError("not implemented")
    }
}

class JSonCompareViewController: SubviewViewController {
    private let observable: VarsObservable
    private let table: TableJsonCompare
    private weak var tableview: NSOutlineView?
    private weak var versionsField: NSTextField?

    // How the resetManualButton isEnabled property gets set is special.
    // It tracks the state of the nextTail reference. And the nextTail
    // gets set when there is a refresh and cleared when there is a reset.
    // Here the swift didSet feature is used to tie one variable that really
    // gets used for data flow, to a button property.
    var autoReset: Bool
    weak var resetManualButton: SimpleButton?
    var nextTail: Any? {
        didSet {
            resetManualButton?.isEnabled = (nextTail != nil)
        }
    }

    init(observable: VarsObservable,
         tableview: NSOutlineView,
         table: TableJsonCompare,
         versionsField: NSTextField) {
        self.observable = observable
        self.table = table
        self.tableview = tableview
        self.versionsField = versionsField
        self.autoReset = true

        super.init(subview: NSView()) // subview is a placeholder
    }
    required init?(coder decoder: NSCoder) { fatalError("not implemented") }

    // manual and auto refresh do the same for now.
    func manualRefresh() {
        self.refresh()
    }

    func autoRefresh() {
        self.refresh()
    }

    func manualReset() {
        self.reset()
        self.tableview?.reloadData()
    }

    private func refresh() {
        self.nextTail = self.table.root.minuend

        self.table.root.minuend = observable.varsHistory.lastJsonDict

        if self.autoReset {
            self.reset()
        }
        // TBD remove the field
        // // Display the number of versions stored.
        // self.versionsField?.intValue = Int32(self.table.root.versions.count)

        self.tableview?.reloadData() // manually called because auto update can be disabled
    }

    private func reset() {
        if self.nextTail != nil {
            self.table.root.subtrahend = self.nextTail
            self.nextTail = nil
        }
    }
}

class JsonCompareController: NSObject {
    //private var strongSelf: JsonCompareController?
    private var viewController: JSonCompareViewController?
    private var controller: NSWindowController?
    private let flagButtons: Buttons
    private let refreshButtons: Buttons
    private let refreshCheckButton: SimpleButton
    private let refreshManualButton: SimpleButton
    private let resetButtons: Buttons
    private let diffColumnButton: NSButton
    private let panel: NSView

    init(description: String, instance: Int, frames: Frames,
         connection: Connection, observable: VarsObservable,
         nodes: [JsonDict]) {

        guard nodes.count == 2 else {
            fatalError("only support comparison between two JSON nodes")
        }

        let tableview = NSOutlineView()
        tableview.columnAutoresizingStyle = .noColumnAutoresizing

        let table = TableJsonCompare(connection: connection, nodes: nodes)
        table.bindWith(tableview)
        // Start off hiding the last column, the Diffs column.
        tableview.tableColumns.last?.isHidden = true

        // Panel frame, button area, creation of buttons, tableview frame, scrollTableView.

        let offset = CGPoint(x: 100, y: 100)
        let configName = config.jsonConfigName
        let contentRect = config.frame(
            windowName: configName,
            frames: frames,
            relativeScreen: false,
            top: false,
            size: defaultContentRect.size,
            offset: offset,
            instanceOffset: offset,
            instance: instance)

        let panel = makeResizingView()
        self.panel = panel
        self.panel.frame.origin = CGPoint(x: 0, y: 0)
        self.panel.frame.size = contentRect.size

        let font = NSFont.systemFont(ofSize: 12)

        let buttonAreaHeight: CGFloat = 36
        let automanualSpacing: CGFloat = 2
        let gapBetweenCheckManualGroups: CGFloat = 15
        let buttonY: CGFloat = 10

        // Draw the "Versions:" on the panel.

        let versionsLabel: NSTextField = {
            let t = NSTextField()
            t.font = font
            t.isBordered = false
            t.isSelectable = false
            t.drawsBackground = false
            t.frame.origin = CGPoint(x: 10, y: buttonY)
            t.stringValue = "Versions:"
            t.sizeToFit()
            // TBD For now, just don't show it. Either get rid of it, or use the field/counter for something useful.
            // panel.addSubview(t)
            return t
        }()

        // Draw the number of versions on the panel.

        var newX = versionsLabel.frame.maxX

        let versionsField: NSTextField = {
            let t = NSTextField()
            t.font = font
            t.isBordered = false
            t.isSelectable = false
            t.drawsBackground = false
            t.frame.origin = CGPoint(x: newX, y: buttonY)
            t.intValue = 999
            t.sizeToFit() // size with temporarily large value
            t.intValue = 0
            // TBD For now, just don't show it.
            // panel.addSubview(t)
            return t
        }()

        // Create view controller to allow binding it from the button closures
        // being created next.

        let viewController = JSonCompareViewController(
                                observable: observable,
                                tableview: tableview,
                                table: table,
                                versionsField: versionsField)

        newX = versionsField.frame.maxX + gapBetweenCheckManualGroups

        // Setup the Reset Buttons

        self.resetButtons = Buttons(origin: CGPoint(x: newX, y: buttonY), spacing: automanualSpacing)
        let (_, _, resetManualButton) =
            self.resetButtons.addCheckManual(
                    title: "Auto Reset:",
                    checkTitle: "Pause",
                    manualTitle: "Manual",
                    check: {[weak viewController] (_: NSButton, _ check: NSButton, _ manual: NSButton) -> Void in
                        viewController?.autoReset = check.state == .off
                    },
                    manual: {[weak viewController] (_: NSButton, _: NSButton, _: NSButton) in
                        viewController?.manualReset()
                    })
        viewController.resetManualButton = resetManualButton
        viewController.resetManualButton?.isEnabled = false

        newX = (self.resetButtons.list.last?.frame.maxX ?? 10) + gapBetweenCheckManualGroups

        // Setup the Refresh Buttons

        self.refreshButtons = Buttons(origin: CGPoint(x: newX, y: buttonY), spacing: automanualSpacing)
        (_, self.refreshCheckButton, self.refreshManualButton) =
            self.refreshButtons.addCheckManual(
                title: "Auto Refresh:",
                checkTitle: "Pause",
                manualTitle: "Manual",
                check: {[weak viewController] (_: NSButton, _ check: NSButton, _ manual: NSButton) in
                    // Turning this on when the manual button had been enabled triggers
                    // a manualRefresh once. Afterwards, automatic refreshes take place.

                    if check.state == .off && manual.isEnabled {
                        viewController?.manualRefresh() // manual caused by disabling pause
                    }

                    manual.isEnabled = false // always starts off false, wait for data available
                },
                manual: {[weak viewController] (_: NSButton, _: NSButton, _ manual: NSButton) in
                    viewController?.manualRefresh()
                    manual.isEnabled = false // starts off false again, wait for more data available
                })
        self.refreshManualButton.isEnabled = false

        newX = (self.refreshButtons.list.last?.frame.maxX ?? 10) + gapBetweenCheckManualGroups

        // Setup the flag button

        self.flagButtons = Buttons(origin: CGPoint(x: newX, y: buttonY), spacing: automanualSpacing)

        self.diffColumnButton =
            self.flagButtons.add(title: "Delta Column", font: font) {[weak tableview] (_ b: NSButton) -> Void in
                guard let tableview = tableview else {
                    return
                }
                let index = tableview.tableColumns.count - 1
                guard index > 0 else {
                    return
                }

                tableview.tableColumns[index].isHidden = (b.state == .off)
            }
        self.diffColumnButton.setButtonType(.onOff) // .onOff keeps button darker when selected

        newX = (self.flagButtons.list.last?.frame.maxX ?? 10) + gapBetweenCheckManualGroups

        // Setup the tableview position

        tableview.frame.size = self.panel.frame.size
        tableview.frame.origin.y = buttonAreaHeight
        tableview.frame.size.height -= buttonAreaHeight

        let scrollTableView = ScrollTableView(tableview: tableview)

        // Add buttons and scrollTableView to panel
        // and then create the view controller for the panel.

        self.panel.addSubviews(self.flagButtons.list)
        self.panel.addSubviews(self.refreshButtons.list)
        self.panel.addSubviews(self.resetButtons.list)

        self.panel.addSubview(scrollTableView)

        self.viewController = viewController

        viewController.subview = self.panel

        super.init()

        observable.observers.add(self) // I am the observer, not the tableview as in other places

        let window = viewController.makeWindow(title: description,
                                               configName: configName,
                                               contentRect: contentRect,
                                               delegate: self)

        liveResizing.track(window: window)

        self.controller = NSWindowController(window: window)
        // Now don't create a cycle to self. The connection retains it.
        //self.strongSelf = self

        /*
        weakLinks.add(
            tableview,
            self.strongSelf,
            self.viewController,
            self.controller,
            self.flagButtons,
            self.refreshButtons,
            self.refreshCheckButton,
            self.refreshManualButton,
            self.resetButtons,
            self.diffColumnButton,
            self.panel)
        */
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

extension JsonCompareController: ReloadDataObserver {
    func reloadData() {
        // Let the trickle down begin, or not, depending on the auto refresh state.
        if self.refreshCheckButton.state == .off {
            // Pause being off means auto refresh is on.
            self.viewController?.autoRefresh()
        } else {
            // Enable the manual refresh button.
            self.refreshManualButton.isEnabled = true // Data is available for refresh.
        }
    }
}

private var liveResizing = LiveResizing()

extension JsonCompareController: NSWindowDelegate {

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
