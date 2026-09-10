
import Foundation

public enum RecommendationEngine {

    public static func bestDailyWindow(
        hours: [(weather: HourlyWeather, result: MowabilityResult, isDaylight: Bool)],
        lawn: LawnProfile,
        calendar: Calendar = .current,
        minimumAcceptableScore: Int = 60,
        bufferMinutes: Int = 15
    ) -> DailyRecommendation {
        guard !hours.isEmpty else {
            return DailyRecommendation(bestWindow: nil, dailyScore: nil, message: "No forecast data.")
        }

        let requiredMinutes = lawn.mowingDurationMinutes + bufferMinutes
        let sorted = hours.sorted { $0.weather.date < $1.weather.date }

        func isAvailable(_ date: Date) -> Bool {
            let weekday = calendar.component(.weekday, from: date)
            let hour = calendar.component(.hour, from: date)
            // Monday-Friday = 2...6 in Gregorian Calendar
            if (2...6).contains(weekday), let start = lawn.preferredWeekdayStartHour {
                return hour >= start
            }
            return true
        }

        var best: MowingWindow?
        var startIndex: Int? = nil

        func closeWindow(at endExclusive: Int) {
            guard let s = startIndex, endExclusive > s else { startIndex = nil; return }
            let slice = Array(sorted[s..<endExclusive])
            guard let first = slice.first, let last = slice.last else { startIndex = nil; return }

            let duration = Int(last.weather.date.timeIntervalSince(first.weather.date) / 60.0) + 60
            guard duration >= requiredMinutes else { startIndex = nil; return }

            let score = slice.map(\.result.score).min() ?? 0
            let candidate = MowingWindow(
                start: first.weather.date,
                end: last.weather.date.addingTimeInterval(3600),
                score: score,
                safetyState: .normal
            )

            if best == nil || candidate.score > best!.score ||
                (candidate.score == best!.score &&
                 candidate.end.timeIntervalSince(candidate.start) > best!.end.timeIntervalSince(best!.start)) {
                best = candidate
            }
            startIndex = nil
        }

        for (i, item) in sorted.enumerated() {
            let usable = item.isDaylight &&
                         isAvailable(item.weather.date) &&
                         item.result.safetyState != .stop &&
                         item.result.score >= minimumAcceptableScore

            if usable {
                if startIndex == nil { startIndex = i }
            } else {
                closeWindow(at: i)
            }
        }
        closeWindow(at: sorted.count)

        if let best {
            return DailyRecommendation(
                bestWindow: best,
                dailyScore: best.score,
                message: "Best conditions window found."
            )
        }

        return DailyRecommendation(
            bestWindow: nil,
            dailyScore: nil,
            message: "No suitable conditions window during your available time."
        )
    }
}
