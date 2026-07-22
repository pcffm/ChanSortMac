// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum ChannelFileIO {
    static func load(from url: URL) throws -> ChannelFile {
        if BackendClient.shouldProbe(url) {
            return try BackendClient.probe(url)
        }
        let data = try Data(contentsOf: url)
        let bom = data.starts(with: [0xEF, 0xBB, 0xBF])
        guard let text = String(data: bom ? data.dropFirst(3) : data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw ChanSortError.invalidFile(L10n.text("error.textDecode"))
        }

        let newline = text.contains("\r\n") ? "\r\n" : "\n"
        let lowerName = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        var file: ChannelFile

        if ["m3u", "m3u8"].contains(ext) || text.hasPrefix("#EXTM3U") {
            file = try M3UAdapter.load(text: text, url: url)
        } else if lowerName.hasPrefix("userbouquet.") || text.contains("#SERVICE") {
            file = try Enigma2Adapter.load(text: text, url: url)
        } else if lowerName == "channels.conf" || VDRAdapter.looksLikeVDR(text) {
            file = try VDRAdapter.load(text: text, url: url)
        } else if ["csv", "tsv", "txt"].contains(ext) {
            file = try DelimitedAdapter.load(text: text, url: url)
        } else {
            throw ChanSortError.unsupportedFormat(url.lastPathComponent)
        }

        file.newline = newline
        file.usesByteOrderMark = bom
        return file
    }

    static func save(_ file: ChannelFile, to url: URL) throws {
        let text: String
        switch file.format {
        case .device:
            try BackendClient.save(file, to: url)
            return
        case .m3u: text = M3UAdapter.serialize(file)
        case .enigma2: text = Enigma2Adapter.serialize(file)
        case .vdr: text = VDRAdapter.serialize(file)
        case .delimited: text = DelimitedAdapter.serialize(file)
        }
        var data = Data()
        if file.usesByteOrderMark {
            data.append(contentsOf: [0xEF, 0xBB, 0xBF])
        }
        data.append(text.data(using: .utf8) ?? Data())
        try data.write(to: url, options: .atomic)
    }

    static func lines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }
}

enum M3UAdapter {
    static func load(text: String, url: URL) throws -> ChannelFile {
        var lines = ChannelFileIO.lines(text)
        if lines.last == "" { lines.removeLast() }
        guard let first = lines.first, first.hasPrefix("#EXTM3U") else {
            throw ChanSortError.invalidFile(L10n.text("error.invalidM3U"))
        }

        var header: [String] = []
        var pending: [String] = []
        var channels: [Channel] = []
        var sawChannel = false

        for line in lines {
            if !sawChannel && (line.hasPrefix("#EXTM3U") || line.hasPrefix("#PLAYLIST:") || line.hasPrefix("#EXTENC:")) {
                header.append(line)
                continue
            }
            pending.append(line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                sawChannel = true
                let extInf = pending.first(where: { $0.hasPrefix("#EXTINF:") })
                let parsed = parseExtInf(extInf ?? "")
                let display = splitProgramNumber(parsed.name, fallback: channels.count + 1)
                let source = URL(string: trimmed)?.host ?? trimmed
                channels.append(Channel(
                    originalIndex: channels.count,
                    programNumber: display.number,
                    name: display.name.isEmpty ? trimmed : display.name,
                    provider: parsed.attributes["group-title"] ?? "",
                    source: source,
                    serviceType: "IP",
                    rawLines: pending
                ))
                pending = []
            }
        }

        return ChannelFile(url: url, format: .m3u, channels: channels, headerLines: header, trailingLines: pending)
    }

    static func serialize(_ file: ChannelFile) -> String {
        var output = file.headerLines.isEmpty ? ["#EXTM3U"] : file.headerLines
        for channel in file.channels where !channel.isDeleted {
            var block = channel.rawLines
            if let index = block.firstIndex(where: { $0.hasPrefix("#EXTINF:") }) {
                var line = block[index]
                if let comma = commaOutsideQuotes(in: line) {
                    line = String(line[...comma]) + "\(channel.programNumber). \(channel.name)"
                }
                line = replacingAttribute("group-title", with: channel.provider, in: line)
                block[index] = line
            } else if let resource = block.lastIndex(where: {
                let value = $0.trimmingCharacters(in: .whitespaces)
                return !value.isEmpty && !value.hasPrefix("#")
            }) {
                block.insert("#EXTINF:-1 group-title=\"\(escapeAttribute(channel.provider))\",\(channel.programNumber). \(channel.name)", at: resource)
            }
            output.append(contentsOf: block)
        }
        output.append(contentsOf: file.trailingLines)
        return output.joined(separator: file.newline) + file.newline
    }

    private static func parseExtInf(_ line: String) -> (name: String, attributes: [String: String]) {
        guard let comma = commaOutsideQuotes(in: line) else { return ("", [:]) }
        let name = String(line[line.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
        let prefix = String(line[..<comma])
        var attrs: [String: String] = [:]
        let pattern = #"([A-Za-z0-9_-]+)\s*=\s*\"([^\"]*)\""#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(prefix.startIndex..., in: prefix)
            for match in regex.matches(in: prefix, range: range) where match.numberOfRanges == 3 {
                if let keyRange = Range(match.range(at: 1), in: prefix),
                   let valueRange = Range(match.range(at: 2), in: prefix) {
                    attrs[String(prefix[keyRange]).lowercased()] = String(prefix[valueRange])
                }
            }
        }
        return (name, attrs)
    }

    private static func splitProgramNumber(_ value: String, fallback: Int) -> (number: Int, name: String) {
        let pattern = #"^\s*(\d+)\.\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let numberRange = Range(match.range(at: 1), in: value),
              let nameRange = Range(match.range(at: 2), in: value) else {
            return (fallback, value)
        }
        return (Int(value[numberRange]) ?? fallback, String(value[nameRange]))
    }

    private static func commaOutsideQuotes(in value: String) -> String.Index? {
        var quoted = false
        for index in value.indices {
            if value[index] == "\"" { quoted.toggle() }
            if value[index] == "," && !quoted { return index }
        }
        return nil
    }

    private static func replacingAttribute(_ key: String, with value: String, in line: String) -> String {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "\\b\(escapedKey)\\s*=\\s*\"[^\"]*\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return regex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "\(key)=\"\(escapeAttribute(value))\"")
        }
        guard !value.isEmpty, let comma = commaOutsideQuotes(in: line) else { return line }
        return String(line[..<comma]) + " \(key)=\"\(escapeAttribute(value))\"" + String(line[comma...])
    }

    private static func escapeAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "'")
    }
}

enum Enigma2Adapter {
    static func load(text: String, url: URL) throws -> ChannelFile {
        let lines = ChannelFileIO.lines(text)
        var header: [String] = []
        var channels: [Channel] = []
        var pending: [String] = []

        func flush() {
            guard !pending.isEmpty else { return }
            guard let service = pending.first(where: { $0.hasPrefix("#SERVICE") }) else {
                header.append(contentsOf: pending)
                pending.removeAll()
                return
            }
            let description = pending.first(where: { $0.hasPrefix("#DESCRIPTION") })
                .map { String($0.dropFirst("#DESCRIPTION".count)).trimmingCharacters(in: .whitespaces) }
            let fallback = service.split(separator: ":").last.map(String.init) ?? L10n.format("store.channelFallback", channels.count + 1)
            channels.append(Channel(
                originalIndex: channels.count,
                programNumber: channels.count + 1,
                name: description?.isEmpty == false ? description! : fallback,
                source: service,
                serviceType: service.contains("4097:") ? "IP" : "DVB",
                rawLines: pending
            ))
            pending.removeAll()
        }

        for line in lines where !(line.isEmpty && line == lines.last) {
            if line.hasPrefix("#SERVICE") {
                flush()
                pending = [line]
            } else if pending.isEmpty {
                header.append(line)
            } else {
                pending.append(line)
            }
        }
        flush()
        guard !channels.isEmpty else {
            throw ChanSortError.invalidFile(L10n.text("error.emptyEnigma"))
        }
        return ChannelFile(url: url, format: .enigma2, channels: channels, headerLines: header)
    }

    static func serialize(_ file: ChannelFile) -> String {
        var output = file.headerLines
        for channel in file.channels where !channel.isDeleted {
            var block = channel.rawLines
            if let description = block.firstIndex(where: { $0.hasPrefix("#DESCRIPTION") }) {
                block[description] = "#DESCRIPTION \(channel.name)"
            } else {
                block.append("#DESCRIPTION \(channel.name)")
            }
            output.append(contentsOf: block)
        }
        return output.joined(separator: file.newline) + file.newline
    }
}

enum VDRAdapter {
    static func looksLikeVDR(_ text: String) -> Bool {
        ChannelFileIO.lines(text).contains { line in
            !line.hasPrefix(":") && line.split(separator: ":", omittingEmptySubsequences: false).count >= 12
        }
    }

    static func load(text: String, url: URL) throws -> ChannelFile {
        var channels: [Channel] = []
        var header: [String] = []
        for line in ChannelFileIO.lines(text) where !line.isEmpty {
            if line.hasPrefix(":") || line.hasPrefix("#") {
                header.append(line)
                continue
            }
            let fields = line.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 12 else { continue }
            let nameParts = fields[0].split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(nameParts.first ?? "")
            let provider = nameParts.count > 1 ? String(nameParts[1]) : ""
            channels.append(Channel(
                originalIndex: channels.count,
                programNumber: channels.count + 1,
                name: name,
                provider: provider,
                source: fields.count > 3 ? fields[3] : "",
                frequency: fields.count > 1 ? fields[1] : "",
                serviceType: "DVB",
                rawLines: [line],
                fields: fields
            ))
        }
        guard !channels.isEmpty else {
            throw ChanSortError.invalidFile(L10n.text("error.invalidVDR"))
        }
        return ChannelFile(url: url, format: .vdr, channels: channels, headerLines: header)
    }

    static func serialize(_ file: ChannelFile) -> String {
        var output = file.headerLines
        for channel in file.channels where !channel.isDeleted {
            var fields = channel.fields
            guard !fields.isEmpty else { continue }
            fields[0] = channel.provider.isEmpty ? channel.name : "\(channel.name);\(channel.provider)"
            output.append(fields.joined(separator: ":"))
        }
        return output.joined(separator: file.newline) + file.newline
    }
}

enum DelimitedAdapter {
    private static let numberNames = ["position", "program", "programnumber", "programnr", "prog", "number", "nummer", "platz"]
    private static let nameNames = ["name", "channel", "channelname", "sender", "sendername"]
    private static let providerNames = ["provider", "anbieter", "network"]
    private static let sourceNames = ["source", "quelle", "satellite", "satellit"]
    private static let frequencyNames = ["frequency", "frequenz", "freq"]

    static func load(text: String, url: URL) throws -> ChannelFile {
        let lines = ChannelFileIO.lines(text).filter { !$0.isEmpty }
        guard let first = lines.first else { throw ChanSortError.invalidFile(L10n.text("error.emptyFile")) }
        let delimiter: Character = url.pathExtension.lowercased() == "tsv" ? "\t" : detectDelimiter(first)
        let firstFields = parseRow(first, delimiter: delimiter)
        let normalized = firstFields.map(normalize)
        let hasHeader = normalized.contains(where: { nameNames.contains($0) })
        let columns = hasHeader ? firstFields : ["Position", "Name"]
        let dataLines = hasHeader ? Array(lines.dropFirst()) : lines
        let normalizedColumns = columns.map(normalize)
        let numberIndex = firstIndex(ofAny: numberNames, in: normalizedColumns)
        let nameIndex = firstIndex(ofAny: nameNames, in: normalizedColumns) ?? (columns.count > 1 ? 1 : 0)
        let providerIndex = firstIndex(ofAny: providerNames, in: normalizedColumns)
        let sourceIndex = firstIndex(ofAny: sourceNames, in: normalizedColumns)
        let frequencyIndex = firstIndex(ofAny: frequencyNames, in: normalizedColumns)

        var channels: [Channel] = []
        for row in dataLines {
            let fields = parseRow(row, delimiter: delimiter)
            guard nameIndex < fields.count else { continue }
            let fallback = channels.count + 1
            let number = numberIndex.flatMap { $0 < fields.count ? Int(fields[$0].trimmingCharacters(in: .whitespaces)) : nil } ?? fallback
            channels.append(Channel(
                originalIndex: channels.count,
                programNumber: number,
                name: fields[nameIndex],
                provider: value(providerIndex, in: fields),
                source: value(sourceIndex, in: fields),
                frequency: value(frequencyIndex, in: fields),
                serviceType: "List",
                fields: fields
            ))
        }
        guard !channels.isEmpty else { throw ChanSortError.invalidFile(L10n.text("error.emptyTable")) }
        return ChannelFile(url: url, format: .delimited, channels: channels, columnNames: columns, delimiter: delimiter)
    }

    static func serialize(_ file: ChannelFile) -> String {
        let normalizedColumns = file.columnNames.map(normalize)
        let numberIndex = firstIndex(ofAny: numberNames, in: normalizedColumns)
        let nameIndex = firstIndex(ofAny: nameNames, in: normalizedColumns) ?? (file.columnNames.count > 1 ? 1 : 0)
        let providerIndex = firstIndex(ofAny: providerNames, in: normalizedColumns)
        let sourceIndex = firstIndex(ofAny: sourceNames, in: normalizedColumns)
        let frequencyIndex = firstIndex(ofAny: frequencyNames, in: normalizedColumns)
        var output = [writeRow(file.columnNames, delimiter: file.delimiter)]
        for channel in file.channels where !channel.isDeleted {
            var fields = channel.fields
            while fields.count < file.columnNames.count { fields.append("") }
            set(numberIndex, value: String(channel.programNumber), in: &fields)
            set(nameIndex, value: channel.name, in: &fields)
            set(providerIndex, value: channel.provider, in: &fields)
            set(sourceIndex, value: channel.source, in: &fields)
            set(frequencyIndex, value: channel.frequency, in: &fields)
            output.append(writeRow(fields, delimiter: file.delimiter))
        }
        return output.joined(separator: file.newline) + file.newline
    }

    private static func detectDelimiter(_ line: String) -> Character {
        let candidates: [Character] = [";", "\t", ",", "|"]
        return candidates.max { a, b in line.filter { $0 == a }.count < line.filter { $0 == b }.count } ?? ";"
    }

    private static func parseRow(_ row: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var value = ""
        var quoted = false
        var index = row.startIndex
        while index < row.endIndex {
            let char = row[index]
            if char == "\"" {
                let next = row.index(after: index)
                if quoted && next < row.endIndex && row[next] == "\"" {
                    value.append("\"")
                    index = next
                } else {
                    quoted.toggle()
                }
            } else if char == delimiter && !quoted {
                result.append(value)
                value = ""
            } else {
                value.append(char)
            }
            index = row.index(after: index)
        }
        result.append(value)
        return result
    }

    private static func writeRow(_ fields: [String], delimiter: Character) -> String {
        fields.map { field in
            if field.contains(delimiter) || field.contains("\"") || field.contains("\n") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }.joined(separator: String(delimiter))
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func firstIndex(ofAny names: [String], in columns: [String]) -> Int? {
        columns.firstIndex(where: { names.contains($0) })
    }

    private static func value(_ index: Int?, in fields: [String]) -> String {
        guard let index, index < fields.count else { return "" }
        return fields[index]
    }

    private static func set(_ index: Int?, value: String, in fields: inout [String]) {
        guard let index, index < fields.count else { return }
        fields[index] = value
    }
}
