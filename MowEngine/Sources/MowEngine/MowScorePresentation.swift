import Foundation
public struct MowScorePresentation: Codable, Equatable {
    public var score10: Double
    public var colorStrength: Double
    public var accessibilityLabel: String
}
public enum MowScorePresenter {
    public static func present(_ result: MowabilityResult) -> MowScorePresentation {
        let s = Double(result.score) / 10.0
        return .init(score10: s,
                     colorStrength: min(1,max(0,s/10)),
                     accessibilityLabel: result.safetyState == .stop
                       ? String(format: "%.1f out of 10, unsafe conditions", s)
                       : String(format: "%.1f out of 10", s))
    }
}
