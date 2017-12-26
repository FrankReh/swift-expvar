# expvar
A macOS app for viewing the JSON output by the golang expvar package.

[upspin.io](https://upspin.io/) is one project that uses the expvar package.

## Build

Builds with swift from the command line on recent macOS versions.

```
$ swift build
```

Should compile in a few seconds with no warnings or errors.

Tested with

```
$ swift -version
Apple Swift version 4.0.2 (swiftlang-900.0.69.2 clang-900.0.38)
Target: x86_64-apple-macosx10.9
```

## Run

Run by invoking the executable.

```
$ .build/debug/expvar
```

You should see a new icon appear in the screen's status bar. This leads to a
menu, with a 'summary window' menu item, among other things.

The running process uses one background thread to look for new IPC and TCP sockets that respond to
the HTTP "/debug/vars" request. It uses one background thread per such socket found, such sockets are
referred to as endpoints. And it uses
one thread for the window and mouse and keyboard interactions, as is usual with such applications.

## Config

A config file named expvar.json is read when the program begins.
Details are in [Config](CONFIG.md).

## Summary Window

There is a main window that lists the endpoints found, along with their status and running details.
From each endpoint's running details, windows can be brought up showing various aspects of their poll results.

## Endpoint Windows

There are four windows that are per endpoint. The user may display any combination of windows for any or all
of the active endpoints.
The first three endpoint winndows are designed to show the next to last JSON data and the last JSON data and to
highlight the differences.
When there is no difference, the last JSON data field is left blank.

### JSON Window

The window for manual traversal of the JSON tree that comes from the endpoint on each poll cycle.
The window contents can be navigated by mouse or keyboard arrow keys.

This window allows array and dictionaries to be expanded.

It is presently the only window that lets the user pause the refresh of the Next Value column
and also the reset of the Prev Value column.

And also the only window that presents the option of displaying the Delta Column.

One shortcoming at the moment is that new fields in the JSON tree, or even changing types for the same field,
will not be picked up by the running implementation. A restart would be needed. Expect to address this in a
future version.

Also a future direction for this window would be to allow the user to specify which prior version of JSON tree
to make the comparison against, perhaps the first one received, perhaps the first or last one that coincided
with a go GC.

### MemStats Window

This window shows the MemStats portion of the JSON tree, with the intention of applying more semantics to the fields
and their display than the JSON window is designed to do.

The history for each field can be pulled up by clicking on the field.

### BySize Window

The array of BySize structures in the expvar JSON tree is shown here, with the size pulled out and used as the key
to the table being displayed. Again, the history for each field can be pulled up by clicking on a field.

### User Window

This window contains the row/column cells that the user has selected from other endpoint windows.
Rows and columns are built up as needed. The row/column cells are selected when the user double clicks on them
in another window. This is mean to let the user select a few fields from the JSON tree or a few counters
from MemStats or BySize that will be of interest while the other windows can then be closed or moved off to the side.

This window is more of an experiment than the other three endpoint windows.
