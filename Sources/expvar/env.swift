// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// Specifically look for $TMPDIR and $TMPDIR/.* for now.
// Expand later if necessary.
func envSubstitution(strings: inout [String]) {
    for i in 0..<strings.count {

        // A little work to avoid partial matching something like
        // $TMPDIRECTORY.

        // Look for $TMPDIR/ first.
        // TBD warning, this branch hasn't been tested.
        if let range = strings[i].range(of: "$TMPDIR/") {
            strings[i].replaceSubrange(range, with: envTMPDIR()+"/")
            continue
        }

        if strings[i] == "$TMPDIR" {
            if let range = strings[i].range(of: "$TMPDIR") {
                strings[i].replaceSubrange(range, with: envTMPDIR())
        }
            continue
        }
    }
}

private func envTMPDIR() -> String {
    guard let value = ProcessInfo.processInfo.environment["TMPDIR"] else {
        print("error: TMPDIR not found in environment")
        exit(1)
    }
    return value
}
