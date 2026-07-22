// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

struct LegalView: View {
    @State private var selection: LegalPage? = .about

    var body: some View {
        NavigationSplitView {
            List(LegalPage.allCases, selection: $selection) { page in
                Label(page.title, systemImage: page.symbol)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            Group {
                switch selection ?? .about {
                case .about: AboutLegalPage()
                case .licence: LegalDocumentPage(
                    title: L10n.text("legal.license.title"),
                    subtitle: L10n.text("legal.license.subtitle"),
                    fileName: "LICENSE"
                )
                case .source: LegalDocumentPage(
                    title: L10n.text("legal.source.title"),
                    subtitle: L10n.text("legal.source.subtitle"),
                    fileName: "SOURCE-CODE.md"
                )
                case .libraries: LibrariesPage()
                case .trademarks: LegalDocumentPage(
                    title: L10n.text("legal.trademarks.title"),
                    subtitle: L10n.text("legal.trademarks.subtitle"),
                    fileName: "TRADEMARKS.md"
                )
                }
            }
            .frame(minWidth: 560, minHeight: 500)
        }
        .navigationTitle(L10n.text("legal.window.title"))
    }
}

private enum LegalPage: String, CaseIterable, Identifiable {
    case about, licence, source, libraries, trademarks

    var id: Self { self }
    var title: String { L10n.text("legal.page.\(rawValue)") }
    var symbol: String {
        switch self {
        case .about: "info.circle"
        case .licence: "doc.text"
        case .source: "chevron.left.forwardslash.chevron.right"
        case .libraries: "shippingbox"
        case .trademarks: "character.book.closed"
        }
    }
}

private struct AboutLegalPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 18) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ChanSort Mac").font(.largeTitle.weight(.semibold))
                        Text(L10n.format("legal.version", appVersion))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(L10n.text("legal.unofficial"))
                            .font(.callout.weight(.medium)).foregroundStyle(.orange)
                    }
                }

                LegalCard(title: L10n.text("legal.publisher.title"), symbol: "person.crop.rectangle") {
                    Text("Thomas Meroth · Meroth IT-Service")
                    Link("www.pcffm.de", destination: URL(string: "https://www.pcffm.de")!)
                    Text("Copyright © 2026 Thomas Meroth, Meroth IT-Service")
                        .font(.caption).foregroundStyle(.secondary)
                }

                LegalCard(title: L10n.text("legal.upstream.title"), symbol: "arrow.triangle.branch") {
                    Text(L10n.text("legal.upstream.body"))
                    Link("github.com/PredatH0r/ChanSort", destination: URL(string: "https://github.com/PredatH0r/ChanSort")!)
                }

                LegalCard(title: L10n.text("legal.rights.title"), symbol: "checkmark.shield") {
                    Text(L10n.text("legal.rights.body"))
                    Text(L10n.text("legal.warranty"))
                        .font(.callout.weight(.semibold))
                }

                LegalCard(title: L10n.text("legal.privacy.title"), symbol: "lock.shield") {
                    Text(L10n.text("legal.privacy.body"))
                }

                Text(L10n.text("legal.origin.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.0"
    }
}

private struct LibrariesPage: View {
    private let libraries = [
        LibraryNotice("ChanSort API and device loaders", "2025-03-08", "Horst Beham and contributors", "GPL-3.0-only"),
        LibraryNotice("Microsoft .NET Runtime · macOS arm64", "8.0.29", "Microsoft, .NET Foundation and contributors", "MIT + notices"),
        LibraryNotice("Microsoft.Data.Sqlite", "8.0.13", "Microsoft Corporation", "MIT"),
        LibraryNotice("Microsoft.Data.Sqlite.Core", "8.0.13", "Microsoft Corporation", "MIT"),
        LibraryNotice("Newtonsoft.Json", "13.0.3", "James Newton-King", "MIT"),
        LibraryNotice("SQLitePCLRaw.bundle_e_sqlite3", "2.1.6", "SourceGear, LLC", "Apache-2.0"),
        LibraryNotice("SQLitePCLRaw.core", "2.1.6", "SourceGear, LLC", "Apache-2.0"),
        LibraryNotice("SQLitePCLRaw.lib.e_sqlite3", "2.1.6", "SourceGear, LLC", "Apache-2.0"),
        LibraryNotice("SQLitePCLRaw.provider.e_sqlite3", "2.1.6", "SourceGear, LLC", "Apache-2.0"),
        LibraryNotice("System.Memory", "4.5.3", "Microsoft Corporation and contributors", "MIT + notices")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LegalPageHeader(
                    title: L10n.text("legal.libraries.title"),
                    subtitle: L10n.text("legal.libraries.subtitle")
                )
                ForEach(libraries) { library in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(library.name).font(.headline)
                            Spacer()
                            Text(library.version).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Text(library.author).font(.subheadline).foregroundStyle(.secondary)
                        Text(library.licence)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }
                Divider()
                Text(L10n.text("legal.libraries.fullNotices"))
                    .font(.callout).foregroundStyle(.secondary)
                Text(LegalDocument.load("THIRD-PARTY-NOTICES.md"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(28)
            .frame(maxWidth: 780, alignment: .leading)
        }
    }
}

private struct LibraryNotice: Identifiable {
    let name: String
    let version: String
    let author: String
    let licence: String
    var id: String { name }

    init(_ name: String, _ version: String, _ author: String, _ licence: String) {
        self.name = name
        self.version = version
        self.author = author
        self.licence = licence
    }
}

private struct LegalDocumentPage: View {
    let title: String
    let subtitle: String
    let fileName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LegalPageHeader(title: title, subtitle: subtitle)
                Divider()
                Text(LegalDocument.load(fileName))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: 780, alignment: .leading)
        }
    }
}

private struct LegalPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.weight(.semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct LegalCard<Content: View>: View {
    let title: String
    let symbol: String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } label: {
            Label(title, systemImage: symbol).font(.headline)
        }
    }
}

private enum LegalDocument {
    static func load(_ fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let candidates: [(Bundle, String?)] = [
            (Bundle.main, nil),
            (Bundle.main, "Legal"),
            (.module, nil),
            (.module, "Legal")
        ]
        for (bundle, directory) in candidates {
            if let url = bundle.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: directory),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return L10n.format("legal.document.missing", fileName)
    }
}
