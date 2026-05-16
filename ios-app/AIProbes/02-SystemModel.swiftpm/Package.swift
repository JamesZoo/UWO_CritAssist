// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Probe02SystemModel",
    platforms: [.iOS("26.0")],
    products: [
        .iOSApplication(
            name: "Probe02SystemModel",
            targets: ["AppModule"],
            bundleIdentifier: "com.recipesharpener.probe02",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            accentColor: .presetColor(.purple),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait, .landscapeRight, .landscapeLeft
            ]
        )
    ],
    targets: [
        .executableTarget(name: "AppModule", path: ".")
    ]
)
