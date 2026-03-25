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

    // Specialty teas
    case greenTea
    case blackTea
    case earlGrey
    case chamomile
    case peppermintTea
    case matcha
    case oolong
    case chai
    case rooibos

    // Mildly reduced hydration
    case tea
    case milk
    case juice
    case lemonade
    case smoothie
    case sportsDrink

    // Espresso-based coffees
    case espresso
    case americano
    case latte
    case cappuccino
    case flatWhite
    case mocha
    case icedCoffee
    case coldBrew
    case macchiato

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
        case .water:          return "Water"
        case .sparklingWater: return "Sparkling Water"
        case .coconutWater:   return "Coconut Water"
        case .herbalTea:      return "Herbal Tea"
        case .greenTea:       return "Green Tea"
        case .blackTea:       return "Black Tea"
        case .earlGrey:       return "Earl Grey"
        case .chamomile:      return "Chamomile"
        case .peppermintTea:  return "Peppermint"
        case .matcha:         return "Matcha"
        case .oolong:         return "Oolong"
        case .chai:           return "Chai"
        case .rooibos:        return "Rooibos"
        case .tea:            return "Tea"
        case .milk:           return "Milk"
        case .juice:          return "Juice"
        case .lemonade:       return "Lemonade"
        case .smoothie:       return "Smoothie"
        case .sportsDrink:    return "Sports Drink"
        case .espresso:       return "Espresso"
        case .americano:      return "Americano"
        case .latte:          return "Latte"
        case .cappuccino:     return "Cappuccino"
        case .flatWhite:      return "Flat White"
        case .mocha:          return "Mocha"
        case .icedCoffee:     return "Iced Coffee"
        case .coldBrew:       return "Cold Brew"
        case .macchiato:      return "Macchiato"
        case .coffee:         return "Coffee"
        case .soda:           return "Soda"
        case .energyDrink:    return "Energy Drink"
        case .soup:           return "Soup"
        case .beer:           return "Beer"
        case .wine:           return "Wine"
        case .cocktail:       return "Cocktail"
        case .other:          return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .water:          return "drop.fill"
        case .sparklingWater: return "bubbles.and.sparkles.fill"
        case .coconutWater:   return "leaf.fill"
        case .herbalTea:      return "mug.fill"
        case .greenTea:       return "leaf.fill"
        case .blackTea:       return "cup.and.saucer.fill"
        case .earlGrey:       return "cup.and.saucer.fill"
        case .chamomile:      return "mug.fill"
        case .peppermintTea:  return "leaf.fill"
        case .matcha:         return "leaf.fill"
        case .oolong:         return "cup.and.saucer.fill"
        case .chai:           return "mug.fill"
        case .rooibos:        return "mug.fill"
        case .tea:            return "cup.and.saucer.fill"
        case .milk:           return "cup.and.saucer.fill"
        case .juice:          return "takeoutbag.and.cup.and.straw.fill"
        case .lemonade:       return "wineglass.fill"
        case .smoothie:       return "takeoutbag.and.cup.and.straw.fill"
        case .sportsDrink:    return "figure.run"
        case .espresso:       return "cup.and.saucer.fill"
        case .americano:      return "cup.and.saucer.fill"
        case .latte:          return "mug.fill"
        case .cappuccino:     return "cup.and.saucer.fill"
        case .flatWhite:      return "cup.and.saucer.fill"
        case .mocha:          return "mug.fill"
        case .icedCoffee:     return "takeoutbag.and.cup.and.straw.fill"
        case .coldBrew:       return "takeoutbag.and.cup.and.straw.fill"
        case .macchiato:      return "cup.and.saucer.fill"
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
        case .water, .sparklingWater:                       return Theme.lagoon
        case .coconutWater:                                 return Theme.mint
        case .herbalTea, .chamomile, .peppermintTea:        return Theme.mint
        case .greenTea, .matcha:                            return Color(red: 0.27, green: 0.68, blue: 0.36)
        case .blackTea, .oolong:                            return Color(red: 0.42, green: 0.27, blue: 0.18)
        case .earlGrey:                                     return Theme.lavender
        case .chai:                                         return Theme.peach
        case .rooibos:                                      return Theme.coral
        case .tea:                                          return Theme.mint
        case .milk, .smoothie:                              return Theme.peach
        case .juice, .lemonade:                             return Theme.sun
        case .sportsDrink, .energyDrink:                    return Theme.coral
        case .espresso, .americano, .coffee, .coldBrew:     return Color(red: 0.32, green: 0.18, blue: 0.08)
        case .latte, .flatWhite:                            return Color(red: 0.72, green: 0.48, blue: 0.28)
        case .cappuccino, .macchiato:                       return Color(red: 0.56, green: 0.34, blue: 0.16)
        case .mocha:                                        return Color(red: 0.40, green: 0.22, blue: 0.12)
        case .icedCoffee:                                   return Color(red: 0.48, green: 0.30, blue: 0.18)
        case .soda:                                         return Theme.lavender
        case .soup:                                         return Theme.sun
        case .beer, .wine, .cocktail:                       return Theme.coral
        case .other:                                        return .gray
        }
    }

    /// Fraction of raw volume that counts as effective hydration (0.0–1.0).
    ///
    /// Based on sports nutrition research:
    /// - Water/sparkling/coconut water: 1.0 (baseline hydration)
    /// - Herbal teas (chamomile, peppermint, rooibos): 0.97 (no caffeine, essentially flavoured water)
    /// - Green tea: 0.92 (~30 mg caffeine per 240 mL, mild diuretic)
    /// - Oolong: 0.90 (~37 mg caffeine, moderate)
    /// - Black tea / Earl Grey / Chai: 0.88 (~50 mg caffeine)
    /// - Matcha: 0.86 (~70 mg caffeine per 180 mL)
    /// - Tea (generic): 0.90
    /// - Milk: 0.90 (electrolytes aid retention)
    /// - Juice / Lemonade: 0.85 (high sugar impairs absorption)
    /// - Sports drink: 0.95 (engineered electrolyte balance)
    /// - Latte / Flat White: 0.84 (milk offsets espresso caffeine)
    /// - Cappuccino: 0.82
    /// - Americano / Coffee / Iced Coffee: 0.80 (~95 mg caffeine)
    /// - Macchiato: 0.80
    /// - Espresso: 0.80 (~60–75 mg caffeine in 30 mL — net dehydration effect is modest)
    /// - Mocha: 0.78 (espresso + sugar)
    /// - Cold Brew: 0.75 (~150–200 mg caffeine per 300 mL — more concentrated)
    /// - Smoothie: 0.80 (fibre and sugar slow hydration)
    /// - Soup: 0.80 (sodium aids retention but not all content is liquid)
    /// - Soda: 0.70 (high sugar + possible caffeine)
    /// - Energy drink: 0.60 (high caffeine 150–300 mg, significant diuretic)
    /// - Beer (~5 % ABV): 0.40 (alcohol is a diuretic)
    /// - Wine (~12 % ABV): 0.25 (stronger diuretic than beer)
    /// - Cocktail (~20–40 % ABV): 0.10 (spirits are strongly dehydrating)
    /// - Other: 0.80 (conservative default)
    var hydrationFactor: Double {
        switch self {
        case .water:          return 1.00
        case .sparklingWater: return 1.00
        case .coconutWater:   return 1.00
        case .herbalTea:      return 0.97
        case .chamomile:      return 0.97
        case .peppermintTea:  return 0.97
        case .rooibos:        return 0.97
        case .greenTea:       return 0.92
        case .oolong:         return 0.90
        case .tea:            return 0.90
        case .milk:           return 0.90
        case .blackTea:       return 0.88
        case .earlGrey:       return 0.88
        case .chai:           return 0.88
        case .matcha:         return 0.86
        case .juice:          return 0.85
        case .lemonade:       return 0.85
        case .latte:          return 0.84
        case .flatWhite:      return 0.83
        case .cappuccino:     return 0.82
        case .sportsDrink:    return 0.95
        case .espresso:       return 0.80
        case .americano:      return 0.80
        case .coffee:         return 0.80
        case .icedCoffee:     return 0.80
        case .macchiato:      return 0.80
        case .smoothie:       return 0.80
        case .soup:           return 0.80
        case .other:          return 0.80
        case .mocha:          return 0.78
        case .coldBrew:       return 0.75
        case .soda:           return 0.70
        case .energyDrink:    return 0.60
        case .beer:           return 0.40
        case .wine:           return 0.25
        case .cocktail:       return 0.10
        }
    }

    /// Default serving size in millilitres — used to pre-fill the intake slider.
    var defaultServingML: Double {
        switch self {
        case .water:          return 250
        case .sparklingWater: return 330
        case .coconutWater:   return 330
        case .herbalTea:      return 240
        case .greenTea:       return 240
        case .blackTea:       return 240
        case .earlGrey:       return 240
        case .chamomile:      return 240
        case .peppermintTea:  return 240
        case .matcha:         return 180
        case .oolong:         return 240
        case .chai:           return 240
        case .rooibos:        return 240
        case .tea:            return 240
        case .milk:           return 250
        case .juice:          return 250
        case .lemonade:       return 250
        case .smoothie:       return 350
        case .sportsDrink:    return 500
        case .espresso:       return 30
        case .americano:      return 240
        case .latte:          return 350
        case .cappuccino:     return 180
        case .flatWhite:      return 220
        case .mocha:          return 350
        case .icedCoffee:     return 360
        case .coldBrew:       return 300
        case .macchiato:      return 60
        case .coffee:         return 240
        case .soda:           return 330
        case .energyDrink:    return 250
        case .soup:           return 300
        case .beer:           return 330
        case .wine:           return 175
        case .cocktail:       return 200
        case .other:          return 250
        }
    }

    var hydrationLabel: String {
        "\(Int(hydrationFactor * 100))% hydration"
    }
}
