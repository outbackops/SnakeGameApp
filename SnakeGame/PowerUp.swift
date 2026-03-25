import SwiftUI

enum PowerUpType: CaseIterable {
    case speedBoost   // temporarily faster
    case slowDown     // temporarily slower
    case ghost        // pass through walls & self for 5s
    case bonusPoints  // 2x score for 5s
    case shrink       // remove 3 tail segments instantly

    var symbol: String {
        switch self {
        case .speedBoost:  return "⚡"
        case .slowDown:    return "🐌"
        case .ghost:       return "👻"
        case .bonusPoints: return "⭐"
        case .shrink:      return "✂️"
        }
    }

    var label: String {
        switch self {
        case .speedBoost:  return "Speed!"
        case .slowDown:    return "Slow"
        case .ghost:       return "Ghost"
        case .bonusPoints: return "2× Pts"
        case .shrink:      return "Shrink"
        }
    }

    var color: Color {
        switch self {
        case .speedBoost:  return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .slowDown:    return Color(red: 0.3, green: 0.7, blue: 1.0)
        case .ghost:       return Color(red: 0.7, green: 0.5, blue: 1.0)
        case .bonusPoints: return Color(red: 1.0, green: 0.85, blue: 0.2)
        case .shrink:      return Color(red: 1.0, green: 0.45, blue: 0.7)
        }
    }

    /// Duration in ticks (0 = instant effect)
    var durationTicks: Int {
        switch self {
        case .speedBoost:  return 30
        case .slowDown:    return 30
        case .ghost:       return 28
        case .bonusPoints: return 28
        case .shrink:      return 0
        }
    }
}

struct PowerUp: Equatable {
    let type: PowerUpType
    let position: GridPoint
    let spawnTick: Int
    let despawnTick: Int       // disappears if not collected
}

struct ActiveEffect: Equatable, Identifiable {
    let id = UUID()
    let type: PowerUpType
    let expiresAtTick: Int
}
