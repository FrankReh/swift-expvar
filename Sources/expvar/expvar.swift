// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

func toStringInt(_ value: Int, _ dimension: HistoryDimension) -> String {
    return String(format: "%d", locale: Locale.current, value)
}
func toStringInt64(_ value: Int64, _ dimension: HistoryDimension) -> String {
    return String(format: "%ld", locale: Locale.current, value)
}

// toStringInt64 is a public version used by the json formatting code.
func toStringInt64(_ value: Int64) -> String {
    return toStringInt64(value, .current)
}

private func myDateFormatter() -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone.current
    dateFormatter.timeStyle = .long
    dateFormatter.dateStyle = .short
    return dateFormatter
}
private let dateFormatter = myDateFormatter()
private func toStringDate(_ value: Int64, _ dimension: HistoryDimension) -> String {
    if dimension == .delta {
        if value < 1000*1000*1000 {
            return "\(toStringInt64(value, dimension)) nsec in between"
        }
        return "\(toStringInt64(value/(1000*1000*1000), dimension)) sec in between"
    }

    let seconds: TimeInterval = Double(value) / Double(1000*1000*1000)
    let date = Date(timeIntervalSince1970: seconds)
    let dateString = dateFormatter.string(from: date)
    return dateString
/*
    A work in progress.

    // Unfortunately, the "yy/mm/dd, hh:mm:ss" is too long for short fields and the second part gets truncated
    // even though the time is more important than the date. So flip the two parts.
    guard var index = dateString.index(of: ",") else {
        return dateString // return unchanged if ", " was not found in the string
    }
    let prefix = dateString.prefix(upTo: index)
    index += 2
    let suffix = dateString.suffix(from: index)
    return suffix + " " + prefix
*/
}
// toStringDate is a public version used by the json formatting code.
func toStringDate(_ value: Int64) -> String {
    return toStringDate(value, .current)
}

private func toStringDuration(_ nsec: Int64, _ dimension: HistoryDimension) -> String {
    let tail = (dimension == .delta) ? " diff from previous": ""
    if nsec < 1000*1000*1000 {
        return "\(toStringInt64(nsec, dimension)) nsec \(tail)"
    }
    var sec = nsec / (1000*1000*1000)
    if sec < 60 {
        return "\(toStringInt64(sec, dimension)) sec\(tail)"
    }
    let d = sec / (24 * 60 * 60)
    sec %= 24 * 60 * 60
    let h = sec / (60 * 60)
    sec %= 60 * 60
    let m = sec / 60
    sec %= 60
    let s = sec
    let dStr = (d == 0) ? "" : "\(d)d "
    let hStr = (h == 0) ? "" : "\(h)h "
    let mStr = (m == 0) ? "" : "\(m)m "
    let sStr = (s == 0) ? "" : "\(s)s "
    return dStr + hStr + mStr + sStr
}

// toStringDuration is a public version used by the json formatting code.
func toStringDuration(_ value: Int64) -> String {
    return toStringDuration(value, .current) // don't want the "diff from previous" appended so use .current
}

private func toStringDouble(_ value: Double, _ dimension: HistoryDimension) -> String {
    // Expect the doubles to be small in which case no characters after decimal are necessary.
    if value < 0.001 {
        // "%e" is supposed to use 'e' but ends up as 'E'. Oh well.
        return String(format: "%.0e", locale: Locale.current, value)
    }
    return String(format: "%e", locale: Locale.current, value)
}

// toStringDouble is a public version used by the json formatting code.
func toStringDouble(_ value: Double) -> String {
    return toStringDouble(value, .current)
}

typealias MallocType = Int

struct MallocFree: CustomStringConvertible {
    var mallocs: MallocType
    var frees: MallocType

    var description: String {
        let m = toStringInt(mallocs, .current)
        let f = toStringInt(frees, .current)
        let d = toStringInt(mallocs-frees, .current)
        return "\(m)-\(f)=\(d)"
    }
}

extension MallocFree: Equatable {
    static func == (lhs: MallocFree, rhs: MallocFree) -> Bool {
        return lhs.mallocs == rhs.mallocs && lhs.frees == rhs.frees
    }
}
extension MallocFree: Comparable {
    static func < (lhs: MallocFree, rhs: MallocFree) -> Bool {
        return lhs.mallocs < rhs.mallocs || (lhs.mallocs == rhs.mallocs && lhs.frees < rhs.frees)
    }
}
extension MallocFree: Diffable {
    static var Zero: MallocFree { return MallocFree(mallocs: 0, frees: 0) }
    static func - (lhs: MallocFree, rhs: MallocFree) -> MallocFree {
        return MallocFree(mallocs: lhs.mallocs - rhs.mallocs,
                          frees: lhs.frees - rhs.frees)
    }
}

private func toStringMallocFree(_ value: MallocFree, _ dimension: HistoryDimension) -> String {
    let a = toStringInt(value.mallocs, dimension)
    let b = toStringInt(value.frees, dimension)
    let c = toStringInt(value.mallocs - value.frees, dimension)
    return "\(a) - \(b) = \(c)"
}

struct BySize {
    var size: UInt32 = 0
    var mallocsFrees: MallocFree
}

struct BySizeDiff {
    // For now, nothing extra to report with the Diff structure.
    var bysize: BySize
}

class BySizeHistory {
    var size: UInt32
    var mallocsFrees: History<MallocFree>

    init(_ stats: HistoryStats, _ bysize: BySize) {
        size = bysize.size
        mallocsFrees = History<MallocFree>(stats, bysize.mallocsFrees,
                                           name: "Size \(size): Mallocs - Frees",
                                           toString: toStringMallocFree)
    }
    func add(_ stats: HistoryStats, _ bysize: BySize) {
        assert(size == bysize.size)
        mallocsFrees.add(stats, bysize.mallocsFrees)
    }

    func printLastDelta() -> [Pair] {
        var r: [Pair] = []
        r += mallocsFrees.printLastDelta("size[\(size)]")
        return r
    }
    func reportIfLastDelta(_ bysizediffs: inout [BySizeDiff]) {
        let (mallocfree, found, _) = mallocsFrees.reportIfLastDelta()
        if found {
            bysizediffs.append(BySizeDiff(bysize: BySize(size: size, mallocsFrees: mallocfree)))
        }
    }
}

struct GCPause {
    var ns: Int64
    var end: Int64 // TBD could be a time type
}

extension GCPause: Equatable {
    static func == (lhs: GCPause, rhs: GCPause) -> Bool {
        return lhs.ns == rhs.ns && lhs.end == rhs.end
    }
}
extension GCPause: Comparable {
    static func < (lhs: GCPause, rhs: GCPause) -> Bool {
        return lhs.end < rhs.end || (lhs.end == rhs.end && lhs.ns < rhs.ns)
    }
}
extension GCPause: Diffable {
    static var Zero: GCPause { return GCPause(ns: 0, end: 0) }
    static func - (lhs: GCPause, rhs: GCPause) -> GCPause { // TBD diff may not make sense for this
        return GCPause(ns: lhs.ns - rhs.ns, end: lhs.end - rhs.end)
    }
}
private func toStringGCPause(_ value: GCPause, _ dimension: HistoryDimension) -> String {
    return "\(toStringDate(value.end, dimension)): \(toStringInt64(value.ns, dimension))ns"
}

struct MemStats {
    var alloc: Int64 = 0
    var totalAlloc: Int64 = 0
    var sys: Int64 = 0
    var lookups: Int64 = 0
    var mallocs: Int64 = 0
    var frees: Int64 = 0
    var heapAlloc: Int64 = 0
    var heapSys: Int64 = 0
    var heapIdle: Int64 = 0
    var heapInuse: Int64 = 0
    var heapReleased: Int64 = 0
    var heapObjects: Int64 = 0
    var stackInuse: Int64 = 0
    var stackSys: Int64 = 0
    var mSpanInuse: Int64 = 0
    var mSpanSys: Int64 = 0
    var mCacheInuse: Int64 = 0
    var mCacheSys: Int64 = 0
    var buckHashSys: Int64 = 0
    var gCSys: Int64 = 0
    var otherSys: Int64 = 0
    var nextGC: Int64 = 0
    var lastGC: Int64 = 0
    var pauseTotalNs: Int64 = 0
    var pauseNs: [Int64] = []
    var pauseEnd: [Int64] = []
    var numGC: Int64 = 0
    var numForcedGC: Int64 = 0
    var gCCPUFraction: Double = 0
    var enableGC: Bool = false
    var debugGC: Bool = false
    var bySize: [BySize] = []
}

class MemStatsHistory {
    var alloc: History<Int64>
    var totalAlloc: History<Int64>
    var sys: History<Int64>
    var lookups: History<Int64>
    var mallocs: History<Int64>
    var frees: History<Int64>
    var heapAlloc: History<Int64>
    var heapSys: History<Int64>
    var heapIdle: History<Int64>
    var heapInuse: History<Int64>
    var heapReleased: History<Int64>
    var heapObjects: History<Int64>
    var stackInuse: History<Int64>
    var stackSys: History<Int64>
    var mSpanInuse: History<Int64>
    var mSpanSys: History<Int64>
    var mCacheInuse: History<Int64>
    var mCacheSys: History<Int64>
    var buckHashSys: History<Int64>
    var gCSys: History<Int64>
    var otherSys: History<Int64>
    var nextGC: History<Int64>
    var lastGC: History<Int64>
    var pauseTotalNs: History<Int64>
    var nextIndex: Int // Index into pauseNs and pauseEnd arrays
    var pauseNs: History<Int64>
    var pauseEnd: History<Int64>
    var pause: History<GCPause>  //experiment, combine pauseNs and pauseEnd
    var numGC: History<Int64>
    var numForcedGC: History<Int64>
    var gCCPUFraction: History<Double>
    var enableGC: Bool
    var debugGC: Bool
    var bySize: [BySizeHistory]

    init(_ stats: HistoryStats, _ memstats: MemStats) {
        alloc = History<Int64>(stats, memstats.alloc, name: "Alloc", toString: toStringInt64)
        totalAlloc = History<Int64>(stats, memstats.totalAlloc, name: "TotalAlloc", toString: toStringInt64)
        sys = History<Int64>(stats, memstats.sys, name: "Sys", toString: toStringInt64)
        lookups = History<Int64>(stats, memstats.lookups, name: "Lookups", toString: toStringInt64)
        mallocs = History<Int64>(stats, memstats.mallocs, name: "Mallocs", toString: toStringInt64)
        frees = History<Int64>(stats, memstats.frees, name: "Frees", toString: toStringInt64)
        heapAlloc = History<Int64>(stats, memstats.heapAlloc, name: "HeapAlloc", toString: toStringInt64)
        heapSys = History<Int64>(stats, memstats.heapSys, name: "HeapSys", toString: toStringInt64)
        heapIdle = History<Int64>(stats, memstats.heapIdle, name: "HeapIdle", toString: toStringInt64)
        heapInuse = History<Int64>(stats, memstats.heapInuse, name: "HeapInuse", toString: toStringInt64)
        heapReleased = History<Int64>(stats, memstats.heapReleased, name: "HeapReleased", toString: toStringInt64)
        heapObjects = History<Int64>(stats, memstats.heapObjects, name: "HeapObjects", toString: toStringInt64)
        stackInuse = History<Int64>(stats, memstats.stackInuse, name: "StackInuse", toString: toStringInt64)
        stackSys = History<Int64>(stats, memstats.stackSys, name: "StackSys", toString: toStringInt64)
        mSpanInuse = History<Int64>(stats, memstats.mSpanInuse, name: "MSpanInuse", toString: toStringInt64)
        mSpanSys = History<Int64>(stats, memstats.mSpanSys, name: "MSpanSys", toString: toStringInt64)
        mCacheInuse = History<Int64>(stats, memstats.mCacheInuse, name: "MCacheInuse", toString: toStringInt64)
        mCacheSys = History<Int64>(stats, memstats.mCacheSys, name: "MCacheSys", toString: toStringInt64)
        buckHashSys = History<Int64>(stats, memstats.buckHashSys, name: "BuckHashSys", toString: toStringInt64)
        gCSys = History<Int64>(stats, memstats.gCSys, name: "GCSys", toString: toStringInt64)
        otherSys = History<Int64>(stats, memstats.otherSys, name: "OtherSys", toString: toStringInt64)
        nextGC = History<Int64>(stats, memstats.nextGC, name: "NextGC", toString: toStringInt64)
        lastGC = History<Int64>(stats, memstats.lastGC, name: "LastGC", toString: toStringDate)
        pauseTotalNs = History<Int64>(stats, memstats.pauseTotalNs, name: "PauseTotalNs", toString: toStringInt64)
        numGC = History<Int64>(stats, memstats.numGC, name: "NumGC", toString: toStringInt64)
        numForcedGC = History<Int64>(stats, memstats.numForcedGC, name: "NumForcedGC", toString: toStringInt64)
        gCCPUFraction = History<Double>(stats, memstats.gCCPUFraction, name: "GCCPUFraction", toString: toStringDouble)
        enableGC = memstats.enableGC
        debugGC = memstats.debugGC
        bySize = []
        for bysize in memstats.bySize {
            bySize.append(BySizeHistory(stats, bysize))
        }

        // Handling of array of pause values

        // Use sortedRanges on the pauseEnd array and get one slice or two.
        // Then iterate through the indexes of the pauseEnd slices,
        //      taking the first as the index into pauseNs and pauseEnd
        //      and creating a struct GCPause{ns, end}, and then add history for each of
        //      the next slice indexes. To build up the history of GC pauses, that goes back
        //      even past the first poll of this app for the endpoint.
        //      Then whenever a new GC is encountered in the add step below,
        //          increment the index place holder (a new private field), and pull out
        //          the new values needed for the next GCPause.

        // Sort the pauseEnd array into one or two slices.
        var firstpause: GCPause = GCPause.Zero
        let ranges = sortedRanges(memstats.pauseEnd)
        //print("\(ranges.count) sorted ranges in the pauseEnd list, \(rangesDebugString(ranges))")

        // Pull first GCPause out of the slices.
        for range in ranges where range.count > 0 {
            let i = range.startIndex
            // print("first pause index", i)
            firstpause = GCPause(ns: memstats.pauseNs[i], end: memstats.pauseEnd[i])
            break // Just look at first one. Rest handld below.
        }

        // firstpause could still be zero, if there had been no GC by the time polling started.
        pauseNs = History<Int64>(stats, firstpause.ns, name: "PauseNs", toString: toStringDuration)
        pauseEnd = History<Int64>(stats, firstpause.end, name: "PauseEnd", toString: toStringDate)
        pause = History<GCPause>(stats, firstpause, name: "Pause", toString: toStringGCPause)

        // Iterate through the remaining GCPauses, amending history.
        nextIndex = 0
        var skip = true // Skip first because it was pulled out already.
        for range in ranges {
            for i in range.startIndex..<range.endIndex {
                nextIndex = i+1 // Track so we know where to look during the next poll result.
                if skip {
                    skip = false
                    continue
                }
                pauseNs.add(stats, memstats.pauseNs[i])
                pauseEnd.add(stats, memstats.pauseEnd[i])
                pause.add(stats, GCPause(ns: memstats.pauseNs[i], end: memstats.pauseEnd[i]))
            }
        }
        // print("next pause index left at", nextIndex)
    }
    func add(_ stats: HistoryStats, _ memstats: MemStats) {
        alloc.add(stats, memstats.alloc)
        totalAlloc.add(stats, memstats.totalAlloc)
        sys.add(stats, memstats.sys)
        lookups.add(stats, memstats.lookups)
        mallocs.add(stats, memstats.mallocs)
        frees.add(stats, memstats.frees)
        heapAlloc.add(stats, memstats.heapAlloc)
        heapSys.add(stats, memstats.heapSys)
        heapIdle.add(stats, memstats.heapIdle)
        heapInuse.add(stats, memstats.heapInuse)
        heapReleased.add(stats, memstats.heapReleased)
        heapObjects.add(stats, memstats.heapObjects)
        stackInuse.add(stats, memstats.stackInuse)
        stackSys.add(stats, memstats.stackSys)
        mSpanInuse.add(stats, memstats.mSpanInuse)
        mSpanSys.add(stats, memstats.mSpanSys)
        mCacheInuse.add(stats, memstats.mCacheInuse)
        mCacheSys.add(stats, memstats.mCacheSys)
        buckHashSys.add(stats, memstats.buckHashSys)
        gCSys.add(stats, memstats.gCSys)
        otherSys.add(stats, memstats.otherSys)
        nextGC.add(stats, memstats.nextGC)
        lastGC.add(stats, memstats.lastGC)
        pauseTotalNs.add(stats, memstats.pauseTotalNs)
    //var pauseNs: [Int64] = []
    //var pauseEnd: [Int64] = []
        numGC.add(stats, memstats.numGC)
        numForcedGC.add(stats, memstats.numForcedGC)
        gCCPUFraction.add(stats, memstats.gCCPUFraction)
        enableGC = memstats.enableGC
        debugGC = memstats.debugGC
        for i in 0..<memstats.bySize.count {
            if bySize[i].size == memstats.bySize[i].size {
                bySize[i].add(stats, memstats.bySize[i])
            } else {
                print("TBD, new BySize size entries found")
            }
        }

        // See if any GCPause need to be picked up
        while true {
            if nextIndex >= memstats.pauseEnd.count {
                nextIndex = 0
            }
            if memstats.pauseEnd[nextIndex] <= pause.top().end { // could also use pauseEnd
                break
            }
            pauseNs.add(stats, memstats.pauseNs[nextIndex])
            pauseEnd.add(stats, memstats.pauseEnd[nextIndex])
            pause.add(stats, GCPause(ns: memstats.pauseNs[nextIndex], end: memstats.pauseEnd[nextIndex]))
            nextIndex += 1
            // print("next pause index incremented to", nextIndex)
        }
    }
    func printLastDelta(_ name: String) -> ([Pair], [BySizeDiff]) {
        var r: [Pair] = []
        r += alloc.printLastDelta("alloc")
        r += sys.printLastDelta("sys")
        r += lookups.printLastDelta("lookups")
        r += mallocs.printLastDelta("mallocs")
        r += frees.printLastDelta("frees")
        r += heapAlloc.printLastDelta("heapAlloc")
        r += heapSys.printLastDelta("heapSys")
        r += heapIdle.printLastDelta("heapIdle")
        r += heapInuse.printLastDelta("heapInuse")
        r += heapReleased.printLastDelta("heapReleased")
        r += heapObjects.printLastDelta("heapObjects")
        r += stackInuse.printLastDelta("stackInuse")
        r += stackSys.printLastDelta("stackSys")
        r += mSpanInuse.printLastDelta("mSpanInuse")
        r += mSpanSys.printLastDelta("mSpanSys")
        r += mCacheInuse.printLastDelta("mCacheInuse")
        r += mCacheSys.printLastDelta("mCacheSys")
        r += buckHashSys.printLastDelta("buckHashSys")
        r += gCSys.printLastDelta("gCSys")
        r += otherSys.printLastDelta("otherSys")
        r += nextGC.printLastDelta("nextGC")
        r += lastGC.printLastDelta("lastGC")
        r += pauseTotalNs.printLastDelta("pauseTotalNs")
        r += pauseNs.printLastDelta("pauseNs")
        r += pauseEnd.printLastDelta("pauseEnd")
        r += pause.printLastDelta("pause")
        r += numGC.printLastDelta("numGC")
        r += numForcedGC.printLastDelta("numForcedGC")
        r += gCCPUFraction.printLastDelta("gCCPUFraction")
        //enableGC = memstats.enableGC
        //debugGC = memstats.debugGC
        var bysizediffs: [BySizeDiff] = []
        bysizediffs.reserveCapacity(bySize.count)
        for i in 0..<bySize.count {
            bySize[i].reportIfLastDelta(&bysizediffs)
        }
        return (r, bysizediffs)
    }
}

struct Vars {
    let jsonDict: [String: Any?]
    let cmdline: [String]
    let memstats: MemStats
    // These two are hacks for now. Figure out how to handle extra fields later.
    let storecacheGoodput: Double
    let storecacheOutput: Double
}

struct Pair {
    let name: String
    let value: String
    init(_ n: String, _ v: Any?) {
        name = n
        var s = "nil"
        if let vv = v {
            s = String(describing: vv)
        }
        value = s
    }
}

class VarsHistory {
    var lastJsonDict: [String: Any?] // replaced each poll
    var stats: HistoryStats
    var cmdline: [String]
    var cmdlineChanges: Int = 0
    var memstats: MemStatsHistory
    var storecacheGoodput: History<Double>
    var storecacheOutput: History<Double>

    init(_ vars: Vars) {
        lastJsonDict = vars.jsonDict
        stats = HistoryStats()
        cmdline = vars.cmdline
        memstats = MemStatsHistory(stats, vars.memstats)
        storecacheGoodput = History<Double>(stats, vars.storecacheGoodput, name: "StorecacheGoodput", toString: toStringDouble)
        storecacheOutput = History<Double>(stats, vars.storecacheOutput, name: "StorecacheOutput", toString: toStringDouble)
    }
    func add(_ vars: Vars) {
        lastJsonDict = vars.jsonDict
        if cmdline != vars.cmdline {
            cmdline = vars.cmdline
            cmdlineChanges += 1
        }
        memstats.add(stats, vars.memstats)
        storecacheGoodput.add(stats, vars.storecacheGoodput)
        storecacheOutput.add(stats, vars.storecacheOutput)
    }
    func printLastDelta() -> ([Pair], [BySizeDiff]) {
        var r: [Pair] = []
        r.append(Pair("cmdline", cmdline))
        r += storecacheGoodput.printLastDelta("storecacheGoodput")
        r += storecacheOutput.printLastDelta("storecacheOutput")
        let (pairs, bysizediffs) = memstats.printLastDelta("memstats")
        r += pairs
        return (r, bysizediffs)
    }
}

enum ExpVarError: Error {
    case badType(key: String, expectedType: String)
    case notDictionary(type: String)
    case dictionaryEntryNilOrMissing(key: String)
    case notDoubleConvertible(string: String)
}

func jsonDictValToStringArray(_ dict: [String: Any?], key: String) throws -> [String] {
    let any = try lookupDict(dict, key: key)
    guard let str = any as? [String] else {
        throw ExpVarError.badType(key: key, expectedType: "[String]")
    }
    return str
}

func jsonDictValToString(_ dict: [String: Any?], key: String) throws -> String {
    let any = try lookupDict(dict, key: key)
    guard let str = any as? String else {
        throw ExpVarError.badType(key: key, expectedType: "String")
    }
    return str
}

func lookupDict(_ dict: [String: Any?], key: String) throws -> Any {
    guard let value = dict[key] else {
        throw ExpVarError.dictionaryEntryNilOrMissing(key: key)
    }
    return value!
}
func jsonToMemStats(_ json: Any?) throws -> MemStats {
    guard let dict = json as? [String: Any?] else {
        throw ExpVarError.notDictionary(type: "MemStats")
    }
    return MemStats(
        alloc: try jsonDictValToInt64(dict, key: "Alloc"),
        totalAlloc: try jsonDictValToInt64(dict, key: "TotalAlloc"),
        sys: try jsonDictValToInt64(dict, key: "Sys"),
        lookups: try jsonDictValToInt64(dict, key: "Lookups"),
        mallocs: try jsonDictValToInt64(dict, key: "Mallocs"),
        frees: try jsonDictValToInt64(dict, key: "Frees"),
        heapAlloc: try jsonDictValToInt64(dict, key: "HeapAlloc"),
        heapSys: try jsonDictValToInt64(dict, key: "HeapSys"),
        heapIdle: try jsonDictValToInt64(dict, key: "HeapIdle"),
        heapInuse: try jsonDictValToInt64(dict, key: "HeapInuse"),
        heapReleased: try jsonDictValToInt64(dict, key: "HeapReleased"),
        heapObjects: try jsonDictValToInt64(dict, key: "HeapObjects"),
        stackInuse: try jsonDictValToInt64(dict, key: "StackInuse"),
        stackSys: try jsonDictValToInt64(dict, key: "StackSys"),
        mSpanInuse: try jsonDictValToInt64(dict, key: "MSpanInuse"),
        mSpanSys: try jsonDictValToInt64(dict, key: "MSpanSys"),
        mCacheInuse: try jsonDictValToInt64(dict, key: "MCacheInuse"),
        mCacheSys: try jsonDictValToInt64(dict, key: "MCacheSys"),
        buckHashSys: try jsonDictValToInt64(dict, key: "BuckHashSys"),
        gCSys: try jsonDictValToInt64(dict, key: "GCSys"),
        otherSys: try jsonDictValToInt64(dict, key: "OtherSys"),
        nextGC: try jsonDictValToInt64(dict, key: "NextGC"),
        lastGC: try jsonDictValToInt64(dict, key: "LastGC"),
        pauseTotalNs: try jsonDictValToInt64(dict, key: "PauseTotalNs"),

        pauseNs: try jsonDictValToInt64Array(dict, key: "PauseNs"),
        pauseEnd: try jsonDictValToInt64Array(dict, key: "PauseEnd"),

        numGC: try jsonDictValToInt64(dict, key: "NumGC"),
        numForcedGC: try jsonDictValToInt64(dict, key: "NumForcedGC"),

        gCCPUFraction: try jsonDictValToDouble(dict, key: "GCCPUFraction"),
        enableGC: try jsonDictValToBool(dict, key: "EnableGC"),
        debugGC: try jsonDictValToBool(dict, key: "DebugGC"),
        bySize: try jsonDictValToBySizeArray(dict, key: "BySize")
        )
}

func jsonDictValToInt64(_ dict: [String: Any?], key: String) throws -> Int64 {
    let any = try lookupDict(dict, key: key)
    guard let u = any as? Int64 else {
        // Bug in swift SR-6302?  Try to extract manually.
        if let nsnumber = any as? NSNumber {
            return nsnumber.int64Value
        }
        throw ExpVarError.badType(key: key, expectedType: "Int64")
    }
    return u
}

func jsonDictValToUInt64(_ dict: [String: Any?], key: String) throws -> UInt64 {
    let any = try lookupDict(dict, key: key)
    guard let u = any as? UInt64 else {
        // Bug in swift SR-6302?  Try to extract manually.
        if let nsnumber = any as? NSNumber {
            return nsnumber.uint64Value
        }
        throw ExpVarError.badType(key: key, expectedType: "UInt64")
    }
    return u
}

func jsonDictValToDouble(_ dict: [String: Any?], key: String) throws -> Double {
    let any = try lookupDict(dict, key: key)
    guard let d = any as? Double else {
        throw ExpVarError.badType(key: key, expectedType: "Double")
    }
    return d
}

func jsonDictValToBool(_ dict: [String: Any?], key: String) throws -> Bool {
    let any = try lookupDict(dict, key: key)
    guard let b = any as? Bool else {
        throw ExpVarError.badType(key: key, expectedType: "Bool")
    }
    return b
}

func jsonDictValToInt32(_ dict: [String: Any?], key: String) throws -> Int32 {
    let any = try lookupDict(dict, key: key)
    guard let i = any as? Int32 else {
        throw ExpVarError.badType(key: key, expectedType: "Int32")
    }
    return i
}

func jsonDictValToUInt32(_ dict: [String: Any?], key: String) throws -> UInt32 {
    let any = try lookupDict(dict, key: key)
    guard let i = any as? UInt32 else {
        throw ExpVarError.badType(key: key, expectedType: "UInt32")
    }
    return i
}

func jsonDictValToMallocType(_ dict: [String: Any?], key: String) throws -> MallocType {
    let any = try lookupDict(dict, key: key)
    guard let i = any as? MallocType else {
        throw ExpVarError.badType(key: key, expectedType: String(describing: MallocType.self))
    }
    return i
}

// This didn't seem to work. Keep around and try later again.
func jsonDictVal<T>(_ dict: [String: Any?], key: String) throws -> T {
    let any = try lookupDict(dict, key: key)
    guard let i = any as? T else {
        throw ExpVarError.badType(key: key, expectedType: String(describing: T.self))
    }
    return i
}

func jsonDictValToInt64Array(_ dict: [String: Any?], key: String) throws -> [Int64] {
    /*
    // This should work but doesn't. Some kind of swift forct cast or NSNumber problem with the large Int64 values.
    // Making the array unwind explicit gets around the problem.
    // So 10 lines instead of 5.

    let any = try lookupDict(dict, key: key)
    guard let str = any as? [Int64] else {
        throw ExpVarError.badType(key: key, expectedType: "[Int64]")
    }
    return str
    */
    let any = try lookupDict(dict, key: key)
    guard let numbers = any as? [NSNumber] else {
        throw ExpVarError.badType(key: key, expectedType: "[Int64], wasn't even an array of NSNumber")
    }
    var result: [Int64] = []
    result.reserveCapacity(numbers.count)
    for n in numbers {
        // Include zeros.
        result.append(n.int64Value)
        //let value = n.int64Value
        //if value != 0 {
        //    result.append(value)
        //}
    }
    return result
}

func jsonDictValToUInt64Array(_ dict: [String: Any?], key: String) throws -> [UInt64] {
    /*
    // This should work but doesn't. Some kind of swift forct cast or NSNumber problem with the large UInt64 values.
    // Making the array unwind explicit gets around the problem.
    // So 10 lines instead of 5.

    let any = try lookupDict(dict, key: key)
    guard let str = any as? [UInt64] else {
        throw ExpVarError.badType(key: key, expectedType: "[UInt64]")
    }
    return str
    */
    let any = try lookupDict(dict, key: key)
    guard let numbers = any as? [NSNumber] else {
        throw ExpVarError.badType(key: key, expectedType: "[UInt64], wasn't even an array of NSNumber")
    }
    var result: [UInt64] = []
    result.reserveCapacity(numbers.count)
    for n in numbers {
        // Include zeros.
        result.append(n.uint64Value)
        //let value = n.uint64Value
        //if value != 0 {
        //    result.append(value)
        //}
    }
    return result
}

func jsonDictValToBySizeArray(_ dict: [String: Any?], key: String) throws -> [BySize] {
    let any = try lookupDict(dict, key: key)
    guard let dictionaries = any as? [[String: Any?]] else {
        throw ExpVarError.badType(key: key, expectedType: "[BySize], wasn't even an array of dictionaries")
    }
    var result: [BySize] = []
    result.reserveCapacity(dictionaries.count)
    for d in dictionaries {
        result.append(try jsonToBySize(d))
    }
    return result
}
func jsonToBySize(_ dict: [String: Any?]) throws -> BySize {
    return BySize(
        size: try jsonDictValToUInt32(dict, key: "Size"),
        mallocsFrees: MallocFree(
            mallocs: try jsonDictValToMallocType(dict, key: "Mallocs"),
            frees: try jsonDictValToMallocType(dict, key: "Frees")
        )
    )
}

// doubleRemoveOps takes a string ending in " ops/s", trims it, and converts to Double.
func doubleRemoveOps(_ value: String) throws -> Double {
    var value = value
    let suffix = " ops/s"
    if value.hasSuffix(suffix) {
        value.removeLast(suffix.count)
    }
    guard let double = Double(value) else {
        throw ExpVarError.notDoubleConvertible(string: value)
    }
    return double
}

func jsonToExpVar(_ dict: [String: Any?]) throws -> Vars {
    var storecacheGoodput: Double = 0
    do {
        storecacheGoodput = try doubleRemoveOps(try jsonDictValToString(dict, key: "storecache-goodput"))
    }
    var storecacheOutput: Double = 0
    do {
        storecacheOutput  = try doubleRemoveOps(try jsonDictValToString(dict, key: "storecache-output"))
    }

    return Vars(
        jsonDict: dict,
        cmdline: try jsonDictValToStringArray(dict, key: "cmdline"),
        memstats: try jsonToMemStats(try lookupDict(dict, key: "memstats")),
        storecacheGoodput: storecacheGoodput,
        storecacheOutput: storecacheOutput
        )
}
private func rangesDebugString(_ ranges: [ArraySlice<Int64>]) -> String {
    var r = ""
    var sep = ""
    for range in ranges {
        r += "\(sep)\(range.startIndex)..<\(range.endIndex)"
        sep = ", "
    }
    return r
}
