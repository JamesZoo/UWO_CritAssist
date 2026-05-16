// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "RecipeSharpener",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .iOSApplication(
            name: "RecipeSharpener",
            targets: ["AppModule"],
            bundleIdentifier: "com.recipesharpener.app",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .bowlOfRice),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            exclude: [
                "Tests",
                "Package.swift",
                "README.md"
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .testTarget(
            name: "AppModuleTests",
            dependencies: ["AppModule"],
            path: "Tests/AppModuleTests"
        )
    ]
)
