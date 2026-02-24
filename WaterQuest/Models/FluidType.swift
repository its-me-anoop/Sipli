import SwiftUI

struct FluidComposition: Equatable, Hashable {
    let type: FluidType
    let proportion: Double
}

enum FluidType: String, CaseIterable, Codable, Identifiable, Hashable {
    // High hydration
    case water
    case sparklingWater
    case coconutWater
    case herbalTea

    // Mildly reduced hydration
    case tea
    case milk
    case juice
    case lemonade
    case smoothie
    case sportsDrink

    // Moderately reduced hydration
    case coffee
    case soda
    case energyDrink
    case soup

    // Alcohol (significant dehydration)
    case beer
    case wine
    case cocktail

    // Catch-all
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water:         return "Water"
        case .sparklingWater: return "Sparkling Water"
        case .coconutWater:  return "Coconut Water"
        case .herbalTea:     return "Herbal Tea"
        case .tea:           return "Tea"
        case .milk:          return "Milk"
        case .juice:         return "Juice"
        case .lemonade:      return "Lemonade"
        case .smoothie:      return "Smoothie"
        case .sportsDrink:   return "Sports Drink"
        case .coffee:        return "Coffee"
        case .soda:          return "Soda"
        case .energyDrink:   return "Energy Drink"
        case .soup:          return "Soup"
        case .beer:          return "Beer"
        case .wine:          return "Wine"
        case .cocktail:      return "Cocktail"
        case .other:         return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .water:          return "drop.fill"
        case .sparklingWater: return "bubbles.and.sparkles.fill"
        case .coconutWater:   return "leaf.fill"
        case .herbalTea:      return "mug.fill"
        case .tea:            return "cup.and.saucer.fill"
        case .milk:           return "cup.and.saucer.fill"
        case .juice:          return "takeoutbag.and.cup.and.straw.fill"
        case .lemonade:       return "wineglass.fill"
        case .smoothie:       return "takeoutbag.and.cup.and.straw.fill"
        case .sportsDrink:    return "figure.run"
        case .coffee:         return "cup.and.saucer.fill"
        case .soda:           return "takeoutbag.and.cup.and.straw.fill"
        case .energyDrink:    return "bolt.fill"
        case .soup:           return "fork.knife"
        case .beer:           return "mug.fill"
        case .wine:           return "wineglass.fill"
        case .cocktail:       return "wineglass.fill"
        case .other:          return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .water, .sparklingWater:          return Theme.lagoon
        case .coconutWater, .herbalTea, .tea:  return Theme.mint
        case .milk, .smoothie:                 return Theme.peach
        case .juice, .lemonade:                return Theme.sun
        case .sportsDrink, .energyDrink:       return Theme.coral
        case .coffee:                          return .brown
        case .soda:                            return Theme.lavender
        case .soup:                            return Theme.sun
        case .beer, .wine, .cocktail:          return Theme.coral
        case .other:                           return .gray
        }
    }

    /// Fraction of raw volume that counts as effective hydration (0.0–1.0).
    ///
    /// Based on sports nutrition research:
    /// - Water/sparkling/coconut water: 1.0 (baseline hydration)
    /// - Herbal tea: 0.97 (no caffeine, essentially flavored water)
    /// - Tea: 0.90 (mild diuretic from ~40mg caffeine)
    /// - Milk: 0.90 (electrolytes aid retention; fat slows absorption)
    /// - Juice/lemonade: 0.85 (high sugar impairs absorption via osmotic effect)
    /// - Sports drink: 0.95 (engineered for hydration with electrolytes)
    /// - Coffee: 0.80 (~95mg caffeine causes mild diuresis)
    /// - Smoothie: 0.80 (fiber and sugar slow hydration)
    /// - Soup: 0.80 (sodium aids retention but not all content is liquid)
    /// - Soda: 0.70 (high sugar + possible caffeine)
    /// - Energy drink: 0.60 (high caffeine 150-300mg, significant diuretic)
    /// - Beer (~5% ABV): 0.40 (alcohol is a diuretic)
    /// - Wine (~12% ABV): 0.25 (stronger diuretic than beer)
    /// - Cocktail (~20-40% ABV): 0.10 (spirits are strongly dehydrating)
    /// - Other: 0.80 (conservative default)
    var hydrationFactor: Double {
        switch self {
        case .water:          return 1.00
        case .sparklingWater: return 1.00
        case .coconutWater:   return 1.00
        case .herbalTea:      return 0.97
        case .tea:            return 0.90
        case .milk:           return 0.90
        case .juice:          return 0.85
        case .lemonade:       return 0.85
        case .smoothie:       return 0.80
        case .sportsDrink:    return 0.95
        case .coffee:         return 0.80
        case .soda:           return 0.70
        case .energyDrink:    return 0.60
        case .soup:           return 0.80
        case .beer:           return 0.40
        case .wine:           return 0.25
        case .cocktail:       return 0.10
        case .other:          return 0.80
        }
    }

    var hydrationLabel: String {
        "\(Int(hydrationFactor * 100))% hydration"
    }
}
