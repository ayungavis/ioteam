import Foundation

/// Shared JSON encoder configured for the DoseLatch backend (encodes dates as ISO8601 with fractional seconds)
public enum DoseLatchEncoder {
    nonisolated(unsafe) private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return f
    }()

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .formatted(dateFormatter)
        return e
    }()

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}
