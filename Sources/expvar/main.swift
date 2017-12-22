// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

loadConfig(file: defaultConfigFilename)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

let inactiveEndpoints = InactiveEndpoints()

inactiveEndpoints.startPolling(registrar: delegate)

app.run()
