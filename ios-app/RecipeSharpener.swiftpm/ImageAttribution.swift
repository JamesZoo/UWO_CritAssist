import Foundation

struct ImageAttribution: Codable, Sendable, Hashable {
    var sourceName: String
    var pageURL: URL?
    var author: String?
    var licenseName: String?
    var licenseURL: URL?

    init(
        sourceName: String,
        pageURL: URL? = nil,
        author: String? = nil,
        licenseName: String? = nil,
        licenseURL: URL? = nil
    ) {
        self.sourceName = sourceName
        self.pageURL = pageURL
        self.author = author
        self.licenseName = licenseName
        self.licenseURL = licenseURL
    }
}
