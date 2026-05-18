import Foundation
import Compression

// MARK: - Minimal zip reader

enum ZipReaderError: LocalizedError {
    case malformed
    case unsupportedCompression(UInt16)
    case decompressionFailed
    case truncated

    var errorDescription: String? {
        switch self {
        case .malformed:                  return "The file isn't a valid zip archive."
        case .unsupportedCompression(let m): return "Unsupported compression method (\(m))."
        case .decompressionFailed:        return "Failed to decompress one of the files."
        case .truncated:                  return "The zip archive is truncated."
        }
    }
}

enum ZipReader {
    struct Entry: Sendable {
        let name: String
        let data: Data
    }

    static func extract(zipURL: URL) throws -> [Entry] {
        let data = try Data(contentsOf: zipURL, options: .mappedIfSafe)
        return try extract(data: data)
    }

    static func extract(data: Data) throws -> [Entry] {
        guard let eocdOffset = findEndOfCentralDirectory(in: data) else {
            throw ZipReaderError.malformed
        }

        let entryCount: UInt16 = try data.readLE(at: eocdOffset + 10)
        let cdOffset: UInt32  = try data.readLE(at: eocdOffset + 16)

        var entries: [Entry] = []
        entries.reserveCapacity(Int(entryCount))

        var cursor = Int(cdOffset)
        for _ in 0..<entryCount {
            let signature: UInt32 = try data.readLE(at: cursor)
            guard signature == 0x02014b50 else { throw ZipReaderError.malformed }

            let compressionMethod: UInt16 = try data.readLE(at: cursor + 10)
            let compressedSize:    UInt32 = try data.readLE(at: cursor + 20)
            let uncompressedSize:  UInt32 = try data.readLE(at: cursor + 24)
            let fileNameLength:    UInt16 = try data.readLE(at: cursor + 28)
            let extraFieldLength:  UInt16 = try data.readLE(at: cursor + 30)
            let commentLength:     UInt16 = try data.readLE(at: cursor + 32)
            let localHeaderOffset: UInt32 = try data.readLE(at: cursor + 42)

            let nameStart = cursor + 46
            let nameEnd   = nameStart + Int(fileNameLength)
            guard nameEnd <= data.count else { throw ZipReaderError.truncated }
            let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? ""

            if !name.hasSuffix("/") {
                let entryData = try readLocalFile(
                    in: data,
                    at: Int(localHeaderOffset),
                    compressionMethod: compressionMethod,
                    compressedSize: Int(compressedSize),
                    uncompressedSize: Int(uncompressedSize)
                )
                entries.append(Entry(name: name, data: entryData))
            }

            cursor = nameEnd + Int(extraFieldLength) + Int(commentLength)
        }

        return entries
    }

    // MARK: - Internals

    private static func readLocalFile(
        in data: Data,
        at offset: Int,
        compressionMethod: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) throws -> Data {
        let signature: UInt32 = try data.readLE(at: offset)
        guard signature == 0x04034b50 else { throw ZipReaderError.malformed }

        let localFileNameLength: UInt16   = try data.readLE(at: offset + 26)
        let localExtraFieldLength: UInt16 = try data.readLE(at: offset + 28)
        let dataStart = offset + 30 + Int(localFileNameLength) + Int(localExtraFieldLength)
        let dataEnd = dataStart + compressedSize
        guard dataEnd <= data.count else { throw ZipReaderError.truncated }

        let payload = data.subdata(in: dataStart..<dataEnd)

        switch compressionMethod {
        case 0:
            return payload
        case 8:
            return try inflateRawDeflate(payload, expectedSize: uncompressedSize)
        default:
            throw ZipReaderError.unsupportedCompression(compressionMethod)
        }
    }

    private static func inflateRawDeflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
        defer { dst.deallocate() }

        let written = data.withUnsafeBytes { rawBuf -> Int in
            guard let src = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                dst, expectedSize,
                src, data.count,
                nil, COMPRESSION_ZLIB
            )
        }

        guard written > 0 else { throw ZipReaderError.decompressionFailed }
        return Data(bytes: dst, count: written)
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        let minSize = 22
        guard data.count >= minSize else { return nil }
        let maxBack = min(data.count, 65557)
        let lowerBound = data.count - maxBack
        var i = data.count - minSize
        while i >= lowerBound {
            if data[i]   == 0x50,
               data[i+1] == 0x4b,
               data[i+2] == 0x05,
               data[i+3] == 0x06 {
                return i
            }
            i -= 1
        }
        return nil
    }
}

// MARK: - Little-endian read helper

private extension Data {
    func readLE<T: FixedWidthInteger>(at offset: Int) throws -> T {
        let size = MemoryLayout<T>.size
        guard offset >= 0, offset + size <= count else { throw ZipReaderError.truncated }
        return withUnsafeBytes { buf in
            buf.loadUnaligned(fromByteOffset: offset, as: T.self).littleEndian
        }
    }
}
