
import Foundation

public enum SafetyState: String, Codable, Equatable {
    case normal, caution, stop
}

public enum GrassFamily: String, Codable, Equatable {
    case coolSeason, warmSeason, unknown
}

public enum MowabilityRating: String, Codable, Equatable {
    case excellent, veryGood, good, fair, poor, veryPoor, stop
}

public struct LawnProfile: Codable, Equatable {
    public var shadeLevel: Int          // 1 = heavy shade, 5 = full sun
    public var grassFamily: GrassFamily
    public var mowingDurationMinutes: Int
    public var preferredWeekdayStartHour: Int?
    public var dryingBias: Double       // clamp ~0.60...1.40
    public var growthBias: Double

    public init(
        shadeLevel: Int = 3,
        grassFamily: GrassFamily = .unknown,
        mowingDurationMinutes: Int = 60,
        preferredWeekdayStartHour: Int? = nil,
        dryingBias: Double = 1.0,
        growthBias: Double = 1.0
    ) {
        self.shadeLevel = min(5, max(1, shadeLevel))
        self.grassFamily = grassFamily
        self.mowingDurationMinutes = max(15, mowingDurationMinutes)
        self.preferredWeekdayStartHour = preferredWeekdayStartHour
        self.dryingBias = min(1.40, max(0.60, dryingBias))
        self.growthBias = min(1.40, max(0.60, growthBias))
    }
}

public struct HourlyWeather: Codable, Equatable {
    public var date: Date
    public var temperatureF: Double
    public var relativeHumidity: Double
    public var dewPointF: Double?
    public var sustainedWindMPH: Double
    public var gustMPH: Double?
    public var precipitationProbability: Double // 0...100
    public var precipitationInches: Double
    public var cloudCover: Double              // 0...100
    public var isThunderstorm: Bool
    public var severeThunderstormWarning: Bool
    public var tornadoWarning: Bool
    public var likelyFrost: Bool
    public var likelyFrozenTurf: Bool
    public var snowOrIcePresent: Bool

    public init(
        date: Date,
        temperatureF: Double,
        relativeHumidity: Double,
        dewPointF: Double? = nil,
        sustainedWindMPH: Double = 0,
        gustMPH: Double? = nil,
        precipitationProbability: Double = 0,
        precipitationInches: Double = 0,
        cloudCover: Double = 0,
        isThunderstorm: Bool = false,
        severeThunderstormWarning: Bool = false,
        tornadoWarning: Bool = false,
        likelyFrost: Bool = false,
        likelyFrozenTurf: Bool = false,
        snowOrIcePresent: Bool = false
    ) {
        self.date = date
        self.temperatureF = temperatureF
        self.relativeHumidity = min(100, max(0, relativeHumidity))
        self.dewPointF = dewPointF
        self.sustainedWindMPH = max(0, sustainedWindMPH)
        self.gustMPH = gustMPH.map { max(0, $0) }
        self.precipitationProbability = min(100, max(0, precipitationProbability))
        self.precipitationInches = max(0, precipitationInches)
        self.cloudCover = min(100, max(0, cloudCover))
        self.isThunderstorm = isThunderstorm
        self.severeThunderstormWarning = severeThunderstormWarning
        self.tornadoWarning = tornadoWarning
        self.likelyFrost = likelyFrost
        self.likelyFrozenTurf = likelyFrozenTurf
        self.snowOrIcePresent = snowOrIcePresent
    }
}

public struct MoistureState: Codable, Equatable {
    public var rainDebt: Double      // may exceed 100
    public var dewMoisture: Double   // 0...100

    public init(rainDebt: Double = 0, dewMoisture: Double = 0) {
        self.rainDebt = max(0, rainDebt)
        self.dewMoisture = min(100, max(0, dewMoisture))
    }

    public var visibleSurfaceMoisture: Double {
        min(100, max(rainDebt, dewMoisture))
    }
}

public struct PenaltyBreakdown: Codable, Equatable {
    public var moisture: Double = 0
    public var wind: Double = 0
    public var gust: Double = 0
    public var heatAndTurf: Double = 0
    public var cold: Double = 0
    public var precipitationRisk: Double = 0

    public var total: Double {
        moisture + wind + gust + heatAndTurf + cold + precipitationRisk
    }
}

public struct MowabilityResult: Codable, Equatable {
    public var score: Int
    public var rating: MowabilityRating
    public var safetyState: SafetyState
    public var reasons: [String]
    public var penalties: PenaltyBreakdown
    public var surfaceMoisture: Double
}

public struct MowingWindow: Codable, Equatable {
    public var start: Date
    public var end: Date
    public var score: Int
    public var safetyState: SafetyState
}

public struct DailyRecommendation: Codable, Equatable {
    public var bestWindow: MowingWindow?
    public var dailyScore: Int?
    public var message: String
}
