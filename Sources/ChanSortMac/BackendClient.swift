// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum BackendClient {
    private struct Command {
        let executable: URL
        let prefixArguments: [String]
    }

    private struct ProbeResponse: Decodable {
        var plugin: String
        var pluginType: String
        var serializer: String
        var tvModel: String?
        var formatVersion: String?
        var information: String
        var warnings: String
        var features: DeviceFeatures
        var lists: [ListResponse]
    }

    private struct ListResponse: Decodable {
        var id: Int
        var name: String?
        var signalSource: Int64
        var readOnly: Bool
        var channels: [ChannelResponse]
    }

    private struct ChannelResponse: Decodable {
        var id: String
        var oldProgramNumber: Int
        var programNumber: Int
        var name: String?
        var provider: String?
        var source: String?
        var satellite: String?
        var frequencyMhz: Double
        var serviceType: Int
        var deleted: Bool
        var hidden: Bool
        var skipped: Bool
        var locked: Bool
        var favorites: Int64
    }

    private struct SaveRequest: Encodable {
        var sourceFile: String
        var outputFile: String
        var plugin: String
        var channels: [ChannelEdit]
    }

    private struct ChannelEdit: Encodable {
        var id: String
        var programNumber: Int
        var name: String
        var deleted: Bool
        var hidden: Bool
        var skipped: Bool
        var locked: Bool
        var favorites: Int64
    }

    private struct ErrorResponse: Decodable { var error: String }

    static func shouldProbe(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        if name == "lamedb" || name == "settingsdb.db" || name == "settingsdb_enc.db" { return true }
        if name.hasPrefix("dvb") && name.hasSuffix("_config.xml") { return true }
        if name.contains("dvbs") && ext == "csv" { return true }
        if name == "senderliste.txt" { return true }
        return ["db", "bin", "zip", "scm", "tll", "xml", "sdx", "dbm", "cdp", "tar"].contains(ext)
    }

    static func probe(_ url: URL) throws -> ChannelFile {
        let data = try run(arguments: ["probe", url.path])
        let response = try JSONDecoder().decode(ProbeResponse.self, from: data)
        var channels: [Channel] = []
        var lists: [ChannelListDescriptor] = []
        for list in response.lists {
            let listName = list.name?.isEmpty == false ? list.name! : L10n.format("store.listFallback", list.id + 1)
            lists.append(ChannelListDescriptor(
                id: list.id,
                name: listName,
                signalSource: list.signalSource,
                isReadOnly: list.readOnly,
                channelCount: list.channels.count
            ))
            for item in list.channels {
                channels.append(Channel(
                    originalIndex: channels.count,
                    programNumber: item.programNumber,
                    name: item.name ?? "",
                    provider: item.provider ?? "",
                    source: item.source ?? "",
                    frequency: formatFrequency(item.frequencyMhz),
                    serviceType: serviceTypeName(item.serviceType),
                    isDeleted: item.deleted,
                    isHidden: item.hidden,
                    isSkipped: item.skipped,
                    isLocked: item.locked,
                    favorites: item.favorites,
                    oldProgramNumber: item.oldProgramNumber,
                    listID: list.id,
                    listName: listName,
                    backendID: item.id,
                    satellite: item.satellite ?? ""
                ))
            }
        }
        let device = DeviceDocument(
            plugin: response.plugin,
            pluginType: response.pluginType,
            serializer: response.serializer,
            tvModel: response.tvModel,
            formatVersion: response.formatVersion,
            information: response.information,
            warnings: response.warnings,
            features: response.features
        )
        return ChannelFile(url: url, format: .device, channels: channels, lists: lists, device: device)
    }

    static func save(_ file: ChannelFile, to url: URL) throws {
        guard let device = file.device else { throw ChanSortError.invalidFile(L10n.text("error.deviceInfoMissing")) }
        let edits = file.channels.compactMap { channel -> ChannelEdit? in
            guard let id = channel.backendID else { return nil }
            return ChannelEdit(
                id: id,
                programNumber: channel.programNumber,
                name: channel.name,
                deleted: channel.isDeleted,
                hidden: channel.isHidden,
                skipped: channel.isSkipped,
                locked: channel.isLocked,
                favorites: channel.favorites
            )
        }
        let request = SaveRequest(
            sourceFile: file.url.path,
            outputFile: url.path,
            plugin: device.pluginType,
            channels: edits
        )
        let requestURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChanSort-save-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: requestURL) }
        try JSONEncoder().encode(request).write(to: requestURL, options: .atomic)
        _ = try run(arguments: ["save", requestURL.path])
    }

    private static func run(arguments: [String]) throws -> Data {
        guard let command = locateCommand() else {
            throw ChanSortError.invalidFile(L10n.text("error.backendMissing"))
        }
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = command.executable
        process.arguments = command.prefixArguments + arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            if let response = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ChanSortError.invalidFile(response.error)
            }
            let message = String(data: errorData.isEmpty ? data : errorData, encoding: .utf8) ?? L10n.text("error.loaderUnknown")
            throw ChanSortError.invalidFile(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return data
    }

    private static func locateCommand() -> Command? {
        let fileManager = FileManager.default
        if let resources = Bundle.main.resourceURL {
            let bundled = resources.appendingPathComponent("Backend/ChanSort.Backend")
            if fileManager.isExecutableFile(atPath: bundled.path) {
                return Command(executable: bundled, prefixArguments: [])
            }
        }

        let sourceFile = URL(fileURLWithPath: #filePath)
        let project = sourceFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let published = project.appendingPathComponent("Backend/bin/publish/osx-arm64/ChanSort.Backend")
        if fileManager.isExecutableFile(atPath: published.path) {
            return Command(executable: published, prefixArguments: [])
        }
        let dotnet = project.deletingLastPathComponent().appendingPathComponent("dotnet-sdk/dotnet")
        let dll = project.appendingPathComponent("Backend/bin/Release/net8.0/osx-arm64/ChanSort.Backend.dll")
        if fileManager.isExecutableFile(atPath: dotnet.path), fileManager.fileExists(atPath: dll.path) {
            return Command(executable: dotnet, prefixArguments: [dll.path])
        }
        return nil
    }

    private static func formatFrequency(_ value: Double) -> String {
        guard value != 0 else { return "" }
        return String(format: value.rounded() == value ? "%.0f" : "%.3f", value)
    }

    private static func serviceTypeName(_ value: Int) -> String {
        switch value {
        case 1, 17, 22, 25: return "TV"
        case 2, 10: return "Radio"
        case 0: return ""
        default: return "Typ \(value)"
        }
    }
}
