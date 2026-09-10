
import XCTest
@testable import MowEngine

final class MowEngineTests: XCTestCase {

    private func weather(
        temp: Double = 75,
        rh: Double = 50,
        wind: Double = 5,
        gust: Double? = nil,
        pop: Double = 0,
        rain: Double = 0,
        thunder: Bool = false,
        severe: Bool = false,
        tornado: Bool = false,
        frost: Bool = false,
        frozen: Bool = false,
        snowIce: Bool = false,
        date: Date = Date()
    ) -> HourlyWeather {
        HourlyWeather(
            date: date,
            temperatureF: temp,
            relativeHumidity: rh,
            sustainedWindMPH: wind,
            gustMPH: gust,
            precipitationProbability: pop,
            precipitationInches: rain,
            cloudCover: 20,
            isThunderstorm: thunder,
            severeThunderstormWarning: severe,
            tornadoWarning: tornado,
            likelyFrost: frost,
            likelyFrozenTurf: frozen,
            snowOrIcePresent: snowIce
        )
    }

    func testIdealCanScore100() {
        let r = MowabilityEngine.evaluate(
            weather: weather(),
            lawn: LawnProfile(),
            moisture: MoistureState(),
            turfStressSeverity: 0
        )
        XCTAssertEqual(r.score, 100)
    }

    func testWetnessNeverAutomaticallyStops() {
        let r = MowabilityEngine.evaluate(
            weather: weather(),
            lawn: LawnProfile(),
            moisture: MoistureState(rainDebt: 150, dewMoisture: 0),
            turfStressSeverity: 0
        )
        XCTAssertEqual(r.safetyState, .normal)
        XCTAssertGreaterThanOrEqual(r.score, 10)
    }

    func testThunderstormStops() {
        let r = MowabilityEngine.evaluate(
            weather: weather(thunder: true),
            lawn: LawnProfile(),
            moisture: MoistureState(),
            turfStressSeverity: 0
        )
        XCTAssertEqual(r.score, 0)
        XCTAssertEqual(r.safetyState, .stop)
    }

    func testWindBelow25NoPenalty() {
        XCTAssertEqual(MowabilityEngine.windPenalty(24.9), 0)
    }

    func testWindPenaltyMonotonic() {
        var previous = MowabilityEngine.windPenalty(0)
        for mph in stride(from: 1.0, through: 60.0, by: 1.0) {
            let current = MowabilityEngine.windPenalty(mph)
            XCTAssertGreaterThanOrEqual(current, previous)
            previous = current
        }
    }

    func testGustPenaltyIndependentOfSustained() {
        XCTAssertEqual(MowabilityEngine.gustPenalty(34.9), 0)
        XCTAssertEqual(MowabilityEngine.gustPenalty(55), 30)
    }

    func testColdDoesNotScorePerfect() {
        let r = MowabilityEngine.evaluate(
            weather: weather(temp: -10),
            lawn: LawnProfile(),
            moisture: MoistureState(),
            turfStressSeverity: 0
        )
        XCTAssertLessThan(r.score, 100)
    }

    func testWorseningMoistureNeverRaisesScore() {
        var previous = 100
        for m in stride(from: 0.0, through: 100.0, by: 5.0) {
            let r = MowabilityEngine.evaluate(
                weather: weather(),
                lawn: LawnProfile(),
                moisture: MoistureState(rainDebt: m, dewMoisture: 0),
                turfStressSeverity: 0
            )
            XCTAssertLessThanOrEqual(r.score, previous)
            previous = r.score
        }
    }

    func testHotterWeatherDoesNotImproveScoreOnceHot() {
        var previous = 100
        for t in stride(from: 85.0, through: 115.0, by: 1.0) {
            let r = MowabilityEngine.evaluate(
                weather: weather(temp: t, rh: 70),
                lawn: LawnProfile(grassFamily: .coolSeason),
                moisture: MoistureState(),
                turfStressSeverity: 40
            )
            XCTAssertLessThanOrEqual(r.score, previous)
            previous = r.score
        }
    }

    func testRainDebtCanExceedVisible100() {
        let lawn = LawnProfile()
        let w = weather(rain: 2.0)
        let state = TurfMoistureModel.apply(
            previous: MoistureState(),
            weather: w,
            lawn: lawn,
            isDaylight: false
        )
        XCTAssertGreaterThan(state.rainDebt, 100)
        XCTAssertEqual(state.visibleSurfaceMoisture, 100)
    }

    func testWeekdayAvailabilityBlocksNoonWindow() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let fmt = ISO8601DateFormatter()
        let lawn = LawnProfile(mowingDurationMinutes: 60, preferredWeekdayStartHour: 17)

        var hours: [(HourlyWeather, MowabilityResult, Bool)] = []
        for h in 12...18 {
            let d = fmt.date(from: String(format: "2026-09-09T%02d:00:00Z", h))!
            let w = weather(date: d)
            let score = (h < 17) ? 100 : 50
            let result = MowabilityResult(
                score: score,
                rating: MowabilityEngine.ratingForScore(score),
                safetyState: .normal,
                reasons: [],
                penalties: PenaltyBreakdown(),
                surfaceMoisture: 0
            )
            hours.append((w, result, true))
        }

        let rec = RecommendationEngine.bestDailyWindow(
            hours: hours.map { (weather: $0.0, result: $0.1, isDaylight: $0.2) },
            lawn: lawn,
            calendar: cal
        )
        XCTAssertNil(rec.bestWindow)
        XCTAssertEqual(rec.message, "No suitable conditions window during your available time.")
    }

    func testDurationRequiresContiguousWindow() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let fmt = ISO8601DateFormatter()
        let lawn = LawnProfile(mowingDurationMinutes: 90)

        var hours: [(weather: HourlyWeather, result: MowabilityResult, isDaylight: Bool)] = []
        for h in 16...17 {
            let d = fmt.date(from: String(format: "2026-09-12T%02d:00:00Z", h))!
            let w = weather(date: d)
            let result = MowabilityResult(
                score: 95, rating: .excellent, safetyState: .normal,
                reasons: [], penalties: PenaltyBreakdown(), surfaceMoisture: 0
            )
            hours.append((w, result, true))
        }

        let rec = RecommendationEngine.bestDailyWindow(hours: hours, lawn: lawn, calendar: cal)
        XCTAssertNotNil(rec.bestWindow) // two hourly blocks = 120 minutes, enough for 105 required
    }

    func testTenPointPresentation() {
        let r = MowabilityEngine.evaluate(weather: weather(), lawn: LawnProfile(),
            moisture: MoistureState(), turfStressSeverity: 0)
        XCTAssertEqual(MowScorePresenter.present(r).score10, 10.0)
    }

    func testTrackerNeverChangesMowScore() {
        let lawn = LawnProfile()
        let w = weather()
        let before = MowabilityEngine.evaluate(weather: w, lawn: lawn,
            moisture: MoistureState(), turfStressSeverity: 0).score
        var tracker = LawnTrackerState(growthProgress: 0)
        tracker = LawnTrackerEngine.updateGrowth(current: tracker, dailyGrowthUnits: 2, lawn: lawn)
        let after = MowabilityEngine.evaluate(weather: w, lawn: lawn,
            moisture: MoistureState(), turfStressSeverity: 0).score
        XCTAssertEqual(before, after)
        XCTAssertEqual(tracker.status, .likelyLong)
    }

    func testRecordMowResetsTrackerOnly() {
        let t = LawnTrackerEngine.recordMow(at: Date(),
            current: LawnTrackerState(growthProgress: 1.2))
        XCTAssertEqual(t.growthProgress, 0)
        XCTAssertNotNil(t.lastMowed)
    }

}
