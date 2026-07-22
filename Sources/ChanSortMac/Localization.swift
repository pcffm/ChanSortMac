// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum L10n {
    private static let resourceBundle: Bundle = {
        if let url = Bundle.main.url(forResource: "ChanSortMac_ChanSortMac", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }()

    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: resourceBundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
