import Foundation

/// A very small zip reader and writer, limited to stored (uncompressed)
/// entries.
///
/// Why hand-written: a backup has to carry the meal photos, so it cannot
/// be a single JSON file, and a real zip is the one container shape that
/// the Files app, macOS and Windows all open with nothing installed.
/// iOS can *create* a zip through NSFileCoordinator, but offers no API to
/// read one back, and a third-party library is out of scope here.
///
/// Why stored rather than deflated: the payload is JPEG data, which does
/// not compress, so skipping compression costs almost nothing and removes
/// the need for an inflate implementation. The CRC-32 that zip keeps for
/// every entry is still written and checked, which is what turns a
/// truncated or damaged file into a clear error instead of nonsense.
enum ZipArchive {

    struct Entry {
        let name: String
        let data: Data
    }

    enum ZipError: LocalizedError {
        case notAZipFile
        case truncated
        case unsupportedCompression(String)
        case checksumMismatch(String)

        var errorDescription: String? {
            switch self {
            case .notAZipFile:
                return "This file is not a VYTR backup."
            case .truncated:
                return "This backup file is incomplete. The copy or download may have stopped early."
            case .unsupportedCompression(let name):
                return "This backup was packed in a way VYTR cannot read (\(name))."
            case .checksumMismatch(let name):
                return "This backup file is damaged: \(name) failed its checksum."
            }
        }
    }

    // MARK: - Writing

    static func write(_ entries: [Entry], modified: Date = .now) -> Data {
        var payload = Data()
        var central = Data()
        let (dosTime, dosDate) = dosTimestamp(from: modified)

        for entry in entries {
            let name = Array(entry.name.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let localOffset = UInt32(payload.count)

            payload.appendUInt32(0x04034b50)   // local file header
            payload.appendUInt16(20)           // version needed
            payload.appendUInt16(0)            // flags
            payload.appendUInt16(0)            // method: stored
            payload.appendUInt16(dosTime)
            payload.appendUInt16(dosDate)
            payload.appendUInt32(crc)
            payload.appendUInt32(size)         // compressed size
            payload.appendUInt32(size)         // uncompressed size
            payload.appendUInt16(UInt16(name.count))
            payload.appendUInt16(0)            // extra length
            payload.append(contentsOf: name)
            payload.append(entry.data)

            central.appendUInt32(0x02014b50)   // central directory header
            central.appendUInt16(20)           // version made by
            central.appendUInt16(20)           // version needed
            central.appendUInt16(0)            // flags
            central.appendUInt16(0)            // method: stored
            central.appendUInt16(dosTime)
            central.appendUInt16(dosDate)
            central.appendUInt32(crc)
            central.appendUInt32(size)
            central.appendUInt32(size)
            central.appendUInt16(UInt16(name.count))
            central.appendUInt16(0)            // extra length
            central.appendUInt16(0)            // comment length
            central.appendUInt16(0)            // disk number
            central.appendUInt16(0)            // internal attributes
            central.appendUInt32(0)            // external attributes
            central.appendUInt32(localOffset)
            central.append(contentsOf: name)
        }

        let centralOffset = UInt32(payload.count)
        var out = payload
        out.append(central)
        out.appendUInt32(0x06054b50)           // end of central directory
        out.appendUInt16(0)                    // this disk
        out.appendUInt16(0)                    // disk holding the directory
        out.appendUInt16(UInt16(entries.count))
        out.appendUInt16(UInt16(entries.count))
        out.appendUInt32(UInt32(central.count))
        out.appendUInt32(centralOffset)
        out.appendUInt16(0)                    // comment length
        return out
    }

    // MARK: - Reading

    /// Entry name to contents. Every entry is checked against the CRC-32
    /// recorded for it, so a file that survives this has not been quietly
    /// damaged on the way in.
    static func read(_ data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { throw ZipError.truncated }
        guard let eocd = findEndOfCentralDirectory(bytes) else {
            // Every zip ends with this record. Without it the file is
            // either something else entirely or was cut short.
            throw bytes.starts(with: [0x50, 0x4b]) ? ZipError.truncated : ZipError.notAZipFile
        }

        let count = Int(bytes.u16(eocd + 10))
        var p = Int(bytes.u32(eocd + 16))
        var result: [String: Data] = [:]

        for _ in 0..<count {
            guard p >= 0, p + 46 <= bytes.count, bytes.u32(p) == 0x02014b50 else {
                throw ZipError.truncated
            }
            let method = bytes.u16(p + 10)
            let crc = bytes.u32(p + 16)
            let size = Int(bytes.u32(p + 24))
            let nameLength = Int(bytes.u16(p + 28))
            let extraLength = Int(bytes.u16(p + 30))
            let commentLength = Int(bytes.u16(p + 32))
            let localOffset = Int(bytes.u32(p + 42))

            guard p + 46 + nameLength <= bytes.count else { throw ZipError.truncated }
            let name = String(decoding: bytes[(p + 46)..<(p + 46 + nameLength)], as: UTF8.self)

            guard method == 0 else { throw ZipError.unsupportedCompression(name) }
            guard localOffset >= 0,
                  localOffset + 30 <= bytes.count,
                  bytes.u32(localOffset) == 0x04034b50
            else {
                throw ZipError.truncated
            }

            let localNameLength = Int(bytes.u16(localOffset + 26))
            let localExtraLength = Int(bytes.u16(localOffset + 28))
            let start = localOffset + 30 + localNameLength + localExtraLength
            guard size >= 0, start + size <= bytes.count else { throw ZipError.truncated }

            let contents = Data(bytes[start..<(start + size)])
            guard crc32(contents) == crc else { throw ZipError.checksumMismatch(name) }
            result[name] = contents

            p += 46 + nameLength + extraLength + commentLength
        }

        return result
    }

    private static func findEndOfCentralDirectory(_ bytes: [UInt8]) -> Int? {
        // The record is 22 bytes plus a comment of at most 65535, so it
        // cannot begin earlier than this.
        let lowest = max(0, bytes.count - 22 - 65_535)
        var i = bytes.count - 22
        while i >= lowest {
            if bytes.u32(i) == 0x06054b50 { return i }
            i -= 1
        }
        return nil
    }

    // MARK: - CRC-32

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) == 1 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for byte in data {
            c = crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFFFFFF
    }

    private static func dosTimestamp(from date: Date) -> (time: UInt16, date: UInt16) {
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let year = max(1980, parts.year ?? 1980) - 1980
        let time = UInt16((parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | ((parts.second ?? 0) / 2))
        let day = UInt16(year << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1))
        return (time, day)
    }
}

// MARK: - Little-endian helpers

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}

private extension Array where Element == UInt8 {
    func u16(_ i: Int) -> UInt16 {
        guard i >= 0, i + 1 < count else { return 0 }
        return UInt16(self[i]) | UInt16(self[i + 1]) << 8
    }

    func u32(_ i: Int) -> UInt32 {
        guard i >= 0, i + 3 < count else { return 0 }
        return UInt32(self[i])
            | UInt32(self[i + 1]) << 8
            | UInt32(self[i + 2]) << 16
            | UInt32(self[i + 3]) << 24
    }
}
