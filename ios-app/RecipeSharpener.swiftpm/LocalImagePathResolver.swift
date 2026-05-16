import Foundation

/// Re-roots a saved file URL to the current app's Documents directory so
/// images saved under one launch's container path are still found after a
/// subsequent launch where the container UUID has changed.
///
/// iOS app sandbox paths look like
/// `/var/mobile/Containers/Data/Application/<UUID>/Documents/...`. The UUID
/// part is reassigned on reinstall, restore from backup, and (in some
/// development sandboxes such as Swift Playgrounds) more frequently. The
/// `/Documents/` segment is stable across UUID changes, so we find it in
/// the saved path and re-attach the suffix to the current Documents URL.
///
/// Remote URLs (https://...) and any URL that doesn't contain `/Documents/`
/// pass through unchanged.
enum LocalImagePathResolver {
    static func resolved(_ url: URL?) -> URL? {
        guard let url else { return nil }
        guard url.isFileURL else { return url }
        let path = url.path
        guard let docsRange = path.range(of: "/Documents/") else { return url }
        let suffix = String(path[docsRange.upperBound...])
        guard let docsDir = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return url }
        return docsDir.appending(path: suffix)
    }
}
