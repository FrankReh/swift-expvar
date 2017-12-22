// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

func fileType(path: String) -> FileAttributeType {
    let filemanager = FileManager.default
    do {
        let attributes = try filemanager.attributesOfItem(atPath: path)
        if let type = attributes[.type] as? FileAttributeType {
            return type
        }
    } catch {
    }
    return .typeUnknown
}

// SocketDirectory is init with a directory path and can search for sockets,
// keeping the sockets found. To avoid making a system call for the
// attributes of files that were already seen, a map is kept of seen files.
// Subsequent calls to search() only add new sockets to the internal list.
class SocketDirectorySearch {
    let directory: String
    var seen: [String: Bool] = [:] // could be called isSocket, but may be used for tracking directories too.

    init(directory: String) {
        self.directory = directory
    }

    // May want to call this on a background thread.
    func searchForNewSockets() -> [String] {
        let filemanager = FileManager.default
        var filenames: [String]
        do {
            filenames = try filemanager.contentsOfDirectory(atPath: directory)
        } catch {
            return []
        }

        var newsockets: [String] = []

        for filename in filenames {
            guard seen[filename] == nil else {
                // already seen
                continue
            }
            seen[filename] = false
            do {
                let fullpath = "\(directory)/\(filename)"
                let attributes = try filemanager.attributesOfItem(atPath: fullpath)
                if let type = attributes[.type] as? FileAttributeType {
                    if type == .typeSocket {
                        seen[filename] = true // Change to true, it is a socket.
                        newsockets.append(fullpath)
                    }
                }
            } catch {
            }
        }
        return newsockets
    }
}

// TBD may not be needed
class SocketPath {
    let directory: String
    let base: String
    let full: String
    init(directory: String, base: String) {
        self.directory = directory
        self.base = base
        self.full = directory + "/" + base
    }
}
func socketsInDirectory(atPath path: String) throws -> [SocketPath] {
    let filemanager = FileManager.default
    let items = try filemanager.contentsOfDirectory(atPath: path)

    var sockets: [SocketPath] = []

    for item in items {
        let attributes = try filemanager.attributesOfItem(atPath: "\(path)/\(item)")
        if let type = attributes[.type] as? FileAttributeType {
            if type == .typeSocket {
                sockets.append(SocketPath(directory: path, base: item))
            }
        }
    }
    return sockets
}
