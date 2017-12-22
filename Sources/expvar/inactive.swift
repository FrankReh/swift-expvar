// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// All the code in this file should be thought of as running on its
// own background thread.
// Accesses to the config data should be done with a synchronous call on the main thread.

// TBD this LogLevel may not prove worthwhile.
private var logLevel: LogLevel = .none
private func log(_ frequency: LogLevel, _ args: [String]) {
    if logLevel.level(frequency) {
        print(args)
    }
}
private func logImportant(_ args: String...) {
    log(.low, args)
}
private func logMedium(_ args: String...) {
    log(.medium, args)
}
private func logUnimportant(_ args: String...) {
    log(.high, args)
}

class InactiveEndpoints {
    private var activePollRate: Double
    private var inactivePollRate: Double
    private var logLevel2: LogLevel

    private var endpoints: [Endpoint] = []
    private var ipcSocketDirectories: [IpcSocketDirectory]
    private var timer: Timer?
    private var strongs: [Any?] = [] // TBD see if necessary.

    init() {
        // Read configuration

        self.inactivePollRate = config.find("endpoints", "pollrates", "search") as? Double ?? 5.0
        self.activePollRate = config.find("endpoints", "pollrates", "active") as? Double ?? 2.5
        let (ipcStrings, tcpStrings, logLevel2) = config.endpoints()

        // IPC

        let (ipcSocketFiles, ipcSocketDirectories) = InactiveEndpoints.ipcSocketGroups(strings: ipcStrings)

        self.logLevel2 = logLevel2

        self.ipcSocketDirectories = ipcSocketDirectories

        self.newIpcSocket(files: ipcSocketFiles)

        // TCP

        for path in tcpStrings {
            guard let url = URL(string: path) else {
                print("URL couldn't be created from \(path):")
                exit(1)
            }
            self.newTcpSocket(url: url)
        }
    }

    func startPolling(registrar: Registrar) {

        self.timer = Timer(queuelabel: "InactiveEndpoints", repeating: self.inactivePollRate) {
            if !registrar.syncStartAnotherPollRound() {
                return
            }

            // Have new socket files added from each directory to sockets list.

            for directory in self.ipcSocketDirectories {
                let newfound = directory.searchForNewSockets()
                if newfound.count > 0 {
                    logImportant("newfound socket files", String(describing: newfound)) // TBD check loglevel
                    self.newIpcSocket(files: newfound)
                }
            }

            // Search through all socket files to see if any can be connected to.

            var removeIndexes: [Int] = []
            for index in 0..<self.endpoints.count {
                let endpoint = self.endpoints[index]

                // TBD some unix domain sockets can cause curl to hang
                // seemingly indefinitely. curl is used with its -m option
                // but that still means these known failed ipc socket attempts
                // make this backround polling take much longer than expected.
                // Report when a connection attempt fails to respond quickly,
                // and consider taking it out of the rotation completely.
                if endpoint.getData() {

                    // If the poll was successful, remove the item from our list because
                    // it will be given its own timer queue. But if a subsequent
                    // poll fails, give it a closure to execute that gets the item put back
                    // onto our queue for polling.

                    removeIndexes.append(index)
                    endpoint.startOwnPoller(repeating: self.activePollRate,
                                            registrar: registrar,
                                            resubmit: {
                                                // Use own dispatch queue to add endpoint to end of list.
                                                self.timer?.async { // or sync, shouldn't matter.
                                                    if self.timer == nil {
                                                    }
                                                    self.endpoints.append(endpoint)
                                                }})
                }
            }

            for index in removeIndexes.reversed() {
                self.endpoints.remove(at: index)
            }
            registrar.asyncSetPollingFinished()
        }
    }

    private func newIpcSocket(files: [String]) {
        for file in files {
            let ipcEndpoint = IPCEndpoint(path: file)

            self.endpoints.append(ipcEndpoint)
            strongs.append(ipcEndpoint) // TBD may not be necessary
        }
    }

    private func newTcpSocket(url: URL) {
        let tcpEndpoint = TCPEndpoint(url: url)

        self.endpoints.append(tcpEndpoint)
        strongs.append(tcpEndpoint) // TBD may not be necessary
    }

    private static func ipcSocketGroups(strings: [String]) -> ([String], [IpcSocketDirectory]) {
        var files: [String] = []
        var dirs: [IpcSocketDirectory] = []

        for string in strings {

            let type = fileType(path: string)
            switch type {
            case .typeSocket:
                files.append(string)
            case .typeDirectory:
                dirs.append(IpcSocketDirectory(directory: string, source: .config))
            default:
                break
            }
        }

        return (files, dirs)
    }
}

private class IpcSocketDirectory {
    // TBD information that may not be useful, depending on how
    // the command line works out.
    enum Source {
        case config
        case cmdline
    }
    let source: Source
    let directory: String
    var socketDirectorySearch: SocketDirectorySearch
    init(directory: String, source: Source) {
        self.directory = directory
        self.source = source
        self.socketDirectorySearch = SocketDirectorySearch(directory: directory)
    }

    func searchForNewSockets() -> [String] {
        var list: [String] = []

        for socketPath in socketDirectorySearch.searchForNewSockets() {
            list.append(socketPath)
        }

        return list
    }
}
