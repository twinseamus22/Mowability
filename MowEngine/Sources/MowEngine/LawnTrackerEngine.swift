import Foundation
public enum LawnLengthStatus: String, Codable, Equatable {
    case notYet, gettingThere, gettingLong, likelyLong
}
public struct LawnTrackerState: Codable, Equatable {
    public var lastMowed: Date?
    public var growthProgress: Double
    public init(lastMowed: Date? = nil, growthProgress: Double = 0) {
        self.lastMowed = lastMowed
        self.growthProgress = max(0, growthProgress)
    }
    public var status: LawnLengthStatus {
        switch growthProgress {
        case ..<0.35: return .notYet
        case ..<0.65: return .gettingThere
        case ..<0.95: return .gettingLong
        default: return .likelyLong
        }
    }
}
public enum LawnTrackerEngine {
    public static func updateGrowth(current: LawnTrackerState, dailyGrowthUnits: Double,
                                    lawn: LawnProfile) -> LawnTrackerState {
        var n=current
        n.growthProgress += max(0,dailyGrowthUnits) * lawn.growthBias
        return n
    }
    public static func recordMow(at date: Date, current: LawnTrackerState) -> LawnTrackerState {
        .init(lastMowed: date, growthProgress: 0)
    }
}
