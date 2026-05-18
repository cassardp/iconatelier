import Foundation

enum ZipWriter {
    /// Zips a directory using `NSFileCoordinator` with `.forUploading`, which
    /// natively produces a zip archive. The result is copied out of the
    /// coordinator's temporary location into a stable URL.
    static func zip(directory source: URL, named filename: String) throws -> URL {
        let fm = FileManager.default
        let destination = fm.temporaryDirectory.appendingPathComponent(filename)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var produced: Error?

        coordinator.coordinate(
            readingItemAt: source,
            options: [.forUploading],
            error: &coordError
        ) { tempZipURL in
            do {
                try fm.copyItem(at: tempZipURL, to: destination)
            } catch {
                produced = error
            }
        }

        if let coordError { throw coordError }
        if let produced { throw produced }
        return destination
    }
}
