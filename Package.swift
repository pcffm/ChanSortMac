// swift-tools-version: 5.9
// Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
// SPDX-License-Identifier: GPL-3.0-only

import PackageDescription

let package = Package(
    name: "ChanSortMac",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ChanSortMac", targets: ["ChanSortMac"])
    ],
    targets: [
        .executableTarget(
            name: "ChanSortMac",
            path: "Sources/ChanSortMac",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ChanSortMacTests",
            dependencies: ["ChanSortMac"],
            path: "Tests/ChanSortMacTests"
        )
    ]
)
