// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

func getHTTP(url: URL) throws -> Data {

    let dispatchQueue = DispatchQueue(label: "GET")
    let dispatchGroup = DispatchGroup()

    var returnData: Data?
    var returnError: Error?

    dispatchQueue.sync {

        dispatchGroup.enter()

        let task = URLSession.shared.dataTask(with: url) { (data, _, error) in
            returnData = data
            returnError = error
            dispatchGroup.leave()
        }
        task.resume()

        dispatchGroup.wait()
        //dispatchGroup.wait(timeout: .distantFuture)
    }

    if let returnError = returnError {
        throw returnError
    }

    if let returnData = returnData {
        return returnData
    }

    throw BackendError.getHTTPNoData(cmd: "URLSession.shared.dataTask(with: url)", url: url)
}
