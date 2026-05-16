// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "VisionProbe03",
    platforms: [.iOS("26.0")],
    products: [
        .iOSApplication(
            name: "VisionProbe03",
            targets: ["AppModule"],
            bundleIdentifier: "com.recipesharpener.vision.probe03",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            accentColor: .presetColor(.teal),
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
