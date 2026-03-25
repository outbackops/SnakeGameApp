import Foundation
import SwiftUI

enum Direction {
    case up, down, left, right

    var offset: GridPoint {
        switch self {
        case .up:    return GridPoint(x: 0, y: -1)
        case .down:  return GridPoint(x: 0, y: 1)
        case .left:  return GridPoint(x: -1, y: 0)
        case .right: return GridPoint(x: 1, y: 0)
        }
    }

    func isOpposite(to other: Direction) -> Bool {
        switch (self, other) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            return true
        default:
            return false
        }
    }
}

struct GridPoint: Equatable, Hashable {
    let x: Int
    let y: Int
}

enum GameEvent {
    case ate, died, levelUp, powerUpCollected, highScore
}

@MainActor
final class GameViewModel: ObservableObject {
    private(set) var columns = 18
    private(set) var rows = 32
    let maxLives = 3
    private var gridConfigured = false

    // MARK: - Published state

    @Published private(set) var snake: [GridPoint] = []
    @Published private(set) var food = GridPoint(x: 0, y: 0)
    @Published private(set) var score = 0
    @Published private(set) var highScore = 0
    @Published private(set) var lives = 3
    @Published private(set) var isGameOver = false
    @Published private(set) var isPlaying = false

    @Published private(set) var levelIndex = 0
    @Published private(set) var levelScore = 0          // score within current level
    @Published private(set) var showingLevelUp = false
    @Published private(set) var isNewHighScore = false
    @Published var shakeTrigger = 0

    @Published private(set) var obstacles: Set<GridPoint> = []
    @Published private(set) var powerUpsOnBoard: [PowerUp] = []
    @Published private(set) var activeEffects: [ActiveEffect] = []

    @Published private(set) var currentDirection: Direction = .right

    var currentLevel: GameLevel { GameLevel.all[levelIndex] }

    // MARK: - Private

    private var pendingDirection: Direction = .right
    private var gameLoopTask: Task<Void, Never>?
    private var tickCount = 0
    private var snakeSet: Set<GridPoint> = []
    private let feedback = FeedbackManager.shared

    var effectiveTickInterval: Int {
        var interval = currentLevel.baseTickInterval
        if activeEffects.contains(where: { $0.type == .speedBoost }) {
            interval = max(50, interval - 40)
        }
        if activeEffects.contains(where: { $0.type == .slowDown }) {
            interval = interval + 50
        }
        return interval
    }

    var isGhostActive: Bool {
        activeEffects.contains(where: { $0.type == .ghost })
    }

    var isBonusActive: Bool {
        activeEffects.contains(where: { $0.type == .bonusPoints })
    }

    // MARK: - Init

    init() {
        highScore = UserDefaults.standard.integer(forKey: "snakeHighScore")
        resetBoard()
        startGame()
    }

    deinit {
        gameLoopTask?.cancel()
    }

    /// Call once from ContentView after measuring available board area.
    func configureGrid(boardWidth: CGFloat, boardHeight: CGFloat) {
        guard !gridConfigured else { return }
        gridConfigured = true

        let targetCellSize: CGFloat = 14
        let newCols = max(10, Int(boardWidth / targetCellSize))
        let cellSize = boardWidth / CGFloat(newCols)
        let newRows = max(10, Int(boardHeight / cellSize))

        let changed = newCols != columns || newRows != rows
        columns = newCols
        rows = newRows

        if changed {
            pauseGame()
            fullReset()
            startGame()
        }
    }

    // MARK: - Public API

    func startGame() {
        if isGameOver { fullReset() }
        guard !isPlaying else { return }
        isPlaying = true

        gameLoopTask?.cancel()
        gameLoopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(self.effectiveTickInterval))
                guard !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    func pauseGame() {
        isPlaying = false
        gameLoopTask?.cancel()
        gameLoopTask = nil
    }

    func restartGame() {
        pauseGame()
        fullReset()
        startGame()
    }

    func changeDirection(_ newDirection: Direction) {
        guard !newDirection.isOpposite(to: currentDirection) else { return }
        pendingDirection = newDirection
    }

    // MARK: - Game loop

    private func tick() {
        guard isPlaying, !isGameOver else { return }
        tickCount += 1

        // Expire effects
        activeEffects.removeAll { $0.expiresAtTick <= tickCount }

        // Expire uncollected power-ups
        powerUpsOnBoard.removeAll { $0.despawnTick <= tickCount }

        // Maybe spawn a power-up
        if powerUpsOnBoard.isEmpty && Double.random(in: 0...1) < currentLevel.powerUpChance {
            spawnPowerUp()
        }

        // Move snake
        if !pendingDirection.isOpposite(to: currentDirection) {
            currentDirection = pendingDirection
        }

        guard let head = snake.first else { return }
        let nextHead = GridPoint(
            x: head.x + currentDirection.offset.x,
            y: head.y + currentDirection.offset.y
        )

        // Collision: wall
        let hitWall = !isInsideBoard(nextHead)
        // Collision: self
        let hitSelf = snakeSet.contains(nextHead)
        // Collision: obstacle
        let hitObstacle = obstacles.contains(nextHead)

        let ghostMode = isGhostActive
        if (hitWall || hitSelf || hitObstacle) && !ghostMode {
            handleDeath()
            return
        }

        // Wrap around in ghost mode if hitting wall
        var actualHead = nextHead
        if hitWall && ghostMode {
            actualHead = GridPoint(
                x: ((nextHead.x % columns) + columns) % columns,
                y: ((nextHead.y % rows) + rows) % rows
            )
        }

        // Skip obstacle collision in ghost mode
        // Skip self collision in ghost mode

        snake.insert(actualHead, at: 0)
        snakeSet.insert(actualHead)

        // Check food
        if actualHead == food {
            let points = isBonusActive ? 2 : 1
            score += points
            levelScore += points
            feedback.playEat()
            placeFood()
            checkLevelUp()
        } else {
            let removed = snake.removeLast()
            snakeSet.remove(removed)
        }

        // Check power-up collection
        if let idx = powerUpsOnBoard.firstIndex(where: { $0.position == actualHead }) {
            collectPowerUp(powerUpsOnBoard[idx])
            powerUpsOnBoard.remove(at: idx)
        }
    }

    // MARK: - Death & Lives

    private func handleDeath() {
        lives -= 1
        shakeTrigger += 1
        feedback.playDie()

        if lives <= 0 {
            isGameOver = true
            pauseGame()
            if score > highScore {
                highScore = score
                isNewHighScore = true
                UserDefaults.standard.set(highScore, forKey: "snakeHighScore")
                feedback.playHighScore()
            }
        } else {
            // Respawn snake in current level
            pauseGame()
            respawnSnake()
            startGame()
        }
    }

    // MARK: - Level progression

    private func checkLevelUp() {
        if levelScore >= currentLevel.targetScore && levelIndex < GameLevel.all.count - 1 {
            levelIndex += 1
            levelScore = 0
            loadLevelObstacles()
            placeFood()
            showingLevelUp = true
            feedback.playLevelUp()
            // Auto-dismiss after 1.5s
            Task {
                try? await Task.sleep(for: .milliseconds(1500))
                showingLevelUp = false
            }
        }
    }

    // MARK: - Power-ups

    private func spawnPowerUp() {
        guard let pos = randomFreeCell() else { return }
        let type = PowerUpType.allCases.randomElement()!
        let pu = PowerUp(type: type, position: pos,
                         spawnTick: tickCount,
                         despawnTick: tickCount + 60)
        powerUpsOnBoard.append(pu)
    }

    private func collectPowerUp(_ pu: PowerUp) {
        feedback.playPowerUp()
        if pu.type == .shrink {
            // Instant: remove up to 3 tail segments
            let removeCount = min(3, max(0, snake.count - 1))
            for _ in 0..<removeCount {
                let removed = snake.removeLast()
                snakeSet.remove(removed)
            }
        } else {
            let effect = ActiveEffect(type: pu.type, expiresAtTick: tickCount + pu.type.durationTicks)
            activeEffects.append(effect)
        }
    }

    // MARK: - Board setup

    private func fullReset() {
        levelIndex = 0
        levelScore = 0
        score = 0
        lives = maxLives
        isGameOver = false
        isNewHighScore = false
        showingLevelUp = false
        activeEffects = []
        powerUpsOnBoard = []
        tickCount = 0
        loadLevelObstacles()
        resetBoard()
    }

    private func resetBoard() {
        let center = GridPoint(x: columns / 2, y: rows / 2)
        snake = [
            center,
            GridPoint(x: center.x - 1, y: center.y),
            GridPoint(x: center.x - 2, y: center.y),
        ]
        snakeSet = Set(snake)
        isPlaying = false
        currentDirection = .right
        pendingDirection = .right
        placeFood()
    }

    private func respawnSnake() {
        // Find 3 consecutive clear horizontal cells
        let center = GridPoint(x: columns / 2, y: rows / 2)
        var spawnPoint: GridPoint?

        // Spiral search outward from center
        outer: for dist in 0..<max(columns, rows) {
            for dy in -dist...dist {
                for dx in -dist...dist {
                    guard abs(dx) == dist || abs(dy) == dist else { continue }
                    let y = (center.y + dy + rows) % rows
                    let x = (center.x + dx + columns) % columns
                    let p  = GridPoint(x: x, y: y)
                    let p1 = GridPoint(x: (x - 1 + columns) % columns, y: y)
                    let p2 = GridPoint(x: (x - 2 + columns) % columns, y: y)
                    if !obstacles.contains(p) && !obstacles.contains(p1) && !obstacles.contains(p2) {
                        spawnPoint = p
                        break outer
                    }
                }
            }
        }

        let sp = spawnPoint ?? center
        snake = [
            sp,
            GridPoint(x: (sp.x - 1 + columns) % columns, y: sp.y),
            GridPoint(x: (sp.x - 2 + columns) % columns, y: sp.y),
        ]
        snakeSet = Set(snake)
        currentDirection = .right
        pendingDirection = .right
        powerUpsOnBoard = []
        activeEffects = []
        placeFood()  // re-place food to avoid spawning on new obstacles
    }

    private func loadLevelObstacles() {
        // Regenerate obstacles for current grid size
        obstacles = Set(currentLevel.generateObstacles(columns: columns, rows: rows))
    }

    // MARK: - Helpers

    private func placeFood() {
        let allCells = Set((0..<rows).flatMap { y in (0..<columns).map { x in GridPoint(x: x, y: y) } })
        let blocked = snakeSet.union(obstacles).union(Set(powerUpsOnBoard.map(\.position)))
        let available = allCells.subtracting(blocked)

        // Filter to only reachable cells (adjacent to at least one non-obstacle cell)
        let reachable = available.filter { cell in
            // A cell is reachable if at least one neighbor is also not an obstacle
            let neighbors = [
                GridPoint(x: cell.x, y: cell.y - 1),
                GridPoint(x: cell.x, y: cell.y + 1),
                GridPoint(x: cell.x - 1, y: cell.y),
                GridPoint(x: cell.x + 1, y: cell.y),
            ]
            return neighbors.contains { n in
                isInsideBoard(n) && !obstacles.contains(n)
            }
        }

        food = reachable.randomElement() ?? available.randomElement() ?? food
    }

    private func randomFreeCell() -> GridPoint? {
        let allCells = Set((0..<rows).flatMap { y in (0..<columns).map { x in GridPoint(x: x, y: y) } })
        let blocked = snakeSet.union(obstacles).union(Set(powerUpsOnBoard.map(\.position))).union([food])
        let available = allCells.subtracting(blocked)
        return available.randomElement()
    }

    private func isInsideBoard(_ point: GridPoint) -> Bool {
        (0..<columns).contains(point.x) && (0..<rows).contains(point.y)
    }
}
