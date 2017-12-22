// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

struct EndpointStatus {
    enum HealthScore: Int {
        // The order of raw values is important because the largest is used as the overall health value
        // by the status bar item.
        case none = 0
        case normal = 1
        case warning = 2
        case failed = 3
    }
    let continuing: Bool
    let error: Error?
    let stderr: String?

    func healthScore() -> HealthScore {
        if !self.continuing {
            return .failed
        }
        if self.error != nil {
            return .warning
        }
        return .normal
    }

    func health() -> (String, NSImage?) {
        switch self.healthScore() {
        case .none:
            return ("none", imageNone())
        case .normal:
            return ("polling", imageOk())
        case .warning:
            return ("warning", imageWarning())
        case .failed:
            return ("polling aborted", imageStopped())
        }
    }

    func keyValues() -> [(String, String)] {
        var r: [(String, String)] = []
        r.append(("Status:", (self.continuing ? "polling" : "polling aborted")))
        if let stderr = stderr {
            r.append(("stderr", stderr))
        }
        if let error = error {
            if let backendError = error as? BackendError {
                r += backendError.keyValues()
            } else {
                r.append(("Error", String(describing: error)))
            }
        }
        return r
    }
}

protocol Registrar: class {
    func syncRegisterEndpoint(description: String) -> ID
    func syncStartAnotherPollRound() -> Bool
    func asyncSetPollingFinished()
}

class DataGetter: CustomStringConvertible {
    var description: String
    var data: Data?
    var stderr: String?
    var error: Error?

    init(description: String) {
        self.description = description
    }

    func getData() -> Bool {
        fatalError("Must Override")
    }
}

class IPCDataGetter: DataGetter {
    private let filename: String

    init(path: String) {
        self.filename = path
        super.init(description: "IPC(\(path))")
    }

    override func getData() -> Bool {
        self.data = nil
        self.stderr = nil
        self.error = nil
        do {
            let (dataT, stderrT) = try runCurlIPC(filename: filename)
            self.data = dataT
            self.stderr = stderrT
            return true
        } catch {
            self.error = error
            return false
        }
    }
}

class TCPDataGetter: DataGetter {
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init(description: "TCP(\(url))")
    }

    override func getData() -> Bool {
        self.data = nil
        self.error = nil
        do {
            self.data = try getHTTP(url: self.url)
            return true
        } catch {
            self.error = error
            return false
        }
    }
}

// Endpoint provides two functions:
// getting data for an outside agent, like a slow poller,
// and starting its own polling, when the outside agent has
// found the endpoint is capable of returning data.
class Endpoint {
    private let dataGetter: DataGetter
    private var timer: Timer?
    private let configJsonBackground: ConfigJsonBackground

    init(_ dataGetter: DataGetter) {
        self.dataGetter = dataGetter

        self.configJsonBackground = mainSyncReadConfig()
    }

    var description: String {
        return dataGetter.description
    }
    private var data: Data? {
        return dataGetter.data
    }
    private var stderr: String? {
        return dataGetter.stderr
    }
    private var error: Error? {
        return dataGetter.error
    }

    func getData() -> Bool {
        return self.dataGetter.getData()
    }

    // startOwnPoller creates a timer with a closure for self and an ID
    // variable so data can be polled, where the first time, an ID is taken
    // from the delegate and the data has already been received.
    // The timer will refire every repeating seconds until the endpoint 
    // is closed at which time the resubmit callback is used to presumably
    // get this endpoint back onto the slow poller.
    func startOwnPoller(repeating: Double,
                        registrar: Registrar,
                        resubmit: @escaping Timer.Job) {
        var id: ID?

        guard self.timer == nil else {
            // This routine isn't to be called when it is already polling.
            fatalError("Duplicate request")
        }

        self.timer = Timer(queuelabel: self.description, repeating: repeating) {

            // Get an ID the first time, get Data all subsequent times.

            if id == nil {
                // Run once.
                id = registrar.syncRegisterEndpoint(description: self.description)

                guard self.data != nil else {
                    fatalError("Should have had data") // when called the first time.
                }
            } else {

                guard self.getData() else {

                    // First type of error, the process appears to have gone
                    // away. Getting data, which had worked at least once, now
                    // is failing.

                    id?.asyncPolledDataFailure(
                        status: EndpointStatus(
                            continuing: false,      // TBD display "polling stopped"
                            error: self.error,      // TBD display "error: ..."
                            stderr: self.stderr))   // TBD display "stderr: ..."
                    self.cleanup(resubmit: resubmit)
                    return
                }
            }

            guard let data = self.data else {
                fatalError("nil data")
            }

            // Convert the data to a JSON dictionary. And convert that to an expvar Vars data structure.

            do {
                var jsonDict = try jsonDictFromData(data)

                if self.configJsonBackground.insertLastGCPause {
                    // Don't include the index if we're removing the arrays anyway.
                    let includeIndex = self.configJsonBackground.insertLastGCPauseIndex
                    insertLastGCPause(&jsonDict, includeIndex: includeIndex)
                }
                if self.configJsonBackground.reworkBySizeArray {
                    reworkBySizeArray(&jsonDict)
                }

                // TBD This could change to allow non expvar endpoints too.
                // The failure of this second routine doesn't mean the json is bad,
                // just that it doesn't look like the expvar output. Might still be
                // worth displaying in the JSON windows. Could have a separate observers
                // list for json and not lump everything in with parsing the memstats correctly.
                let vars = try jsonToExpVar(jsonDict)
                if id?.asyncPolledDataAvailable(vars: vars) == false {
                    // The connection has gone away so cleanup.
                    self.cleanup(resubmit: resubmit)
                    return
                }
            } catch {
                id?.asyncPolledDataFailure(
                    status: EndpointStatus(
                        continuing: true,
                        error: error,
                        stderr: self.stderr))
                // Don't exit. Allow endpoint poll to keep trying.
            }
        }
    }
    func cleanup(resubmit: Timer.Job) {
        self.timer?.cancel()
        self.timer = nil
        resubmit()
    }
}

// TCPEndpoint makes a connection to a TCP socket using HTTP.
// For now, it opens a connection for each poll.
class TCPEndpoint: Endpoint {
    init(url: URL) {
        super.init(TCPDataGetter(url: url))
    }
}

// IPCEndpoint makes a connection to a unix domain socket using HTTP.
// For now, it runs the curl tool as a child process for each poll.
class IPCEndpoint: Endpoint {
    init(path: String) {
        super.init(IPCDataGetter(path: path))
    }
}

// ConfigJsonBackground made struct so each thread that wants to look at these
// really does get their own copy of the variables.
struct ConfigJsonBackground {
    var insertLastGCPause = false
    var insertLastGCPauseIndex = false
    var reworkBySizeArray = false
}

// mainSyncReadConfig will read the config for the background info needed.
// If the current thread is not main, a blocking calling to the main thread is made,
// to keep all config reads on the main thread.
private func mainSyncReadConfig() -> ConfigJsonBackground {
    var r = ConfigJsonBackground()

    let fn = {
        if let cfgBackground = config.dict.dict("json", "backgroundModify") {

            r.insertLastGCPause      = cfgBackground.findBool("insertLastGCPause")
            r.insertLastGCPauseIndex = cfgBackground.findBool("insertLastGCPauseIndex")
            r.reworkBySizeArray      = cfgBackground.findBool("reworkBySizeArray")
        }
    }
    if Thread.isMainThread {
        fn()
    } else {
        DispatchQueue.main.sync { fn() }
    }

    return r
}

// insertLastGCPause adds a LastGCPauseNs field to memstats.
// It dives into the json "memstats" dictionary
// and uses the LastGC field's value to find the index
// of the matching time in the PauseEnd array, and pulls
// out the matching PauseNs field using that index.
// It may also add the index used to the memstats table.
private func insertLastGCPause(_ jsonDict: inout [String: Any?], includeIndex: Bool) {
    guard var memstats = jsonDict.find("memstats") as? [String: Any?] else {
        return
    }
    guard let lastGC = memstats.find("LastGC") as? NSNumber else {
        return
    }
    guard let pauseEnd = memstats.find("PauseEnd") as? [Any?] else {
        return
    }
    guard let pauseNs = memstats.find("PauseNs") as? [Any?] else {
        return
    }
    var lastPauseNs: Int64 = 0
    var lastPauseIndex: Int64 = -1
    for index in 0..<pauseEnd.count {
        if let number = pauseEnd[index] as? NSNumber,
        number == lastGC {
            if index < pauseNs.count {
                lastPauseNs = pauseNs[index] as? Int64 ?? 0
                lastPauseIndex = Int64(index)
            }
            break
        }
    }
    memstats["LastGCPauseNs"] = lastPauseNs

    if includeIndex {
        memstats["LastGCPauseIndex"] = lastPauseIndex
    }

    // Put the new memstats back into the dictionary from where it came.

    jsonDict["memstats"] = memstats
}

private func reworkBySizeArray(_ jsonDict: inout [String: Any?]) {
    guard var memstats = jsonDict.find("memstats") as? [String: Any?] else {
        return
    }
    guard let bySize = memstats.find("BySize") as? [Any?] else {
        return
    }
    var bySize2: [String: Any?] = [:]
    for entry in bySize {
        if let entry = entry as? [String: Any?] {
            if let size = entry["Size"],
               let mallocs = entry["Mallocs"],
               let frees = entry["Frees"] {
                   if let size = size {
                       bySize2["Size[\(String(describing: size))]"] = ["Mallocs": mallocs, "Frees": frees]
               }
            }
        }
    }
    memstats["BySize2"] = bySize2

    jsonDict["memstats"] = memstats
}

private func jsonDictFromData(_ data: Data) throws -> [String: Any?] {
    let json = try jsonObject(data: data)

    guard let jsonDictionary = json as? [String: Any?] else {
        throw BackendError.jsonNotDictionary(json: json)
    }

    return jsonDictionary
}
