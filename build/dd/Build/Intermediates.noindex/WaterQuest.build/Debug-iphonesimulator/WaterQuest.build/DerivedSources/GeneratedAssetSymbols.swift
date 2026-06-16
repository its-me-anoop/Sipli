import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "PaperBackground" asset catalog color resource.
    static let paperBackground = DeveloperToolsSupport.ColorResource(name: "PaperBackground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "Mascot" asset catalog image resource.
    static let mascot = DeveloperToolsSupport.ImageResource(name: "Mascot", bundle: resourceBundle)

    /// The "bottle" asset catalog image resource.
    static let bottle = DeveloperToolsSupport.ImageResource(name: "bottle", bundle: resourceBundle)

    /// The "sipliIcon" asset catalog image resource.
    static let sipliIcon = DeveloperToolsSupport.ImageResource(name: "sipliIcon", bundle: resourceBundle)

}

