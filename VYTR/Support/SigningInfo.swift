import Foundation

/// Reads when this build's signature runs out.
///
/// A free Apple ID signs for seven days. Rather than asking the user to
/// remember when they last ran Sideloadly, the app reads the expiry date
/// out of the provisioning profile it was signed with and says so.
///
/// The profile is added by Sideloadly at signing time, not by the cloud
/// build, so everything here copes with it being absent.
enum SigningInfo {

    static let version: String = {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }()

    /// When the current signature stops working, if it can be determined.
    static let expiryDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url)
        else { return nil }

        // The file is a signed container wrapping a plain plist. Rather
        // than decoding the signature, locate the plist inside it.
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8))
        else { return nil }

        let plistData = data[start.lowerBound..<end.upperBound]

        guard let plist = try? PropertyListSerialization.propertyList(
            from: plistData, options: [], format: nil
        ) as? [String: Any] else { return nil }

        return plist["ExpirationDate"] as? Date
    }()

    /// Whole days left, floored, so "0 days" means it goes today.
    static var daysRemaining: Int? {
        guard let expiryDate else { return nil }
        let days = Calendar.current.dateComponents(
            [.day], from: .now, to: expiryDate
        ).day
        return days.map { max($0, 0) }
    }

    /// A sentence for the settings screen. Deliberately specific: "expires
    /// Thursday" is actionable, "expires soon" is not.
    static var expiryText: String {
        guard let expiryDate, let days = daysRemaining else {
            return "This build is not signed yet, or its profile could not be read."
        }

        let date = expiryDate.formatted(.dateTime.weekday(.wide).day().month(.wide))

        switch days {
        case 0:  return "Signature runs out today (\(date)). Re-sign with Sideloadly to keep opening the app."
        case 1:  return "Signature runs out tomorrow (\(date))."
        default: return "Signature runs out in \(days) days, on \(date)."
        }
    }

    /// Under three days left is worth drawing attention to.
    static var isExpiringSoon: Bool {
        guard let days = daysRemaining else { return false }
        return days <= 2
    }
}
