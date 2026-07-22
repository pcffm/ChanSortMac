// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum ChannelFileFormat: String, CaseIterable, Codable {
    case device = "Original device export"
    case m3u = "M3U / M3U8"
    case enigma2 = "Enigma2 bouquet"
    case vdr = "VDR channels.conf"
    case delimited = "CSV / TSV"

    var canEditProvider: Bool {
        self == .m3u || self == .vdr || self == .delimited
    }
}

struct ChannelListDescriptor: Identifiable, Hashable, Codable {
    var id: Int
    var name: String
    var signalSource: Int64 = 0
    var isReadOnly = false
    var channelCount = 0
}

struct DeviceFeatures: Hashable, Codable {
    var channelNameEdit = "All"
    var deleteMode = "Flag"
    var canSaveAs = true
    var canSkip = false
    var canLock = false
    var canHide = false
    var favoritesMode = "None"
    var maxFavoriteLists = 0

    static let native = DeviceFeatures()
}

struct DeviceDocument: Hashable, Codable {
    var plugin: String
    var pluginType: String
    var serializer: String
    var tvModel: String?
    var formatVersion: String?
    var information: String
    var warnings: String
    var features: DeviceFeatures
}

struct Channel: Identifiable, Hashable, Codable {
    var id = UUID()
    var originalIndex: Int
    var programNumber: Int
    var name: String
    var provider: String = ""
    var source: String = ""
    var frequency: String = ""
    var serviceType: String = ""
    var isDeleted = false
    var isHidden = false
    var isSkipped = false
    var isLocked = false
    var favorites: Int64 = 0
    var oldProgramNumber: Int? = nil
    var listID = 0
    var listName = "Channels"
    var backendID: String? = nil
    var satellite = ""
    var rawLines: [String] = []
    var fields: [String] = []
}

struct ChannelFile {
    var url: URL
    var format: ChannelFileFormat
    var channels: [Channel]
    var lists: [ChannelListDescriptor] = []
    var device: DeviceDocument? = nil
    var headerLines: [String] = []
    var trailingLines: [String] = []
    var columnNames: [String] = []
    var delimiter: Character = ";"
    var newline = "\n"
    var usesByteOrderMark = false
}

enum ChanSortError: LocalizedError {
    case unsupportedFormat(String)
    case invalidFile(String)
    case noDocument

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let name):
            return L10n.format("error.unsupported", name)
        case .invalidFile(let reason):
            return reason
        case .noDocument:
            return L10n.text("error.noDocument")
        }
    }
}
