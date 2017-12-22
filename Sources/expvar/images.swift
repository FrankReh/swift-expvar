// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

// https://developer.apple.com/documentation/appkit/nsimage.name
func imageOk() -> NSImage? {
    return NSImage(named: NSImage.Name.statusAvailable)
}
func imageNone() -> NSImage? {
    return NSImage(named: NSImage.Name.statusNone)
}
func imageWarning() -> NSImage? {
    return NSImage(named: NSImage.Name.statusPartiallyAvailable)
}
func imageStopped() -> NSImage? {
    return NSImage(named: NSImage.Name.statusUnavailable)
}
