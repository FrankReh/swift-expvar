// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

private let errorName = "Error:"

enum BackendError: Error {
    case getHTTPNoData(cmd: String, url: URL)
    case jsonNotDictionary(json: Any?)
    case processFailure(launchPath: String, args: [String], status: Int32, stderr: String)
    case curlTCPYieldsBadData(launchPath: String, args: [String], data: String)

    func keyValues() -> [(String, String)] {
        var r: [(String, String)] = []
        switch self {
        case let .getHTTPNoData(cmd, url):
            r.append((errorName, "GetHTTPNoData"))
            r.append(("cmd:", cmd))
            r.append(("url:", url.description))
        case let .jsonNotDictionary(json):
            r.append((errorName, "JsonNotDictionary"))
            r.append(("json:", String(describing: json)))
        case let .processFailure(launchPath, args, status, stderr):
            r.append((errorName, "ProcessFailure"))
            r.append(("launchPath:", launchPath))
            r.append(("args:", String(describing: args)))
            r.append(("status:", String(describing: status)))
            if stderr != "" {
                r.append(("stderr:", stderr))
            }
        case let .curlTCPYieldsBadData(launchPath, args, data):
            r.append((errorName, "CurlTCPYieldsBadData"))
            r.append(("launchPath:", launchPath))
            r.append(("args:", String(describing: args)))
            r.append(("data:", String(describing: data)))
        }

        return r
    }
}
