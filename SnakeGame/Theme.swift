import SwiftUI

struct GameTheme {
    // Board
    let boardBg       = Color(red: 0.10, green: 0.18, blue: 0.10)
    let tileA         = Color(red: 0.12, green: 0.22, blue: 0.12)
    let tileB         = Color(red: 0.14, green: 0.25, blue: 0.14)

    // Snake
    let snakeHead     = Color(red: 0.45, green: 0.95, blue: 0.15)
    let snakeTail     = Color(red: 0.15, green: 0.55, blue: 0.20)
    let snakeEyeWhite = Color.white
    let snakeEyePupil = Color(red: 0.08, green: 0.08, blue: 0.12)

    // Food
    let foodBody      = Color(red: 1.0, green: 0.25, blue: 0.20)
    let foodLeaf      = Color(red: 0.20, green: 0.72, blue: 0.15)
    let foodStem      = Color(red: 0.35, green: 0.22, blue: 0.10)

    // Obstacles
    let obstacle      = Color(red: 0.55, green: 0.35, blue: 0.18)
    let obstacleLine  = Color(red: 0.40, green: 0.25, blue: 0.12)

    // HUD
    let hudBg         = Color.black.opacity(0.50)
    let hudText       = Color.white
    let hudDim        = Color.white.opacity(0.55)
    let accent        = Color(red: 0.35, green: 0.92, blue: 0.25)
    let heartFull     = Color(red: 1.0, green: 0.30, blue: 0.35)
    let heartEmpty    = Color.white.opacity(0.2)

    // Controls
    let dpadBg        = Color.white.opacity(0.18)
    let dpadArrow     = Color.white.opacity(0.85)
    let dpadActive    = Color(red: 0.35, green: 0.92, blue: 0.25)
    let pillBg        = Color.white.opacity(0.12)
    let pillText      = Color.white

    // Overlays
    let gold          = Color(red: 1.0, green: 0.84, blue: 0.0)

    static let shared = GameTheme()
}
