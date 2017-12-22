// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
func isSorted(_ array: [Int64]) -> Bool {
    if array.count > 0 {
        for i in 1..<array.count where array[i-1] > array[i] {
            return false
        }
    }
    return true
}
*/

// sortedRanges returns slices of sorted ranges, capping off at three since we
// only expect one or two and can treat three as a failure case for the
// caller to deal with. Also only ranges containing nonzero values are returned.
func sortedRanges(_ list: [Int64]) -> [ArraySlice<Int64>] {
    var r: [ArraySlice<Int64>] = []

    guard list.count > 0 else {
        return r
    }

    var nextBase = 0
    for i in 1..<list.count {

        if list[i] < list[i-1] {
            let newrange = list[nextBase..<i]

            r.append(newrange)
            if r.count >= 3 {
                // Cut search short if this is the third.
                return r
            }
            nextBase = i
        }
        if list[i] <= 0 {
            // Skip 0 entries. Also assume there won't be negative values.
            nextBase = i+1
        }
    }

    // Catch at least the last range. If the whole list is sorted, this will be
    // the only slice appended. If the last number in the list was zero, this
    // won't fire because nextBase will have been incremented off the back.
    if nextBase < list.count {
        r.append(list[nextBase..<list.count])
    }

    return flipFirstTwo(r)
}

// flipFirstTwo, when it seems an array of two slices, verifies the second one
// is less than the first, and then it returns them in the opposite order.
func flipFirstTwo (_ ranges: [ArraySlice<Int64>]) -> [ArraySlice<Int64>] {
    guard ranges.count == 2 && ranges[0].count > 0 && ranges[1].count > 0 else {
        return ranges
    }
    guard first(ranges[1]) <= last(ranges[0]) else {
        // Return nothing if the second wasn't completely less than the first.
        return []
    }
    return [ranges[1], ranges[0]]
}

func first(_ slice: ArraySlice<Int64>) -> Int64 {
    return slice[slice.startIndex]
}

func last(_ slice: ArraySlice<Int64>) -> Int64 {
    return slice[slice.endIndex-1]
}
