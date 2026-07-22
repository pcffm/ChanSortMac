// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

struct ChannelTableView: NSViewRepresentable {
    let channels: [Channel]
    @Binding var selection: Set<UUID>
    var autosaveName: String
    var canRename = true
    var onMove: (Set<UUID>, UUID, Bool) -> Void
    var onRename: (UUID, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = KeyboardTableView()
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.allowsColumnReordering = true
        table.allowsColumnResizing = true
        table.usesAlternatingRowBackgroundColors = true
        table.selectionHighlightStyle = .regular
        table.focusRingType = .none
        table.rowHeight = 28
        table.intercellSpacing = NSSize(width: 8, height: 1)
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.headerView = NSTableHeaderView()
        table.autosaveName = NSTableView.AutosaveName(autosaveName)
        table.autosaveTableColumns = true
        table.registerForDraggedTypes([Coordinator.channelPasteboardType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.onDelete = { [weak coordinator = context.coordinator] in coordinator?.deleteSelection() }

        for definition in ColumnDefinition.all {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(definition.id))
            column.title = definition.title
            column.width = definition.width
            column.minWidth = definition.minWidth
            column.maxWidth = definition.maxWidth
            column.resizingMask = [.userResizingMask, .autoresizingMask]
            column.headerCell.alignment = definition.alignment
            column.sortDescriptorPrototype = NSSortDescriptor(key: definition.id, ascending: true)
            table.addTableColumn(column)
        }
        table.sortDescriptors = [NSSortDescriptor(key: "program", ascending: true)]

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.automaticallyAdjustsContentInsets = false
        context.coordinator.tableView = table
        context.coordinator.refresh(forceReload: true)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refresh()
    }

    private struct ColumnDefinition {
        let id: String
        let title: String
        let width: CGFloat
        let minWidth: CGFloat
        let maxWidth: CGFloat
        let alignment: NSTextAlignment

        static let all = [
            ColumnDefinition(id: "program", title: L10n.text("table.column.program"), width: 64, minWidth: 48, maxWidth: 110, alignment: .right),
            ColumnDefinition(id: "name", title: L10n.text("table.column.name"), width: 245, minWidth: 130, maxWidth: 600, alignment: .left),
            ColumnDefinition(id: "provider", title: L10n.text("table.column.provider"), width: 145, minWidth: 80, maxWidth: 350, alignment: .left),
            ColumnDefinition(id: "source", title: L10n.text("table.column.source"), width: 120, minWidth: 70, maxWidth: 280, alignment: .left),
            ColumnDefinition(id: "frequency", title: L10n.text("table.column.frequency"), width: 90, minWidth: 68, maxWidth: 150, alignment: .right),
            ColumnDefinition(id: "type", title: L10n.text("table.column.type"), width: 85, minWidth: 60, maxWidth: 150, alignment: .left),
            ColumnDefinition(id: "original", title: L10n.text("table.column.original"), width: 72, minWidth: 52, maxWidth: 110, alignment: .right),
            ColumnDefinition(id: "state", title: L10n.text("table.column.state"), width: 115, minWidth: 80, maxWidth: 220, alignment: .left)
        ]
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        static let channelPasteboardType = NSPasteboard.PasteboardType("de.chansort.mac.channel-ids")

        var parent: ChannelTableView
        weak var tableView: NSTableView?
        private var rows: [Channel] = []
        private var isSynchronizingSelection = false

        init(_ parent: ChannelTableView) {
            self.parent = parent
        }

        func refresh(forceReload: Bool = false) {
            guard let tableView else { return }
            let updatedRows = sorted(parent.channels, using: tableView.sortDescriptors)
            if forceReload || updatedRows != rows {
                rows = updatedRows
                tableView.reloadData()
            }
            isSynchronizingSelection = true
            let indexes = IndexSet(rows.indices.filter { parent.selection.contains(rows[$0].id) })
            if tableView.selectedRowIndexes != indexes {
                tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            }
            isSynchronizingSelection = false
        }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0, row < rows.count, let tableColumn else { return nil }
            let channel = rows[row]
            let identifier = tableColumn.identifier
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? makeCell(identifier)
            guard let field = cell.textField else { return cell }
            field.alignment = tableColumn.headerCell.alignment
            field.toolTip = channel.name

            let value: String
            switch identifier.rawValue {
            case "program": value = channel.programNumber > 0 ? String(channel.programNumber) : "—"
            case "name": value = channel.name
            case "provider": value = channel.provider
            case "source": value = channel.source.isEmpty ? channel.satellite : channel.source
            case "frequency": value = channel.frequency
            case "type": value = channel.serviceType
            case "original": value = channel.oldProgramNumber.map(String.init) ?? String(channel.originalIndex + 1)
            case "state": value = stateText(channel)
            default: value = ""
            }

            if channel.isDeleted {
                field.attributedStringValue = NSAttributedString(
                    string: value,
                    attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                 .foregroundColor: NSColor.secondaryLabelColor]
                )
            } else {
                field.stringValue = value
                field.textColor = identifier.rawValue == "name" ? .labelColor : .secondaryLabelColor
            }
            if let editable = field as? ChannelNameField {
                editable.isEditable = parent.canRename && !channel.isDeleted
                editable.channelID = channel.id
                editable.onCommit = parent.onRename
            }
            return cell
        }

        private func makeCell(_ identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let field: NSTextField
            if identifier.rawValue == "name" {
                let editable = ChannelNameField()
                editable.isEditable = true
                editable.isSelectable = true
                editable.isBordered = false
                editable.drawsBackground = false
                editable.focusRingType = .none
                editable.delegate = self
                field = editable
            } else {
                field = NSTextField(labelWithString: "")
            }
            field.translatesAutoresizingMaskIntoConstraints = false
            field.lineBreakMode = .byTruncatingTail
            field.maximumNumberOfLines = 1
            cell.textField = field
            cell.addSubview(field)
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSynchronizingSelection, let tableView else { return }
            parent.selection = Set(tableView.selectedRowIndexes.compactMap { index in
                index < rows.count ? rows[index].id : nil
            })
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            refresh(forceReload: true)
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row >= 0, row < rows.count else { return nil }
            let item = NSPasteboardItem()
            item.setString(rows[row].id.uuidString, forType: Self.channelPasteboardType)
            return item
        }

        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                       proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            guard row >= 0, row <= rows.count, !rows.isEmpty,
                  tableView.sortDescriptors.first?.key == "program" else { return [] }
            tableView.setDropRow(row, dropOperation: .above)
            return .move
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                       row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard !rows.isEmpty else { return false }
            let items = info.draggingPasteboard.pasteboardItems ?? []
            let ids = Set(items.compactMap { item in
                item.string(forType: Self.channelPasteboardType).flatMap(UUID.init(uuidString:))
            })
            let targetIndex = min(max(0, row), rows.count - 1)
            let target = rows[targetIndex].id
            guard !ids.isEmpty, !ids.contains(target) else { return false }
            parent.onMove(ids, target, row >= rows.count)
            return true
        }

        private func stateText(_ channel: Channel) -> String {
            var values: [String] = []
            if channel.isDeleted { values.append(L10n.text("table.state.deleted")) }
            if channel.isHidden { values.append(L10n.text("table.state.hidden")) }
            if channel.isSkipped { values.append(L10n.text("table.state.skipped")) }
            if channel.isLocked { values.append(L10n.text("table.state.locked")) }
            if channel.favorites != 0 { values.append(L10n.text("table.state.favorite")) }
            return values.isEmpty ? L10n.text("table.state.active") : values.joined(separator: ", ")
        }

        func deleteSelection() {
            NotificationCenter.default.post(name: .channelTableDeleteSelection, object: nil)
        }

        private func sorted(_ channels: [Channel], using descriptors: [NSSortDescriptor]) -> [Channel] {
            guard let descriptor = descriptors.first, let key = descriptor.key else { return channels }
            let ascending = descriptor.ascending
            return channels.sorted { lhs, rhs in
                let order: ComparisonResult
                switch key {
                case "program": order = lhs.programNumber == rhs.programNumber ? .orderedSame : (lhs.programNumber < rhs.programNumber ? .orderedAscending : .orderedDescending)
                case "name": order = lhs.name.localizedStandardCompare(rhs.name)
                case "provider": order = lhs.provider.localizedStandardCompare(rhs.provider)
                case "source": order = (lhs.source.isEmpty ? lhs.satellite : lhs.source).localizedStandardCompare(rhs.source.isEmpty ? rhs.satellite : rhs.source)
                case "frequency": order = lhs.frequency.localizedStandardCompare(rhs.frequency)
                case "type": order = lhs.serviceType.localizedStandardCompare(rhs.serviceType)
                case "original":
                    let left = lhs.oldProgramNumber ?? lhs.originalIndex + 1
                    let right = rhs.oldProgramNumber ?? rhs.originalIndex + 1
                    order = left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
                case "state": order = lhs.isDeleted == rhs.isDeleted ? .orderedSame : (lhs.isDeleted ? .orderedDescending : .orderedAscending)
                default: order = .orderedSame
                }
                if order == .orderedSame { return lhs.originalIndex < rhs.originalIndex }
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
        }
    }
}

private final class ChannelNameField: NSTextField {
    var channelID: UUID?
    var onCommit: ((UUID, String) -> Void)?

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        if let channelID { onCommit?(channelID, stringValue) }
    }
}

private final class KeyboardTableView: NSTableView {
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 {
            onDelete?()
        } else {
            super.keyDown(with: event)
        }
    }
}

extension Notification.Name {
    static let channelTableDeleteSelection = Notification.Name("ChannelTableDeleteSelection")
}
