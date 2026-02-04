// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftScripting",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "SwiftScripting",
            targets: ["SwiftScripting"]
        ),
        .library(
            name: "SwiftScriptingAppleEvents",
            targets: ["SwiftScriptingAppleEvents"]
        ),
        .library(
            name: "SwiftScriptingIntents",
            targets: ["SwiftScriptingIntents"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // MARK: - Core Framework
        .target(
            name: "SwiftScripting",
            dependencies: ["SwiftScriptingMacrosClient"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Macro Implementation (compiler plugin)
        .macro(
            name: "SwiftScriptingMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Macro Declarations (re-exported by SwiftScripting)
        .target(
            name: "SwiftScriptingMacrosClient",
            dependencies: ["SwiftScriptingMacros"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Apple Event Interface (macOS only)
        .target(
            name: "SwiftScriptingAppleEvents",
            dependencies: ["SwiftScripting"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - App Intents Bridge
        .target(
            name: "SwiftScriptingIntents",
            dependencies: ["SwiftScripting"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Example Apps
        .executableTarget(
            name: "ScriptableTodos",
            dependencies: ["SwiftScripting", "SwiftScriptingAppleEvents"],
            path: "Examples/ScriptableTodos",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "ScriptableTextEditor",
            dependencies: ["SwiftScripting", "SwiftScriptingAppleEvents"],
            path: "Examples/ScriptableTextEditor",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Tests
        .testTarget(
            name: "SwiftScriptingTests",
            dependencies: [
                "SwiftScripting",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                "SwiftScriptingMacros",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SwiftScriptingAppleEventsTests",
            dependencies: ["SwiftScriptingAppleEvents"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SwiftScriptingIntentsTests",
            dependencies: ["SwiftScriptingIntents"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
