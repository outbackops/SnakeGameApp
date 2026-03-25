import SwiftUI

struct GameLevel {
    let id: Int
    let name: String
    let emoji: String
    let targetScore: Int
    let baseTickInterval: Int      // ms per tick
    let obstacleGenerator: (Int, Int) -> [GridPoint]  // (columns, rows) -> obstacles
    let powerUpChance: Double      // 0.0–1.0, checked each tick

    var displayName: String { "\(emoji) \(name)" }

    func generateObstacles(columns: Int, rows: Int) -> [GridPoint] {
        obstacleGenerator(columns, rows)
    }
}

extension GameLevel {
    static let all: [GameLevel] = [
        GameLevel(
            id: 1, name: "Hatchling", emoji: "🐣",
            targetScore: 5, baseTickInterval: 160,
            obstacleGenerator: { _, _ in [] },
            powerUpChance: 0.0
        ),
        GameLevel(
            id: 2, name: "Slither", emoji: "🐍",
            targetScore: 10, baseTickInterval: 145,
            obstacleGenerator: { _, _ in [] },
            powerUpChance: 0.005
        ),
        GameLevel(
            id: 3, name: "Garden", emoji: "🌿",
            targetScore: 15, baseTickInterval: 135,
            obstacleGenerator: centerDots,
            powerUpChance: 0.008
        ),
        GameLevel(
            id: 4, name: "Maze", emoji: "🧱",
            targetScore: 20, baseTickInterval: 125,
            obstacleGenerator: cornerBlocks,
            powerUpChance: 0.01
        ),
        GameLevel(
            id: 5, name: "Rush", emoji: "💨",
            targetScore: 25, baseTickInterval: 115,
            obstacleGenerator: horizontalBars,
            powerUpChance: 0.012
        ),
        GameLevel(
            id: 6, name: "Jungle", emoji: "🌴",
            targetScore: 30, baseTickInterval: 108,
            obstacleGenerator: scatteredWalls,
            powerUpChance: 0.015
        ),
        GameLevel(
            id: 7, name: "Tunnel", emoji: "🕳️",
            targetScore: 35, baseTickInterval: 100,
            obstacleGenerator: corridorWalls,
            powerUpChance: 0.018
        ),
        GameLevel(
            id: 8, name: "Arena", emoji: "🏟️",
            targetScore: 40, baseTickInterval: 92,
            obstacleGenerator: arenaWalls,
            powerUpChance: 0.02
        ),
        GameLevel(
            id: 9, name: "Viper", emoji: "🐉",
            targetScore: 50, baseTickInterval: 85,
            obstacleGenerator: denseWalls,
            powerUpChance: 0.025
        ),
        GameLevel(
            id: 10, name: "Inferno", emoji: "🔥",
            targetScore: .max, baseTickInterval: 75,
            obstacleGenerator: infernoWalls,
            powerUpChance: 0.03
        ),
    ]

    // MARK: - Obstacle generators

    private static func centerDots(columns: Int, rows: Int) -> [GridPoint] {
        let cx = columns / 2
        let cy = rows / 2 - 4   // offset upward to avoid spawn point
        return [
            GridPoint(x: cx - 1, y: cy), GridPoint(x: cx, y: cy), GridPoint(x: cx + 1, y: cy),
            GridPoint(x: cx, y: cy - 1), GridPoint(x: cx, y: cy + 1),
        ]
    }

    private static func cornerBlocks(columns: Int, rows: Int) -> [GridPoint] {
        var pts: [GridPoint] = []
        for dx in 0..<3 {
            for dy in 0..<3 {
                pts.append(GridPoint(x: 2 + dx, y: 4 + dy))
                pts.append(GridPoint(x: columns - 5 + dx, y: 4 + dy))
                pts.append(GridPoint(x: 2 + dx, y: rows - 7 + dy))
                pts.append(GridPoint(x: columns - 5 + dx, y: rows - 7 + dy))
            }
        }
        return pts
    }

    private static func horizontalBars(columns: Int, rows: Int) -> [GridPoint] {
        var pts: [GridPoint] = []
        let barY1 = rows / 3
        let barY2 = 2 * rows / 3
        for x in 3..<(columns - 3) {
            pts.append(GridPoint(x: x, y: barY1))
            pts.append(GridPoint(x: x, y: barY2))
        }
        return pts
    }

    private static func scatteredWalls(columns: Int, rows: Int) -> [GridPoint] {
        var pts: [GridPoint] = []
        let positions = [
            (3, 5), (7, 8), (12, 6), (15, 10),
            (4, 15), (9, 18), (13, 14), (2, 22),
            (8, 24), (14, 20), (6, 27), (11, 26),
        ]
        for (x, y) in positions where x < columns && y < rows {
            pts.append(GridPoint(x: x, y: y))
            if x + 1 < columns { pts.append(GridPoint(x: x + 1, y: y)) }
        }
        return pts
    }

    private static func corridorWalls(columns: Int, rows: Int) -> [GridPoint] {
        var pts: [GridPoint] = []
        let wallX1 = 4
        let wallX2 = columns - 5
        for y in 3..<(rows - 3) {
            if y % 6 < 4 {
                pts.append(GridPoint(x: wallX1, y: y))
            }
            if (y + 3) % 6 < 4 {
                pts.append(GridPoint(x: wallX2, y: y))
            }
        }
        return pts
    }

    private static func arenaWalls(columns: Int, rows: Int) -> [GridPoint] {
        var pts: [GridPoint] = []
        let cx = columns / 2
        let cy = rows / 2
        let rx = 5
        let ry = 7
        for angle in stride(from: 0.0, to: 360.0, by: 8.0) {
            let rad = angle * .pi / 180
            let x = cx + Int(round(Double(rx) * cos(rad)))
            let y = cy + Int(round(Double(ry) * sin(rad)))
            if x >= 0 && x < columns && y >= 0 && y < rows {
                let p = GridPoint(x: x, y: y)
                if !pts.contains(p) { pts.append(p) }
            }
        }
        return pts
    }

    private static func denseWalls(columns: Int, rows: Int) -> [GridPoint] {
        var pts = cornerBlocks(columns: columns, rows: rows)
        pts += horizontalBars(columns: columns, rows: rows)
        let cx = columns / 2
        let cy = rows / 2
        for dy in -1...1 {
            pts.append(GridPoint(x: cx, y: cy + dy))
        }
        return Array(Set(pts))
    }

    private static func infernoWalls(columns: Int, rows: Int) -> [GridPoint] {
        var pts = denseWalls(columns: columns, rows: rows)
        pts += scatteredWalls(columns: columns, rows: rows)
        for x in stride(from: 2, to: columns - 2, by: 4) {
            let y = rows / 2
            pts.append(GridPoint(x: x, y: y - 4))
            pts.append(GridPoint(x: x, y: y + 4))
        }
        return Array(Set(pts))
    }
}
