// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import XCTest
@testable import ChanSortMac

final class FormatAdapterTests: XCTestCase {
    func testM3URoundTripPreservesResourceAndUpdatesOrder() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1 group-title="News",2. Zweites
        http://example.test/2
        #EXTINF:-1 group-title="Public",1. Erstes
        http://example.test/1

        """
        let url = URL(fileURLWithPath: "/tmp/list.m3u")
        var file = try M3UAdapter.load(text: text, url: url)
        XCTAssertEqual(file.channels.count, 2)
        XCTAssertEqual(file.channels[0].name, "Zweites")
        XCTAssertEqual(file.channels[0].provider, "News")
        file.channels.swapAt(0, 1)
        file.channels[0].programNumber = 1
        file.channels[1].programNumber = 2
        let saved = M3UAdapter.serialize(file)
        XCTAssertLessThan(saved.range(of: "http://example.test/1")!.lowerBound,
                          saved.range(of: "http://example.test/2")!.lowerBound)
        XCTAssertTrue(saved.contains("1. Erstes"))
    }

    func testCSVHandlesQuotedDelimiter() throws {
        let text = "Position;Name;Anbieter\n1;\"News; HD\";ARD\n"
        let url = URL(fileURLWithPath: "/tmp/list.csv")
        var file = try DelimitedAdapter.load(text: text, url: url)
        XCTAssertEqual(file.channels[0].name, "News; HD")
        file.channels[0].name = "News \"Plus\""
        let saved = DelimitedAdapter.serialize(file)
        XCTAssertTrue(saved.contains("\"News \"\"Plus\"\"\""))
    }

    func testEnigma2RenamesDescriptionWithoutChangingService() throws {
        let text = "#NAME Favoriten\n#SERVICE 1:0:1:AAAA:BBBB:CCCC:0:0:0:0:\n#DESCRIPTION Alt\n"
        let url = URL(fileURLWithPath: "/tmp/userbouquet.test.tv")
        var file = try Enigma2Adapter.load(text: text, url: url)
        file.channels[0].name = "Neu"
        let saved = Enigma2Adapter.serialize(file)
        XCTAssertTrue(saved.contains("#SERVICE 1:0:1:AAAA:BBBB:CCCC:0:0:0:0:"))
        XCTAssertTrue(saved.contains("#DESCRIPTION Neu"))
    }

    func testVDRPreservesTechnicalFields() throws {
        let text = "Das Erste;ARD:11836:HC34M2O0S1:S19.2E:27500:101:102=deu:104:0:28106:1:1101:0\n"
        let url = URL(fileURLWithPath: "/tmp/channels.conf")
        var file = try VDRAdapter.load(text: text, url: url)
        file.channels[0].name = "Das Erste HD"
        let saved = VDRAdapter.serialize(file)
        XCTAssertTrue(saved.hasPrefix("Das Erste HD;ARD:11836:HC34M2O0S1:S19.2E"))
        XCTAssertTrue(saved.contains(":28106:1:1101:0"))
    }

    func testOriginalChanSortFixturesWhenAvailable() throws {
        guard let root = ProcessInfo.processInfo.environment["CHANSORT_FIXTURE_ROOT"] else {
            throw XCTSkip("Original-ChanSort-Testdaten sind nicht Teil dieses Pakets.")
        }
        let fixtures = [
            "Test.Loader.M3u/TestFiles/example.m3u",
            "Test.Loader.M3u/TestFiles/extinftags.m3u",
            "Test.Loader.VDR/TestFiles/channels.conf",
            "Test.Loader.Enigma2/TestFiles/userbouquet.horst.mix"
        ]
        for relative in fixtures {
            let url = URL(fileURLWithPath: root).appendingPathComponent(relative)
            let file = try ChannelFileIO.load(from: url)
            XCTAssertFalse(file.channels.isEmpty, "Keine Sender in \(relative)")

            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)
            try ChannelFileIO.save(file, to: temporary)
            let reloaded = try ChannelFileIO.load(from: temporary)
            XCTAssertEqual(reloaded.channels.count, file.channels.filter { !$0.isDeleted }.count)
            try? FileManager.default.removeItem(at: temporary)
        }
    }

    func testProprietaryLoaderFixturesWhenAvailable() throws {
        guard let root = ProcessInfo.processInfo.environment["CHANSORT_FIXTURE_ROOT"] else {
            throw XCTSkip("Original-ChanSort-Testdaten sind nicht Teil dieses Pakets.")
        }
        let fixtures = [
            "Test.Loader.Samsung/Zip/TestFiles/Channel_list_T-KTSUDEUC-1007.3.zip",
            "Test.Loader.Sony/TestFiles/android_sdb-sat.xml",
            "Test.Loader.Hisense/ServicelistDb/TestFiles/servicelist_2021.db",
            "Test.Loader.Panasonic/TestFiles/svl-sat.db",
            "Test.Loader.Toshiba/TestFiles/Toshiba-SL863G.zip"
        ]
        for relative in fixtures {
            let file = try ChannelFileIO.load(from: URL(fileURLWithPath: root).appendingPathComponent(relative))
            XCTAssertNotNil(file.device, "Kein Geräteloader für \(relative)")
            XCTAssertFalse(file.channels.isEmpty, "Keine Sender in \(relative)")
            XCTAssertFalse(file.lists.isEmpty, "Keine Teillisten in \(relative)")
        }
    }
}
