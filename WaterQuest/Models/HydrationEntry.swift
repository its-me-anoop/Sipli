import Foundation

enum HydrationSource: String, Codable {
    case manual
    case healthKit
}

struct HydrationEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var volumeML: Double
    var source: HydrationSource
    var fluidType: FluidType
    var note: String?

    /// Effective hydration in mL after applying the fluid's hydration factor.
    var effectiveML: Double {
        volumeML * fluidType.hydrationFactor
    }

    init(id: UUID = UUID(), date: Date, volumeML: Double, source: HydrationSource, fluidType: FluidType = .water, note: String? = nil) {
        self.id = id
        self.date = date
        self.volumeML = volumeML
        self.source = source
        self.fluidType = fluidType
        self.note = note
    }

    // Custom Codable for backward compatibility — old entries without fluidType decode as .water
    private enum CodingKeys: String, CodingKey {
        case id, date, volumeML, source, fluidType, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self, forKey: .id)
        date      = try c.decode(Date.self, forKey: .date)
        volumeML  = try c.decode(Double.self, forKey: .volumeML)
        source    = try c.decode(HydrationSource.self, forKey: .source)
        fluidType = try c.decodeIfPresent(FluidType.self, forKey: .fluidType) ?? .water
        note      = try c.decodeIfPresent(String.self, forKey: .note)
    }
}
