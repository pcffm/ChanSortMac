// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ChannelStore: ObservableObject {
    @Published private(set) var document: ChannelFile?
    @Published var selection: Set<UUID> = []
    @Published private(set) var activeListID = 0
    @Published var searchText = ""
    @Published var showDeleted = false
    @Published private(set) var isDirty = false
    @Published var errorMessage: String?
    @Published var statusMessage = L10n.text("store.initial")

    private var undoStack: [[Channel]] = []
    private var redoStack: [[Channel]] = []
    private var backedUpURLs: Set<URL> = []

    var channels: [Channel] { document?.channels.filter { $0.listID == activeListID } ?? [] }

    var channelLists: [ChannelListDescriptor] { document?.lists ?? [] }

    var activeList: ChannelListDescriptor? {
        channelLists.first { $0.id == activeListID }
    }

    var features: DeviceFeatures { document?.device?.features ?? .native }
    var canSaveAs: Bool { document?.device?.features.canSaveAs ?? true }
    var canEditNames: Bool { features.channelNameEdit != "None" && activeList?.isReadOnly != true }
    var canDelete: Bool { features.deleteMode != "None" && activeList?.isReadOnly != true }

    var filteredChannels: [Channel] {
        channels.filter { channel in
            (showDeleted || !channel.isDeleted) &&
            (searchText.isEmpty || channel.name.localizedCaseInsensitiveContains(searchText)
                || channel.provider.localizedCaseInsensitiveContains(searchText)
                || channel.source.localizedCaseInsensitiveContains(searchText)
                || channel.satellite.localizedCaseInsensitiveContains(searchText))
        }
    }

    var selectedChannel: Channel? {
        guard let id = selection.first else { return nil }
        return channels.first(where: { $0.id == id })
    }

    var selectedChannels: [Channel] {
        channels.filter { selection.contains($0.id) }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func requestOpen() {
        let panel = NSOpenPanel()
        panel.title = L10n.text("dialog.open.title")
        panel.prompt = L10n.text("common.open")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "m3u") ?? .data,
            UTType(filenameExtension: "m3u8") ?? .data,
            .commaSeparatedText,
            .tabSeparatedText,
            .plainText,
            .data
        ]
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    func open(_ url: URL) {
        do {
            var loaded = try ChannelFileIO.load(from: url)
            if loaded.lists.isEmpty {
                loaded.lists = [ChannelListDescriptor(id: 0, name: L10n.text("store.defaultList"), channelCount: loaded.channels.count)]
                for index in loaded.channels.indices {
                    loaded.channels[index].listID = 0
                    loaded.channels[index].listName = L10n.text("store.defaultList")
                }
            }
            activeListID = loaded.lists.first(where: { $0.channelCount > 0 })?.id ?? loaded.lists.first?.id ?? 0
            document = loaded
            selection = Set(channels.first.map { [$0.id] } ?? [])
            undoStack.removeAll()
            redoStack.removeAll()
            backedUpURLs.removeAll()
            isDirty = false
            let format = loaded.device?.plugin ?? loaded.format.rawValue
            statusMessage = L10n.format("store.loaded", loaded.channels.count, format)
        } catch {
            present(error)
        }
    }

    func save() {
        guard let document else { present(ChanSortError.noDocument); return }
        save(to: document.url)
    }

    func requestSaveAs() {
        guard let document else { present(ChanSortError.noDocument); return }
        guard canSaveAs else {
            present(ChanSortError.invalidFile(L10n.text("error.saveAsDevice")))
            return
        }
        let panel = NSSavePanel()
        panel.title = L10n.text("dialog.saveAs.title")
        panel.nameFieldStringValue = document.url.lastPathComponent
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            save(to: url)
        }
    }

    func save(to url: URL) {
        guard var document else { present(ChanSortError.noDocument); return }
        do {
            var backupURL: URL?
            if url.standardizedFileURL == document.url.standardizedFileURL,
               FileManager.default.fileExists(atPath: url.path),
               !backedUpURLs.contains(url.standardizedFileURL) {
                backupURL = try createBackup(of: url)
                backedUpURLs.insert(url.standardizedFileURL)
            }
            try ChannelFileIO.save(document, to: url)
            document.url = url
            self.document = document
            isDirty = false
            if let backupURL {
                statusMessage = L10n.format("store.savedBackup", backupURL.lastPathComponent)
            } else {
                statusMessage = L10n.format("store.saved", url.lastPathComponent)
            }
        } catch {
            present(error)
        }
    }

    func updateName(_ name: String) {
        guard canEditNames else { return }
        mutateSelected { $0.name = name }
    }

    func updateName(_ id: UUID, name: String) {
        guard canEditNames else { return }
        mutate(id: id) { $0.name = name }
    }

    func updateProvider(_ provider: String) {
        guard document?.format.canEditProvider == true else { return }
        mutateSelected { $0.provider = provider }
    }

    func toggleHidden() { toggleBoolean(\.isHidden, allowed: features.canHide, label: L10n.text("inspector.hidden")) }
    func toggleSkipped() { toggleBoolean(\.isSkipped, allowed: features.canSkip, label: L10n.text("inspector.skip")) }
    func toggleLocked() { toggleBoolean(\.isLocked, allowed: features.canLock, label: L10n.text("inspector.locked")) }

    func toggleFavorite(_ index: Int) {
        guard index >= 0, index < features.maxFavoriteLists, !selection.isEmpty, var document else { return }
        let mask = Int64(1) << Int64(index)
        checkpoint()
        let shouldSet = selectedChannels.first.map { ($0.favorites & mask) == 0 } ?? true
        for channelIndex in document.channels.indices where selection.contains(document.channels[channelIndex].id) {
            if shouldSet { document.channels[channelIndex].favorites |= mask }
            else { document.channels[channelIndex].favorites &= ~mask }
        }
        self.document = document
        isDirty = true
        statusMessage = L10n.format("store.favorite", index + 1)
    }

    func selectList(_ id: Int) {
        guard id != activeListID, channelLists.contains(where: { $0.id == id }) else { return }
        activeListID = id
        selection = Set(channels.first.map { [$0.id] } ?? [])
        searchText = ""
        statusMessage = L10n.format("store.listSelected", activeList?.name ?? L10n.text("store.defaultList"))
    }

    func moveSelected(toProgramNumber value: Int) {
        guard !selection.isEmpty, var document else { return }
        checkpoint()
        var active = channels
        let moving = active.filter { selection.contains($0.id) }
        active.removeAll { selection.contains($0.id) }
        let newIndex = min(max(0, value - 1), active.count)
        active.insert(contentsOf: moving, at: newIndex)
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = L10n.format("store.inserted", moving.count, value)
    }

    func moveSelected(by offset: Int) {
        guard !selection.isEmpty, offset != 0, var document else { return }
        checkpoint()
        var active = channels
        if offset < 0 {
            for index in 1..<active.count where selection.contains(active[index].id) && !selection.contains(active[index - 1].id) {
                active.swapAt(index, index - 1)
            }
        } else if active.count > 1 {
            for index in stride(from: active.count - 2, through: 0, by: -1)
                where selection.contains(active[index].id) && !selection.contains(active[index + 1].id) {
                active.swapAt(index, index + 1)
            }
        }
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = L10n.format("store.moved", selection.count)
    }

    func moveChannel(_ sourceID: UUID, before targetID: UUID, placeAfter: Bool = false) {
        moveChannels([sourceID], before: targetID, placeAfter: placeAfter)
    }

    func moveChannels(_ sourceIDs: Set<UUID>, before targetID: UUID, placeAfter: Bool = false) {
        var active = channels
        guard !sourceIDs.isEmpty, !sourceIDs.contains(targetID), var document,
              let originalTargetIndex = active.firstIndex(where: { $0.id == targetID }) else { return }
        checkpoint()
        let moving = active.filter { sourceIDs.contains($0.id) }
        let removedBeforeTarget = active[..<originalTargetIndex].filter { sourceIDs.contains($0.id) }.count
        active.removeAll { sourceIDs.contains($0.id) }
        var targetIndex = originalTargetIndex
        targetIndex -= removedBeforeTarget
        if placeAfter { targetIndex += 1 }
        targetIndex = min(max(0, targetIndex), active.count)
        active.insert(contentsOf: moving, at: targetIndex)
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        selection = sourceIDs
        isDirty = true
        statusMessage = L10n.format("store.dragged", moving.count)
    }

    func toggleDeleted(_ id: UUID? = nil) {
        guard canDelete else { return }
        let targets = id.map { Set([$0]) } ?? selection
        guard !targets.isEmpty, var document else { return }
        checkpoint()
        var active = channels
        let shouldDelete = active.first(where: { targets.contains($0.id) })?.isDeleted == false
        for index in active.indices where targets.contains(active[index].id) {
            active[index].isDeleted = shouldDelete
        }
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = shouldDelete ? L10n.format("store.deleted", targets.count) : L10n.format("store.restored", targets.count)
        if shouldDelete && !showDeleted {
            selection = Set(filteredChannels.first.map { [$0.id] } ?? [])
        }
    }

    func sortSelectedByName() {
        guard selection.count > 1, var document else { return }
        checkpoint()
        var active = channels
        let indices = active.indices.filter { selection.contains(active[$0].id) }
        let sorted = indices.map { active[$0] }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        for (offset, index) in indices.enumerated() { active[index] = sorted[offset] }
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = L10n.text("store.sortedSelection")
    }

    func swapSelected() {
        guard selection.count == 2, var document else { return }
        var active = channels
        let indices = active.indices.filter { selection.contains(active[$0].id) }
        guard indices.count == 2 else { return }
        checkpoint()
        active.swapAt(indices[0], indices[1])
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = L10n.text("store.swapped")
    }

    func swapChannels(_ sourceID: UUID, with targetID: UUID) {
        guard sourceID != targetID, var document else { return }
        var active = channels
        guard let sourceIndex = active.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = active.firstIndex(where: { $0.id == targetID }) else { return }
        checkpoint()
        active.swapAt(sourceIndex, targetIndex)
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        selection = [sourceID]
        isDirty = true
        statusMessage = L10n.text("store.swapped")
    }

    func moveSelectionToBoundary(top: Bool) {
        guard !selection.isEmpty, var document else { return }
        checkpoint()
        var active = channels
        let moving = active.filter { selection.contains($0.id) }
        active.removeAll { selection.contains($0.id) }
        if top { active.insert(contentsOf: moving, at: 0) }
        else { active.append(contentsOf: moving) }
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = L10n.text(top ? "store.top" : "store.bottom")
    }

    func restoreAll() {
        guard var document, channels.contains(where: { $0.isDeleted }) else { return }
        checkpoint()
        var active = channels
        for index in active.indices { active[index].isDeleted = false }
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = L10n.text("store.restoredAll")
    }

    func sortByProgramNumber() {
        guard var document else { return }
        checkpoint()
        var active = channels
        active.sort {
            if $0.programNumber == $1.programNumber { return $0.originalIndex < $1.originalIndex }
            return $0.programNumber < $1.programNumber
        }
        renumber(&active)
        replaceActiveChannels(active, in: &document)
        self.document = document
        isDirty = true
        statusMessage = L10n.text("store.sortedProgram")
    }

    func undo() {
        guard var document, let state = undoStack.popLast() else { return }
        redoStack.append(document.channels)
        document.channels = state
        self.document = document
        isDirty = true
        statusMessage = L10n.text("store.undo")
    }

    func redo() {
        guard var document, let state = redoStack.popLast() else { return }
        undoStack.append(document.channels)
        document.channels = state
        self.document = document
        isDirty = true
        statusMessage = L10n.text("store.redo")
    }

    func confirmCloseIfNeeded() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = L10n.text("dialog.unsaved.title")
        alert.informativeText = L10n.text("dialog.unsaved.message")
        alert.addButton(withTitle: L10n.text("common.save"))
        alert.addButton(withTitle: L10n.text("common.discard"))
        alert.addButton(withTitle: L10n.text("common.cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: save(); return !isDirty
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    private func mutateSelected(_ change: (inout Channel) -> Void) {
        guard selection.count == 1, let id = selection.first else { return }
        mutate(id: id, change)
    }

    private func mutate(id: UUID, _ change: (inout Channel) -> Void) {
        guard var document, let index = document.channels.firstIndex(where: { $0.id == id }) else { return }
        checkpoint()
        change(&document.channels[index])
        self.document = document
        isDirty = true
        statusMessage = L10n.text("store.modified")
    }

    private func toggleBoolean(_ keyPath: WritableKeyPath<Channel, Bool>, allowed: Bool, label: String) {
        guard allowed, !selection.isEmpty, var document else { return }
        checkpoint()
        let enabled = !(selectedChannels.first?[keyPath: keyPath] ?? false)
        for index in document.channels.indices where selection.contains(document.channels[index].id) {
            document.channels[index][keyPath: keyPath] = enabled
        }
        self.document = document
        isDirty = true
        statusMessage = L10n.format("store.flag", label, selection.count, L10n.text(enabled ? "store.enabled" : "store.disabled"))
    }

    private func checkpoint() {
        guard let document else { return }
        undoStack.append(document.channels)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func renumber(_ channels: inout [Channel]) {
        var number = 1
        for index in channels.indices where !channels[index].isDeleted {
            channels[index].programNumber = number
            number += 1
        }
    }

    private func replaceActiveChannels(_ active: [Channel], in document: inout ChannelFile) {
        var iterator = active.makeIterator()
        for index in document.channels.indices where document.channels[index].listID == activeListID {
            guard let channel = iterator.next() else { break }
            document.channels[index] = channel
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        statusMessage = L10n.text("store.error")
    }

    private func createBackup(of url: URL) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = url.lastPathComponent + ".backup-" + formatter.string(from: Date())
        let backup = url.deletingLastPathComponent().appendingPathComponent(name)
        try FileManager.default.copyItem(at: url, to: backup)
        return backup
    }
}
