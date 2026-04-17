import XCTest
import UserNotifications
@testable import Sipli

final class NotificationCategoriesTests: XCTestCase {

    func test_all_containsHydrationReminderCategory() {
        let ids = NotificationCategories.all.map(\.identifier)
        XCTAssertTrue(ids.contains(NotificationCategoryID.hydrationReminder.rawValue))
    }

    func test_hydrationReminder_hasLog250MlAction() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        XCTAssertNotNil(category)
        let actionIds = category?.actions.map(\.identifier) ?? []
        XCTAssertTrue(actionIds.contains(NotificationActionID.log250ml.rawValue))
    }

    func test_hydrationReminder_hasLog500MlAction() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        let actionIds = category?.actions.map(\.identifier) ?? []
        XCTAssertTrue(actionIds.contains(NotificationActionID.log500ml.rawValue))
    }

    func test_hydrationReminder_hasSnooze1HAction() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        let actionIds = category?.actions.map(\.identifier) ?? []
        XCTAssertTrue(actionIds.contains(NotificationActionID.snooze1h.rawValue))
    }

    func test_log250Ml_doesNotRequireAuthentication() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        let log = category?.actions.first { $0.identifier == NotificationActionID.log250ml.rawValue }
        XCTAssertNotNil(log)
        XCTAssertFalse(log?.options.contains(.authenticationRequired) ?? true)
    }
}
