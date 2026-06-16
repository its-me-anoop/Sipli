#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.waterquest.hydration";

/// The "PaperBackground" asset catalog color resource.
static NSString * const ACColorNamePaperBackground AC_SWIFT_PRIVATE = @"PaperBackground";

/// The "Mascot" asset catalog image resource.
static NSString * const ACImageNameMascot AC_SWIFT_PRIVATE = @"Mascot";

/// The "bottle" asset catalog image resource.
static NSString * const ACImageNameBottle AC_SWIFT_PRIVATE = @"bottle";

/// The "sipliIcon" asset catalog image resource.
static NSString * const ACImageNameSipliIcon AC_SWIFT_PRIVATE = @"sipliIcon";

#undef AC_SWIFT_PRIVATE
