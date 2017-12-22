// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// LogLevel represents the logging verbosity level.
// .none indicates no log messages should be printed.
// .low indicates a low frequency level is requested, just the most important.
// 
enum LogLevel: Int {
    case none = 0
    case low = 1 // important
    case medium = 2
    case high = 3 // unimportant
    func level(_ level: LogLevel) -> Bool {
        return self.rawValue >= level.rawValue
    }
    static func from(string: String) -> LogLevel? {
        switch string {
        case "none":
            return .none
        case "low":
            return .low
        case "medium":
            return .medium
        case "high":
            return .high
        default:
            return nil
        }
    }
}
