
import Foundation

public enum TurfMoistureModel {

    public static func apply(
        previous: MoistureState,
        weather: HourlyWeather,
        lawn: LawnProfile,
        isDaylight: Bool
    ) -> MoistureState {
        var rainDebt = previous.rainDebt
        var dew = previous.dewMoisture

        // Rain debt can exceed 100 so 2" of rain remains wetter longer than 1".
        if weather.precipitationInches > 0 {
            rainDebt += weather.precipitationInches * 100.0
        }

        // Dew/fog style loading: only strong when humid and near dew point.
        if let dp = weather.dewPointF {
            let spread = max(0, weather.temperatureF - dp)
            if weather.relativeHumidity >= 90 && spread <= 3 {
                dew = max(dew, 55)
            } else if weather.relativeHumidity >= 85 && spread <= 5 {
                dew = max(dew, 40)
            }
        } else if weather.relativeHumidity >= 92 {
            dew = max(dew, 45)
        }

        let shadeMultipliers: [Int: Double] = [1:0.55, 2:0.70, 3:0.85, 4:1.00, 5:1.15]
        let shade = shadeMultipliers[lawn.shadeLevel] ?? 0.85

        let cloudFactor = max(0.25, 1.0 - weather.cloudCover / 125.0)
        let rhFactor = max(0.25, 1.0 - max(0, weather.relativeHumidity - 45) / 90.0)
        let wind = min(24, weather.sustainedWindMPH)
        let windFactor = 1.0 + min(0.35, wind / 70.0)
        let tempFactor = weather.temperatureF < 45 ? 0.45 :
                         weather.temperatureF < 60 ? 0.75 :
                         weather.temperatureF < 80 ? 1.00 :
                         weather.temperatureF < 95 ? 1.10 : 1.05
        let daylightFactor = isDaylight ? 1.0 : 0.05

        let dryingRate = 8.0 * shade * cloudFactor * rhFactor * windFactor * tempFactor * daylightFactor * lawn.dryingBias

        // Rain debt dries slowly and tapers near zero.
        let rainTaper = max(0.20, min(1.0, rainDebt / 50.0))
        rainDebt = max(0, rainDebt - dryingRate * rainTaper)

        // Dew is surface-only and clears substantially faster.
        let dewRate = dryingRate * 1.8
        let dewTaper = max(0.30, min(1.0, dew / 30.0))
        dew = max(0, dew - dewRate * dewTaper)

        return MoistureState(rainDebt: rainDebt, dewMoisture: dew)
    }
}
