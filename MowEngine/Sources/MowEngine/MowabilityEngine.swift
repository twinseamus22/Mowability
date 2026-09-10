
import Foundation

public enum MowabilityEngine {

    public static func evaluate(
        weather: HourlyWeather,
        lawn: LawnProfile,
        moisture: MoistureState,
        turfStressSeverity: Double
    ) -> MowabilityResult {
        let safety = safetyState(weather: weather)
        if safety == .stop {
            return MowabilityResult(
                score: 0,
                rating: .stop,
                safetyState: .stop,
                reasons: safetyReasons(weather),
                penalties: PenaltyBreakdown(),
                surfaceMoisture: moisture.visibleSurfaceMoisture
            )
        }

        var penalties = PenaltyBreakdown()
        var reasons: [String] = []

        let surface = moisture.visibleSurfaceMoisture
        penalties.moisture = moisturePenalty(surface)
        if penalties.moisture > 0 { reasons.append(moistureReason(surface)) }

        penalties.wind = windPenalty(weather.sustainedWindMPH)
        if penalties.wind > 0 { reasons.append("Aggressive sustained wind") }

        penalties.gust = gustPenalty(weather.gustMPH ?? 0)
        if penalties.gust > 0 { reasons.append("Strong gusts") }

        let heat = heatPenalty(weather)
        let turf = turfStressPenalty(turfStressSeverity)
        penalties.heatAndTurf = combineRelatedPenalties(heat, turf)
        if heat > 0 { reasons.append("Heat stress") }
        if turf > 0 { reasons.append("Turf stress") }

        penalties.cold = coldPenalty(weather)
        if penalties.cold > 0 { reasons.append("Cold/frost conditions") }

        penalties.precipitationRisk = precipitationRiskPenalty(
            probability: weather.precipitationProbability,
            surfaceMoisturePenalty: penalties.moisture
        )
        if penalties.precipitationRisk > 0 { reasons.append("Rain risk") }

        let raw = 100.0 - penalties.total
        let score = max(10, min(100, Int(raw.rounded())))
        let rating = ratingForScore(score)

        return MowabilityResult(
            score: score,
            rating: rating,
            safetyState: safety == .caution ? .caution : .normal,
            reasons: reasons,
            penalties: penalties,
            surfaceMoisture: surface
        )
    }

    public static func safetyState(weather: HourlyWeather) -> SafetyState {
        if weather.tornadoWarning || weather.severeThunderstormWarning || weather.isThunderstorm {
            return .stop
        }
        if weather.snowOrIcePresent { return .stop }
        if weather.temperatureF >= 115 { return .caution }
        if (weather.gustMPH ?? 0) >= 55 || weather.sustainedWindMPH >= 39 { return .caution }
        return .normal
    }

    private static func safetyReasons(_ weather: HourlyWeather) -> [String] {
        var reasons: [String] = []
        if weather.tornadoWarning { reasons.append("Tornado warning") }
        if weather.severeThunderstormWarning { reasons.append("Severe thunderstorm warning") }
        if weather.isThunderstorm { reasons.append("Thunderstorm/lightning") }
        if weather.snowOrIcePresent { reasons.append("Snow or ice present") }
        return reasons
    }

    public static func moisturePenalty(_ moisture: Double) -> Double {
        switch moisture {
        case ..<15: return 0
        case ..<30: return 3
        case ..<45: return 8
        case ..<60: return 18
        case ..<75: return 35
        case ..<90: return 50
        default: return 65
        }
    }

    private static func moistureReason(_ moisture: Double) -> String {
        switch moisture {
        case ..<30: return "Slight surface moisture"
        case ..<45: return "Slightly damp turf"
        case ..<60: return "Damp turf"
        case ..<75: return "Wet turf"
        case ..<90: return "Very wet turf"
        default: return "Saturated turf"
        }
    }

    public static func windPenalty(_ mph: Double) -> Double {
        if mph < 25 { return 0 }
        if mph <= 38 {
            // 25 -> 5, 28 -> 10, 31 -> 15, 34 -> 20, 38 -> 30
            let points = [(25.0,5.0),(28,10),(31,15),(34,20),(38,30)]
            return interpolate(points, mph)
        }
        if mph <= 55 {
            return interpolate([(39.0,40.0),(45,56),(55,73)], mph)
        }
        return 80
    }

    public static func gustPenalty(_ mph: Double) -> Double {
        switch mph {
        case ..<35: return 0
        case ..<45: return 8
        case ..<55: return 18
        default: return 30
        }
    }

    public static func heatPenalty(_ w: HourlyWeather) -> Double {
        let t = w.temperatureF
        let rh = w.relativeHumidity

        if t < 85 { return 0 }
        let humidityBoost = max(0, rh - 40) * 0.18
        switch t {
        case ..<90: return 5 + humidityBoost * 0.4
        case ..<95: return 10 + humidityBoost * 0.6
        case ..<100: return 18 + humidityBoost * 0.8
        case ..<105: return 28 + humidityBoost
        case ..<110: return 38 + humidityBoost * 1.1
        default: return 50 + humidityBoost * 1.2
        }
    }

    public static func turfStressPenalty(_ severity: Double) -> Double {
        let s = min(100, max(0, severity))
        switch s {
        case ..<21: return 0
        case ..<41: return 5
        case ..<61: return 12
        case ..<81: return 25
        default: return 40
        }
    }

    public static func combineRelatedPenalties(_ a: Double, _ b: Double) -> Double {
        max(a, b) + 0.5 * min(a, b)
    }

    public static func coldPenalty(_ w: HourlyWeather) -> Double {
        if w.likelyFrozenTurf { return 60 }
        if w.likelyFrost { return 35 }

        switch w.temperatureF {
        case 45...: return 0
        case 40..<45: return 3
        case 35..<40: return 10
        case 33..<35: return 20
        default: return 35
        }
    }

    public static func precipitationRiskPenalty(probability: Double, surfaceMoisturePenalty: Double) -> Double {
        let raw: Double
        switch probability {
        case ..<20: raw = 0
        case ..<40: raw = 4
        case ..<60: raw = 10
        case ..<80: raw = 18
        default: raw = 25
        }
        // Avoid fully double-counting moisture + rain risk.
        return surfaceMoisturePenalty >= 35 ? raw * 0.4 : raw
    }

    public static func ratingForScore(_ score: Int) -> MowabilityRating {
        switch score {
        case 95...: return .excellent
        case 85..<95: return .veryGood
        case 75..<85: return .good
        case 60..<75: return .fair
        case 40..<60: return .poor
        case 10..<40: return .veryPoor
        default: return .stop
        }
    }

    private static func interpolate(_ points: [(Double,Double)], _ x: Double) -> Double {
        if x <= points[0].0 { return points[0].1 }
        if x >= points[points.count-1].0 { return points[points.count-1].1 }
        for i in 0..<(points.count-1) {
            let (x1,y1) = points[i]
            let (x2,y2) = points[i+1]
            if x >= x1 && x <= x2 {
                let t = (x - x1) / (x2 - x1)
                return y1 + t * (y2 - y1)
            }
        }
        return points.last!.1
    }
}
