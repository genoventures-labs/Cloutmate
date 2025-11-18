import Foundation

enum DateParsing {
    static func parse(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let lowered = raw.lowercased()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        switch lowered {
        case "today":
            return todayStart
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: todayStart)
        default:
            break
        }
        if lowered.hasPrefix("next ") {
            let keyword = String(lowered.dropFirst(5))
            if let relative = nextWeekday(named: keyword, from: todayStart) {
                return relative
            }
        }
        let isoFormatter = ISO8601DateFormatter()
        let isoOptions: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate]
        ]
        for options in isoOptions {
            isoFormatter.formatOptions = options
            if let date = isoFormatter.date(from: raw) {
                return date
            }
        }
        if raw.contains("T"), raw.range(of: "[Zz+-]", options: .regularExpression) == nil {
            for options in isoOptions {
                isoFormatter.formatOptions = options
                if let date = isoFormatter.date(from: raw + "Z") {
                    return date
                }
            }
        }
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM/dd/yy",
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "MMMM d yyyy",
            "MMM d yyyy"
        ]
        for format in fallbackFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        let naturalFormatter = DateFormatter()
        naturalFormatter.locale = Locale.current
        naturalFormatter.dateStyle = .long
        naturalFormatter.timeStyle = .short
        if let date = naturalFormatter.date(from: raw) {
            return date
        }
        naturalFormatter.timeStyle = .none
        if let date = naturalFormatter.date(from: raw) {
            return date
        }
        return nil
    }
    
    private static func nextWeekday(named name: String, from date: Date) -> Date? {
        let calendar = Calendar.current
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let weekdaySymbols = calendar.weekdaySymbols.map { $0.lowercased() }
        let shortSymbols = calendar.shortWeekdaySymbols.map { $0.lowercased() }
        if let index = weekdaySymbols.firstIndex(where: { $0.hasPrefix(normalized) }) ?? shortSymbols.firstIndex(where: { $0.hasPrefix(normalized) }) {
            let targetWeekday = index + 1
            var components = DateComponents()
            components.weekday = targetWeekday
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .strict, direction: .forward)
        }
        return nil
    }
}
