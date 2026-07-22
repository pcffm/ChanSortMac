// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI
import XCTest
@testable import ChanSortMac

final class UIStabilityTests: XCTestCase {
    @MainActor
    func testTableRowsRemainWhenSelectionBecomesEmpty() {
        let channels = [
            Channel(originalIndex: 0, programNumber: 1, name: "One"),
            Channel(originalIndex: 1, programNumber: 2, name: "Two")
        ]
        var selected = Set([channels[0].id])
        let binding = Binding<Set<UUID>>(get: { selected }, set: { selected = $0 })
        var view = ChannelTableView(
            channels: channels,
            selection: binding,
            autosaveName: "ChanSortMac.Tests.Table",
            onMove: { _, _, _ in },
            onRename: { _, _ in }
        )
        let coordinator = view.makeCoordinator()
        let table = NSTableView()
        table.sortDescriptors = [NSSortDescriptor(key: "program", ascending: true)]
        coordinator.tableView = table
        coordinator.refresh(forceReload: true)
        XCTAssertEqual(coordinator.numberOfRows(in: table), 2)

        selected.removeAll()
        view = ChannelTableView(
            channels: channels,
            selection: binding,
            autosaveName: "ChanSortMac.Tests.Table",
            onMove: { _, _, _ in },
            onRename: { _, _ in }
        )
        coordinator.parent = view
        coordinator.refresh()
        XCTAssertEqual(coordinator.numberOfRows(in: table), 2)
        XCTAssertTrue(table.selectedRowIndexes.isEmpty)
    }

    func testEnglishAndGermanLocalizationResourcesExist() throws {
        let englishPath = try XCTUnwrap(Bundle.module.path(forResource: "en", ofType: "lproj"))
        let germanPath = try XCTUnwrap(Bundle.module.path(forResource: "de", ofType: "lproj"))
        let english = try XCTUnwrap(Bundle(path: englishPath))
        let german = try XCTUnwrap(Bundle(path: germanPath))
        XCTAssertEqual(english.localizedString(forKey: "welcome.open", value: nil, table: nil), "Open channel list…")
        XCTAssertEqual(german.localizedString(forKey: "welcome.open", value: nil, table: nil), "Senderliste öffnen …")
    }

    @MainActor
    func testMinimumWindowKeepsTableVisibleAfterFocusLeavesTable() throws {
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let store = ChannelStore()
        store.open(project.appendingPathComponent("Samples/demo.m3u"))
        let expectedRows = store.filteredChannels.count
        let host = NSHostingView(rootView: ContentView().environmentObject(store))
        host.frame = NSRect(x: 0, y: 0, width: 920, height: 640)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        let table = try XCTUnwrap(descendants(of: host).compactMap { $0 as? NSTableView }.first)
        XCTAssertGreaterThan(table.enclosingScrollView?.frame.height ?? 0, 250)
        XCTAssertEqual(table.numberOfRows, expectedRows)

        store.selection.removeAll()
        host.window?.makeFirstResponder(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertGreaterThan(table.enclosingScrollView?.frame.height ?? 0, 250)
        XCTAssertEqual(table.numberOfRows, expectedRows)

        if let path = ProcessInfo.processInfo.environment["CHANSORT_UI_SNAPSHOT"],
           let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }

    @MainActor
    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}
