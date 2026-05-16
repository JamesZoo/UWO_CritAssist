import Foundation

enum BuildInfo {
    static let gitShortSHA: String = {
        if let injected = Bundle.main.object(forInfoDictionaryKey: "GitShortSHA") as? String, !injected.isEmpty {
            return injected
        }
        return "local"
    }()

    static let buildDate: String = {
        if let injected = Bundle.main.object(forInfoDictionaryKey: "BuildDate") as? String, !injected.isEmpty {
            return injected
        }
        return "n/a"
    }()

    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    static var fullVersionLine: String {
        "v\(marketingVersion) (\(bundleVersion)) · \(gitShortSHA)"
    }
}
