// Copyright 2017 Frank Rehwinkel. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import AppKit

class SummaryRow: PolledDataObserver, ReloadDataObserver {
    weak var summaryViewController: SummaryViewController?
    weak var connection: Connection?

    private var varsHistory: VarsHistory? {
        return self.connection?.varsObservable?.varsHistory
    }
    private var pollcount = 0
    private var pollcountString = ""
    var configString: String

    lazy var detailPanel: DetailPanel = { [unowned self] in
        guard let connection = self.connection,
              let summaryViewController = self.summaryViewController else {
                  fatalError("weak references already cleaned up")
              }
        return DetailPanel(frame: summaryViewController.rightFrame,
                          configName: summaryViewController.rightConfigName,
                          connection: connection)
    }()

    init(summaryViewController: SummaryViewController,
         connection: Connection) {
        self.summaryViewController = summaryViewController
        self.connection = connection
        // Start with a configString value that will change with the first poll result.
        self.configString = "no poll result yet"

        connection.pollObservable.observers.add(self)
    }

    func polledDataFailure() {
        summaryViewController?.reloadRow(self)
    }

    func polledDataAvailable() {
        // Endpoint data has arrived and been parsed successfully for first time.
        guard let varsObservable = connection?.varsObservable else {
            fatalError("bug")
        }
        varsObservable.observers.add(self)

        // The first poll result is in. Set configString correctly.
        self.configString = extractConfigString(cmdline: varsObservable.varsHistory.cmdline) ?? ""
        summaryViewController?.reloadRow(self)
    }
    func reloadData() {
        // called by the varsObservable when new data for the connection has arrived.
        summaryViewController?.reloadRow(self)
    }

    // Access methods to support the table cell drawing.

    func cmd() -> String {
        guard let v = varsHistory, v.cmdline.count > 0  else {
            return ""
        }
        return v.cmdline[0]
    }
    func endpoint() -> String {
        return self.connection?.description ?? ""
    }
    func health() -> (String, NSImage?) {
        guard let pollObservable =  self.connection?.pollObservable else {
            return ("no polling info", nil)
        }
        return pollObservable.health()
    }
    func gcValue() -> String {
        // TBD bit of a hack that the words "in between" show up in the root column when it is wide enough.
        return varsHistory?.memstats.pauseEnd.historyDeltaDescription() ?? ""
    }
    func gcPause() -> String {
        return varsHistory?.memstats.pauseNs.historyCurrentDescription() ?? ""
    }
    func numberofpolls() -> String {
        return String(describing: self.connection?.varsObservable?.pollcount ?? 0)
    }
}

private func extractConfigString(cmdline: [String]) -> String? {
    for arg in cmdline {
        if arg.hasPrefix("-config=") {
            return arg // TBD strip front part off
        }
    }
    return nil
}
