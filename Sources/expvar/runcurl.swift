// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

func runCmdForData(cmd: String, args: [String]) throws -> (outdata: Data, stderr: String) {
    let task = Process()
    task.launchPath = cmd
    task.arguments = args
    let outpipe = Pipe()
    let errpipe = Pipe()
    task.standardOutput = outpipe
    task.standardError = errpipe
    task.launch()
    let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
    let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
    let stderr = String(data: errdata, encoding: .utf8) ?? ""
    task.waitUntilExit()
    let status = task.terminationStatus

    if status != 0 {
        throw BackendError.processFailure(launchPath: cmd, args: args, status: status, stderr: stderr)
    }
    return (outdata, stderr)
}

func runCurlIPC(filename: String) throws -> (Data, String) {
    let path = "/usr/bin/curl"

    // Try as HTTP over unix domain socket, aka IPC.
    // TBD make the ipc -m timeout value configurable.
    let cmdargs = ["-m", "1", "--unix-socket", filename, "http://:/debug/vars"]

    let (data, stderr) = try runCmdForData(cmd: path, args: cmdargs)

    return (data, stderr)
}

// This function isn't used right now but it came in handy before settling on the URLSession route
// in the getHTTP function. Worth keeping around.
func runCurlTCP(filename: String) throws -> (Data, String) {
    let path = "/usr/bin/curl"

    // Try as HTTP over TCP.
    // TBD make the tcp -m timeout value configurable.
    let cmdargs = ["-m", "1", "http://" + filename + "/debug/vars"]

    let (data, stderr) = try runCmdForData(cmd: path, args: cmdargs)

    if data.count == 7 { // TBD change to check for actual string
        let str = String(data: data, encoding: .utf8) ?? "nonzero data not utf8"
        throw BackendError.curlTCPYieldsBadData(launchPath: path, args: cmdargs, data: str)
    }

    return (data, stderr)
}
