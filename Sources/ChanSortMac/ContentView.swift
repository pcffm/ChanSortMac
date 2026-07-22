// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChannelStore
    @State private var targetProgramNumber = "1"
    @State private var tableMode: TableMode = .single
    @State private var placement: PlacementMode = .before
    @State private var showsInspector = true

    private enum TableMode: CaseIterable, Identifiable {
        case single, split
        var id: Self { self }
        var title: String { L10n.text(self == .single ? "toolbar.oneList" : "toolbar.twoLists") }
        var symbol: String { self == .single ? "rectangle" : "rectangle.split.2x1" }
    }

    private enum PlacementMode: CaseIterable, Identifiable {
        case before, after, swap
        var id: Self { self }
        var title: String {
            switch self {
            case .before: L10n.text("toolbar.before")
            case .after: L10n.text("toolbar.after")
            case .swap: L10n.text("toolbar.swap")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.document == nil { WelcomeView() }
            else { documentView }
            Divider()
            statusBar
        }
        .frame(minWidth: 920, minHeight: 640)
        .alert(L10n.text("app.title"), isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button(L10n.text("common.ok"), role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var documentView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    documentHeader
                    Divider()
                    actionBar
                    Divider()
                    tableArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(10)
                        .onReceive(NotificationCenter.default.publisher(for: .channelTableDeleteSelection)) { _ in
                            store.toggleDeleted()
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(10)

                if showsInspector {
                    Divider()
                    InspectorView()
                        .frame(width: min(320, max(280, geometry.size.width * 0.28)))
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showsInspector)
        }
    }

    private var documentHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(L10n.text("toolbar.channelList"), systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                Picker("", selection: Binding(
                    get: { store.activeListID },
                    set: { store.selectList($0) }
                )) {
                    ForEach(store.channelLists) { list in
                        Text("\(list.name)  ·  \(list.channelCount)").tag(list.id)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 180, idealWidth: 260, maxWidth: 330)

                if store.activeList?.isReadOnly == true {
                    Label(L10n.text("toolbar.readOnly"), systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 12)
                Picker("", selection: $tableMode) {
                    ForEach(TableMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                Button { showsInspector.toggle() } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.bordered)
                .tint(showsInspector ? .accentColor : nil)
                .help(L10n.text("toolbar.inspector"))
            }
            .padding(.horizontal, 14)
            .frame(height: 48)

            Divider().padding(.leading, 14)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L10n.text("toolbar.search"), text: $store.searchText)
                    .textFieldStyle(.plain)
                if !store.searchText.isEmpty {
                    Button { store.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Divider().frame(height: 18)
                Toggle(L10n.text("toolbar.showDeleted"), isOn: $store.showDeleted)
                    .toggleStyle(.checkbox)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
        }
        .background(.bar)
    }

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Text(store.selection.isEmpty
                     ? L10n.text("toolbar.selection.none")
                     : L10n.format("toolbar.selection.count", store.selection.count))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(store.selection.isEmpty ? .secondary : .primary)
                    .frame(minWidth: 84, alignment: .leading)

                ControlGroup {
                    actionButton("arrow.up", help: "toolbar.moveUp") { store.moveSelected(by: -1) }
                    actionButton("arrow.down", help: "toolbar.moveDown") { store.moveSelected(by: 1) }
                    actionButton("arrow.up.to.line", help: "toolbar.moveTop") { store.moveSelectionToBoundary(top: true) }
                    actionButton("arrow.down.to.line", help: "toolbar.moveBottom") { store.moveSelectionToBoundary(top: false) }
                }
                .disabled(store.selection.isEmpty)

                Divider().frame(height: 24)

                Text(L10n.text("toolbar.target"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("#", text: $targetProgramNumber)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 58)
                    .onSubmit { applyTargetNumber() }

                Menu {
                    ForEach(PlacementMode.allCases) { mode in
                        Button {
                            placement = mode
                        } label: {
                            if placement == mode { Label(mode.title, systemImage: "checkmark") }
                            else { Text(mode.title) }
                        }
                    }
                } label: {
                    Text(placement.title).frame(minWidth: 66)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button(placement == .swap ? L10n.text("common.apply") : L10n.text("toolbar.insert")) {
                    applyTargetNumber()
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.selection.isEmpty || (placement == .swap && store.selection.count != 1))

                Menu {
                    Button(L10n.text("toolbar.sortSelection")) { store.sortSelectedByName() }
                        .disabled(store.selection.count < 2)
                    Button(L10n.text("toolbar.swapSelected")) { store.swapSelected() }
                        .disabled(store.selection.count != 2)
                    Divider()
                    Button(L10n.text("toolbar.sortProgram")) { store.sortByProgramNumber() }
                    Button(L10n.text("toolbar.restoreAll")) { store.restoreAll() }
                } label: {
                    Label(L10n.text("toolbar.more"), systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func actionButton(_ symbol: String, help key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }.help(L10n.text(key))
    }

    @ViewBuilder
    private var tableArea: some View {
        if tableMode == .split {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    tablePanel(
                        title: L10n.text("table.sorted"),
                        channels: store.filteredChannels.filter { $0.programNumber > 0 && !$0.isDeleted },
                        autosave: "ChanSortMac.V3.SortedTable"
                    )
                    .frame(width: max(280, (geometry.size.width - 1) / 2))
                    Divider()
                    tablePanel(
                        title: L10n.text("table.all"),
                        channels: store.filteredChannels,
                        autosave: "ChanSortMac.V3.AllTable"
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            stableTable(channels: store.filteredChannels, autosave: "ChanSortMac.V3.MainTable")
        }
    }

    private func tablePanel(title: String, channels: [Channel], autosave: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Text("\(channels.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            stableTable(channels: channels, autosave: autosave)
        }
        .frame(maxHeight: .infinity)
    }

    private func stableTable(channels: [Channel], autosave: String) -> some View {
        ZStack {
            ChannelTableView(
                channels: channels,
                selection: $store.selection,
                autosaveName: autosave,
                canRename: store.canEditNames,
                onMove: handleMove,
                onRename: { id, name in store.updateName(id, name: name) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if channels.isEmpty {
                EmptyState(
                    title: L10n.text("table.empty.title"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    detail: L10n.text("table.empty.detail")
                )
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func handleMove(_ ids: Set<UUID>, _ target: UUID, _ droppedAfter: Bool) {
        if placement == .swap, ids.count == 1, let source = ids.first {
            store.swapChannels(source, with: target)
        } else {
            store.moveChannels(ids, before: target, placeAfter: droppedAfter || placement == .after)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(store.isDirty ? Color.orange : Color.green)
                .frame(width: 7, height: 7)
            Text(store.statusMessage).lineLimit(1)
            Spacer(minLength: 16)
            if let document = store.document {
                Text(L10n.format("status.count", store.filteredChannels.count, store.channels.count))
                    .monospacedDigit()
                Text("•")
                Text(document.device?.plugin ?? document.format.rawValue)
                    .lineLimit(1)
                if store.isDirty {
                    Text("• \(L10n.text("status.unsaved"))").foregroundStyle(.orange)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.bar)
    }

    private func applyTargetNumber() {
        guard let number = Int(targetProgramNumber), number > 0 else { return }
        if placement == .swap,
           store.selection.count == 1,
           let source = store.selection.first,
           let target = store.channels.first(where: { $0.programNumber == number }) {
            store.swapChannels(source, with: target.id)
        } else {
            store.moveSelected(toProgramNumber: placement == .after ? number + 1 : number)
        }
        targetProgramNumber = String(number + store.selection.count)
    }
}

private struct InspectorView: View {
    @EnvironmentObject private var store: ChannelStore
    @State private var programNumber = ""
    @State private var name = ""
    @State private var provider = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.text("inspector.title")).font(.headline)
                Spacer()
                if !store.selection.isEmpty {
                    Text("\(store.selection.count)")
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            Divider()

            if let channel = store.selectedChannel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if store.selection.count > 1 {
                            Text(L10n.format("inspector.multiple", store.selection.count))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        GroupBox {
                            VStack(spacing: 10) {
                                inspectorField(L10n.text("inspector.program"), text: $programNumber)
                                    .onSubmit {
                                        if let value = Int(programNumber), value > 0 { store.moveSelected(toProgramNumber: value) }
                                    }
                                inspectorField(L10n.text("inspector.name"), text: $name)
                                    .disabled(store.selection.count != 1 || !store.canEditNames)
                                    .onSubmit { store.updateName(name) }
                                inspectorField(L10n.text("inspector.provider"), text: $provider)
                                    .disabled(store.document?.format.canEditProvider != true || store.selection.count != 1)
                                    .onSubmit { store.updateProvider(provider) }
                            }
                        }

                        GroupBox {
                            VStack(spacing: 8) {
                                detailRow("inspector.format", store.document?.device?.plugin ?? store.document?.format.rawValue ?? "")
                                if !channel.frequency.isEmpty { detailRow("inspector.frequency", channel.frequency) }
                                if !channel.source.isEmpty { detailRow("inspector.source", channel.source) }
                                detailRow("inspector.original", String(channel.oldProgramNumber ?? channel.originalIndex + 1))
                                if !channel.satellite.isEmpty { detailRow("inspector.satellite", channel.satellite) }
                            }
                        }

                        if store.features.canHide || store.features.canSkip || store.features.canLock {
                            GroupBox(L10n.text("inspector.flags")) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if store.features.canHide { Toggle(L10n.text("inspector.hidden"), isOn: flagBinding(\.isHidden, action: store.toggleHidden)) }
                                    if store.features.canSkip { Toggle(L10n.text("inspector.skip"), isOn: flagBinding(\.isSkipped, action: store.toggleSkipped)) }
                                    if store.features.canLock { Toggle(L10n.text("inspector.locked"), isOn: flagBinding(\.isLocked, action: store.toggleLocked)) }
                                }
                                .toggleStyle(.checkbox)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if store.features.maxFavoriteLists > 0 {
                            GroupBox(L10n.text("inspector.favorites")) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 7) {
                                    ForEach(0..<min(store.features.maxFavoriteLists, 8), id: \.self) { index in
                                        Button(String(UnicodeScalar(65 + index)!)) { store.toggleFavorite(index) }
                                            .buttonStyle(.bordered)
                                            .tint((channel.favorites & (Int64(1) << Int64(index))) != 0 ? .accentColor : .gray)
                                    }
                                }
                            }
                        }

                        Button(role: channel.isDeleted ? nil : .destructive) {
                            store.toggleDeleted()
                        } label: {
                            Label(
                                L10n.text(channel.isDeleted ? "inspector.restore" : "inspector.delete"),
                                systemImage: channel.isDeleted ? "arrow.uturn.backward" : "trash"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canDelete)
                    }
                    .padding(16)
                }
            } else {
                EmptyState(
                    title: L10n.text("inspector.none.title"),
                    systemImage: "cursorarrow.click.2",
                    detail: L10n.text("inspector.none.detail")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { if let channel = store.selectedChannel { load(channel) } }
        .onChange(of: store.selection) { _ in if let channel = store.selectedChannel { load(channel) } }
    }

    private func inspectorField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            TextField(title, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.text(key)).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).lineLimit(2).multilineTextAlignment(.trailing)
        }
    }

    private func load(_ channel: Channel) {
        programNumber = String(channel.programNumber)
        name = channel.name
        provider = channel.provider
    }

    private func flagBinding(_ keyPath: KeyPath<Channel, Bool>, action: @escaping () -> Void) -> Binding<Bool> {
        Binding(get: { store.selectedChannel?[keyPath: keyPath] ?? false }, set: { _ in action() })
    }
}

private struct EmptyState: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage).font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
    }
}

private struct WelcomeView: View {
    @EnvironmentObject private var store: ChannelStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "tv.and.mediabox").font(.system(size: 72, weight: .thin)).foregroundStyle(.tint)
            Text(L10n.text("welcome.title")).font(.largeTitle.weight(.semibold))
            Text(L10n.text("welcome.subtitle")).font(.title3).foregroundStyle(.secondary)
            Button(L10n.text("welcome.open")) { store.requestOpen() }
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut("o")
            Text(L10n.text("welcome.formats")).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(
            colors: [Color.accentColor.opacity(0.09), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }
}
