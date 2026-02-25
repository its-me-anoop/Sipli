import Foundation

enum Formatters {
    static func volumeString(ml: Double, unit: UnitSystem) -> String {
        let amount = unit.amount(fromML: ml)
        if unit == .metric {
            return "\(Int(amount)) ml"
        }
        return String(format: "%.0f oz", amount)
    }

    static func shortVolume(ml: Double, unit: UnitSystem) -> String {
        let amount = unit.amount(fromML: ml)
        if unit == .metric {
            return "\(Int(amount))"
        }
        return String(format: "%.0f", amount)
    }

    static func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    static func temperatureString(celsius: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return "\(Int(celsius))°C"
        case .imperial:
            let fahrenheit = celsius * 9.0 / 5.0 + 32
            return "\(Int(fahrenheit))°F"
        }
    }
}
