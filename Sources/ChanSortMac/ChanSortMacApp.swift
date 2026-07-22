// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

@main
struct ChanSortMacApp: App {
    @StateObject private var store = ChannelStore()

    var body: some Scene {
        WindowGroup(L10n.text("app.title")) {
            ContentView()
                .environmentObject(store)
                .onOpenURL { store.open($0) }
        }
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.text("menu.open")) { store.requestOpen() }
                    .keyboardShortcut("o")
                Divider()
                Button(L10n.text("menu.save")) { store.save() }
                    .keyboardShortcut("s")
                    .disabled(store.document == nil)
                Button(L10n.text("menu.saveAs")) { store.requestSaveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(store.document == nil || !store.canSaveAs)
            }
            CommandGroup(replacing: .undoRedo) {
                Button(L10n.text("menu.undo")) { store.undo() }
                    .keyboardShortcut("z")
                    .disabled(!store.canUndo)
                Button(L10n.text("menu.redo")) { store.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!store.canRedo)
            }
            CommandMenu(L10n.text("menu.channel")) {
                Button(L10n.text("toolbar.moveUp")) { store.moveSelected(by: -1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command])
                Button(L10n.text("toolbar.moveDown")) { store.moveSelected(by: 1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command])
                Divider()
                Button(L10n.text("menu.deleteRestore")) { store.toggleDeleted() }
                    .keyboardShortcut(.delete, modifiers: [])
                Button(L10n.text("toolbar.restoreAll")) { store.restoreAll() }
                Divider()
                Button(L10n.text("toolbar.sortProgram")) { store.sortByProgramNumber() }
            }
            LegalCommands()
        }

        Window(L10n.text("legal.window.title"), id: "legal") {
            LegalView()
        }
        .defaultSize(width: 900, height: 680)
        .windowResizability(.contentMinSize)
    }
}

private struct LegalCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L10n.text("menu.aboutLegal")) {
                openWindow(id: "legal")
            }
        }
    }
}
