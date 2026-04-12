import WatchKit

enum WatchHaptics {
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }

    static func goalReached() {
        WKInterfaceDevice.current().play(.notification)
    }

    static func reminder() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    static func click() {
        WKInterfaceDevice.current().play(.click)
    }
}
