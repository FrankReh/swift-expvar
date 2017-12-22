// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

extension String {
    func prefixpad(toLength: Int) -> String {
        let l = self.count
        guard l < toLength else {
            return self
        }
        let pad = "".padding(toLength: (toLength-l), withPad: " ", startingAt: 0)
        return pad + self
    }
}

struct RectPieces {
    var x: String
    var y: String
    var w: String
    var h: String
    init(_ rect: CGRect) {
        x = String(format: "%.0f", rect.minX).prefixpad(toLength: 4)
        y = String(format: "%.0f", rect.minY).prefixpad(toLength: 4)
        w = String(format: "%.0f", rect.width).prefixpad(toLength: 4)
        h = String(format: "%.0f", rect.height).prefixpad(toLength: 4)
    }
    func combine() -> String {
        return "((\(x) \(y))(\(w) \(h)))" // "((origin) (size))"
    }
}
private func rectString(_ rect: CGRect) -> String {
    // Just show Ints, padded to three characters
    // And no commas are needed either.
    let pieces = RectPieces(rect)
    return pieces.combine()
}

extension NSWindow {
    func printframe(label: String) {
        let paddedlabel = label.padding(toLength: 25, withPad: " ", startingAt: 0)
        let frameRect = self.frame
        let cntntRect = self.contentRect(forFrameRect: frameRect)

        let framePieces = RectPieces(frameRect)
        // Look at the contentRect pieces and mark any that are the same with the frame pieces.
        // So visually, it is easier to see what about the contentRect is dissimilar to the frame.
        var cntntPieces = RectPieces(cntntRect)

        let frameStr = framePieces.combine()
        if framePieces.x == cntntPieces.x {
            cntntPieces.x = "same"
        }
        if framePieces.y == cntntPieces.y {
            cntntPieces.y = "same"
        }
        if framePieces.w == cntntPieces.w {
            cntntPieces.w = "same"
        }
        if framePieces.h == cntntPieces.h {
            cntntPieces.h = "same"
        }
        let cntntStr = cntntPieces.combine()

        let isKey = self.isKeyWindow ? "is key": "is not key"
        let canBecomeKey = self.canBecomeKey ? "can become key" : "cannot become key"
        print("NSWindow:\(paddedlabel) frame \(frameStr) contentRect \(cntntStr) \(isKey), \(canBecomeKey)")
    }
}

extension NSView {
    func printframe(label: String) {
        let paddedlabel = label.padding(toLength: 25, withPad: " ", startingAt: 0)
        let frameRect = self.frame
        let boundsRect = self.bounds
        var boundsStr = ""
        if !hasZeroPoint(boundsRect) || frameRect.size != boundsRect.size {
            boundsStr = " bounds\(rectString(boundsRect))"
        }
        print("NSView  :\(paddedlabel) frame \(rectString(frameRect))\(boundsStr)")
    }
    func printframestack(label: String) {
        self.superview?.printframestackR(label: label, depth: 0)
        self.printframe(label: label)
    }
    private func printframestackR(label: String, depth: Int) {
        self.superview?.printframestackR(label: label, depth: (depth+1))
        self.printframe(label: "super \(depth) \(label)")
    }
}

func hasZeroPoint(_ f: NSRect) -> Bool {
    return f.minX == 0.0 && f.minY == 0.0
}

func hasZeroSize(_ f: NSRect) -> Bool {
    return f.width == 0.0 && f.height == 0.0
}

// TBD may not be needed
func isZeroFrame(_ f: NSRect) -> Bool {
    return hasZeroPoint(f) && hasZeroSize(f)
}
