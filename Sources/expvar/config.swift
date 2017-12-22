// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Parse an optional JSON config file.
//
// The top level item from the JSON extracted from the config file
// is required to be a dictionary.

import AppKit

// Config contains fields that can be extracted from the JSON config file.
// Methods: 
//      loadJSON(absoluteFile:String) // Multiple can be called.
//      dump()
//      dump()
//      find(_: String...) -> Any?
//      findBool(_: String...) -> Bool

extension Dictionary where Key == String, Value == Any? {
    func find(_ args: String...) -> Any? {
        return self.find(args)
    }
    func findBool(_ args: String...) -> Bool {
        return self.findBool(args)
    }
    func findBool(_ args: [String]) -> Bool {
        return self.find(args) as? Bool ?? false
    }
    func find(_ args: [String]) -> Any? {
        var value = self as Any?
        for arg in args {
            guard let dictionary = value as? [String: Any?],
                  let v = dictionary[arg] else {
                return nil
            }
            value = v
        }
        return value
    }
    func dict(_ args: String...) -> [String: Any?]? {
        return self.find(args) as? [String: Any?]
    }
    func dict(_ args: [String]) -> [String: Any?]? {
        return self.find(args) as? [String: Any?]
    }
}

class Config {
    var debug = false

    var dict: [String: Any?] = [:]

    private func postLoad() {
        if let debug = self.find("debug") as? Bool {
            self.debug = debug
        }
    }

    // find uses the arg strings to traverse the config dictionary tree
    // and returns what it finds.
    func find(_ args: String...) -> Any? {
        return self.dict.find(args)
    }

    func findBool(_ args: String...) -> Bool {
        return self.dict.findBool(args)
    }

    // loadJSON attempts to read a JSON dictionary from file and add the
    // results to the dictionary. The function calls exit(1) if
    // a JSON parsing error is encountered.
    // Returns true if the read and the JSON parsing were successful.
    func loadJSON(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            do {
                let json = try jsonObject(data: data)

                if let dict = json as? [String: Any?] {
                    for (key, value) in dict {
                        self.dict[key] = value
                    }
                    self.postLoad()
                    return true
                }
            } catch {
                // The thought here is, if a config file was found, but does not parse properly,
                // the user will want to take corrective action so make the problem obvious but
                // aborting.
                print("Fatal JSON decode error for file:\(url.absoluteString): \(error.localizedDescription)")
                exit(1)
            }
        } catch {
            // Not finding a file could be very common, so don't abort.
            // This routine might be used for trying several locations.
            // print("Nonfatal config read error for file:\(file): \(error.localizedDescription)")
        }
        return false
    }

    func dump() {
        print(self.dict)
    }

    // Helper functions
    func click(_ windowname: String) -> Bool {
        let path = ["windows", windowname, "click"]

        guard let value = self.dict.find(path) else {
            return false
        }
        if let bool = value as? Bool {
            return bool
        }
        if let string = value as? String {
            switch string {
            case "all": return true
            default:
                print("config warning: unexpected windows:\(windowname):click: value '\(string)'.")
                return false
            }
        }
        return false
    }
    func summaryFrame(top: Bool,
                      screenFrame: NSRect,
                      size: CGSize,
                      offset: CGPoint) -> NSRect {

        let cfg = self.dict.dict("windows", "Summary", "frame")

        return frameI(dictionary: cfg,
                   relativeScreen: true,
                   top: top,
                   screenFrame: screenFrame,
                   parentFrame: NSRect(x: 0, y: 0, width: 0, height: 0),
                   size: size,
                   offset: offset,
                   instanceOffset: CGPoint(x: 0, y: 0),
                   instance: 0)
    }

    let jsonConfigName = "json"
    let userConfigName = "user"
    let memStatsConfigName = "memstats"
    let bySizeConfigName = "bysize"
    func frame(windowName: String,
               frames: Frames,
               relativeScreen relativeScreenDefault: Bool,
               top: Bool,
               size: CGSize,
               offset: CGPoint,
               instanceOffset: CGPoint,
               instance: Int) -> NSRect {
        let (parentFrame, screenFrame) = frames.frames()

        let cfg = self.dict.dict("windows", windowName, "frame")
        let relativeScreen = (cfg?.find("offset", "relativeScreen") as? Bool) ?? relativeScreenDefault

        return frameI(dictionary: cfg,
                      relativeScreen: relativeScreen,
                      top: top,
                      screenFrame: screenFrame,
                      parentFrame: parentFrame,
                      size: size,
                      offset: offset,
                      instanceOffset: instanceOffset,
                      instance: instance)
    }

    private func frameI(dictionary cfg: [String: Any?]?,
                        relativeScreen: Bool,
                        top topDefault: Bool,
                        screenFrame: NSRect,
                        parentFrame: NSRect,
                        size sizeDefault: CGSize,
                        offset offsetDefault: CGPoint,
                        instanceOffset instanceOffsetDefault: CGPoint,
                        instance: Int) -> NSRect {
        let top = (cfg?.find("offset", "top") as? Bool) ?? topDefault

        let size = sizeI(cfg?.dict("size"), sizeDefault)

        var offset = CGPoint(
            x: (cfg?.find("offset", "dx") as? CGFloat) ?? offsetDefault.x,
            y: (cfg?.find("offset", "dy") as? CGFloat) ?? offsetDefault.y)

        var instanceOffset = CGPoint(
            x: (cfg?.find("instanceOffset", "dx") as? CGFloat) ?? instanceOffsetDefault.x,
            y: (cfg?.find("instanceOffset", "dy") as? CGFloat) ?? instanceOffsetDefault.y)

        let source = relativeScreen ? screenFrame : parentFrame
        var target = NSRect(origin: source.origin, size: size)

        // Make dy the difference between windows (0 or positive no overlap)
        // So FlipY == true means bottom of new frame sits on top of old frame
        // else new frame sits under bottom of old frame.
        // so two things ...
        // so sense of dy probaby has to be reversed,
        // and new frame bottom or top has to be matched against the old top or bottom.
        // and a third thing ...
        // from top, positive dy goes down but
        // from bottom, positive dy goes up

        let sourceIsOver = (relativeScreen != top) // poor man's xor

        if sourceIsOver {
            // set the target.minY
            target.origin.y = relativeScreen ? screenFrame.minY : parentFrame.maxY
        } else {
            // source is under
            // set the target.maxY
            let targetMaxY = relativeScreen ? screenFrame.maxY : parentFrame.minY
            target.origin.y = targetMaxY - target.height

            // Flip the dy values because the target should move down further.
            offset.y *= -1
            instanceOffset.y *= -1
        }

        target.origin.x += offset.x + instanceOffset.x*CGFloat(instance)
        target.origin.y += offset.y + instanceOffset.y*CGFloat(instance)

        return target
    }

    func adjust(column: NSTableColumn, forWindow: String) {
        if let dictionary = self.dict.dict("windows", forWindow, "columns") {
            let title = column.title
            let warning = {(_ msg: String) in
                print("config warning: windows/\(forWindow)/columns/\(title) \(msg)")
            }
            guard let found = dictionary.find(title) else {
                warning("missing")
                return
            }
            guard let foundDict = found as? [String: Any?] else {
                warning("not a dictionary")
                return
            }

            for (key, value) in foundDict {
                switch key {
                case "width":
                    guard let width = value as? CGFloat else {
                        warning("\(key) not a number value")
                        return
                    }
                    column.width = width
                case "minWidth":
                    guard let minWidth = value as? CGFloat else {
                        warning("\(key) not a number value")
                        return
                    }
                    column.minWidth = minWidth
                case "maxWidth":
                    guard let maxWidth = value as? CGFloat else {
                        warning("\(key) not a number value")
                        return
                    }
                    column.maxWidth = maxWidth
                // case "resizingMask": // Not implemented.
                case "sizeToFit":
                    guard let sizeToFit = value as? Bool else {
                        warning("\(key) not a boolean value")
                        return
                    }
                    if sizeToFit {
                        column.sizeToFit()
                    }
                default:
                    warning("key \(key) not recognized")
                }
            }
        }
    }

    func popoverSize(forWindow: String, defaultSize: CGSize) -> CGSize {
        return sizeI(self.dict.dict("windows", forWindow, "popover", "size"), defaultSize)
    }

    func popoverIntercellSpacing(forWindow: String) -> CGSize {
        let defaultSize = CGSize(width: 3.0, height: 2.0)
        return sizeI(self.dict.dict("windows", forWindow, "popover", "intercellSpacing"), defaultSize)
    }

    func endpoints() -> (ipcSockets: [String], tcpSockets: [String], logLevel: LogLevel) {
        var logLevel = LogLevel.high
        // Removed from the default config file. It hasn't proven useful.
        if let logLevelString = self.find("endpoints", "log-level") as? String {
            if let parsedLogLevel = LogLevel.from(string: logLevelString) {
                logLevel = parsedLogLevel
            } else {
                print("config warning: endpoints/log-level \(logLevelString) didn't match")
            }
        }
        // Provide default of "$TMPDIR" if there is no config or no ipc-sockets within the config.
        // If the user doesn't want $TMPDIR searched, they can provide an empty array.
        var ipcSockets = self.find("endpoints", "ipc-sockets") as? [String] ?? ["$TMPDIR"]
        envSubstitution(strings: &ipcSockets)
        return (
            ipcSockets,
            self.find("endpoints", "tcp-sockets") as? [String] ?? [],
            logLevel
            )
    }

    var jsonOrderingMap: [String: Int]?
    // TBD create protocol for the name.
    func jsonOrdering() -> [String: Int] {
        if self.jsonOrderingMap == nil {
            self.jsonOrderingMap  = loadJsonOrdering()
        }
        return self.jsonOrderingMap!
    }
    private func loadJsonOrdering() -> [String: Int] {
        var map: [String: Int] = [:]
        guard let orderingCfg = self.dict.find("windows", "json", "ordering") else {
            print("config warning, windows/json/ordering not found")
            return map
        }
        guard let array = orderingCfg as? [String] else {
            print("config warning, windows/json/ordering not an array of strings")
            return map
        }
        for position in 0..<array.count {
            let string = array[position]
            map[string] = position
        }
        return map
    }
}

private func sizeI(_ cfg: [String: Any?]?, _ defaultSize: CGSize) -> CGSize {
    return CGSize(
        width: cfg?["width"] as? CGFloat ?? defaultSize.width,
        height: cfg?["height"] as? CGFloat ?? defaultSize.height)
}

func loadConfig(file: String) {

    func defaultConfigURLs(file: String) -> [URL] {
        var l: [URL] = []
        l.append(URL(fileURLWithPath: file))

        if #available(macOS 10.12, *) {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            l.append(URL(fileURLWithPath: file, relativeTo: homeURL))
            l.append(URL(fileURLWithPath: "upspin/" + file, relativeTo: homeURL))
        }

        return l
    }

    // Try to load a single config from several places.
    for url in defaultConfigURLs(file: file) {
        if config.loadJSON(url: url) {
            break
        }
    }
    //config.dump()
}

var config = Config()
