// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// jsonObject returns a top-level object of Array or Dictionary,
// else throws an error.
func jsonObject(data: Data) throws -> Any {
    return try JSONSerialization.jsonObject(with: data, options: [.mutableContainers])
}
