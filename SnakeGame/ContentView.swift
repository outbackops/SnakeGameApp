import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @FocusState private var isFocused: Bool

    private let theme = GameTheme.shared

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBot = proxy.safeAreaInsets.bottom
            let _ = configureGridOnce(screenSize: proxy.size,
                                      safeTop: safeTop, safeBot: safeBot)

            VStack(spacing: 0) {
                // Top safe area fill
                theme.boardBg
                    .frame(height: safeTop)

                // Header HUD
                headerHUD
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.boardBg)

                // Active effects bar
                if !viewModel.activeEffects.isEmpty {
                    effectsBar
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                        .background(theme.boardBg)
                }

                // Board
                ZStack {
                    boardCanvas

                    if viewModel.showingLevelUp {
                        levelUpBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }

                    if viewModel.isGameOver {
                        gameOverOverlay
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }

                    if viewModel.isNewHighScore && viewModel.isGameOver {
                        ConfettiView()
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(swipeGesture)

                // Controls
                if !viewModel.isGameOver {
                    controlsBar
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.boardBg)
                }

                // Bottom safe area fill
                theme.boardBg
                    .frame(height: safeBot)
            }
            .background(theme.boardBg)
            .animation(.easeInOut(duration: 0.25), value: viewModel.isGameOver)
            .animation(.easeInOut(duration: 0.25), value: viewModel.showingLevelUp)
        }
        .ignoresSafeArea()
        .shake(trigger: viewModel.shakeTrigger)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.upArrow)    { viewModel.changeDirection(.up);    return .handled }
        .onKeyPress(.downArrow)  { viewModel.changeDirection(.down);  return .handled }
        .onKeyPress(.leftArrow)  { viewModel.changeDirection(.left);  return .handled }
        .onKeyPress(.rightArrow) { viewModel.changeDirection(.right); return .handled }
        .onKeyPress(" ") {
            if viewModel.isGameOver { viewModel.restartGame() }
            else if viewModel.isPlaying { viewModel.pauseGame() }
            else { viewModel.startGame() }
            return .handled
        }
        .onKeyPress(.return) {
            if viewModel.isGameOver { viewModel.restartGame() }
            return .handled
        }
        .onAppear { isFocused = true }
    }

    // MARK: - Board Canvas

    private var boardCanvas: some View {
        Canvas { context, size in
            // Cell fills width exactly; rows fill most of height
            let cell = size.width / CGFloat(viewModel.columns)
            let boardH = cell * CGFloat(viewModel.rows)
            let offsetY = (size.height - boardH) / 2

            // Fill full canvas with board background
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.boardBg))

            // Checkerboard
            for row in 0..<viewModel.rows {
                for col in 0..<viewModel.columns {
                    let rect = CGRect(x: CGFloat(col) * cell,
                                      y: offsetY + CGFloat(row) * cell,
                                      width: cell, height: cell)
                    let fill = (row + col).isMultiple(of: 2) ? theme.tileA : theme.tileB
                    context.fill(Path(rect), with: .color(fill))
                }
            }

            // Obstacles
            for obs in viewModel.obstacles {
                let rect = CGRect(x: CGFloat(obs.x) * cell + 0.5,
                                  y: offsetY + CGFloat(obs.y) * cell + 0.5,
                                  width: cell - 1, height: cell - 1)
                let path = Path(roundedRect: rect, cornerRadius: cell * 0.15)
                context.fill(path, with: .color(theme.obstacle))
                let midY = rect.midY
                context.stroke(
                    Path { p in p.move(to: CGPoint(x: rect.minX + 2, y: midY)); p.addLine(to: CGPoint(x: rect.maxX - 2, y: midY)) },
                    with: .color(theme.obstacleLine), lineWidth: 0.8
                )
            }

            // Power-ups
            for pu in viewModel.powerUpsOnBoard {
                let px = CGFloat(pu.position.x) * cell
                let py = offsetY + CGFloat(pu.position.y) * cell
                let inset: CGFloat = 1.5
                let orb = CGRect(x: px + inset, y: py + inset, width: cell - inset * 2, height: cell - inset * 2)
                let glowRect = orb.insetBy(dx: -2, dy: -2)
                context.fill(Path(ellipseIn: glowRect), with: .color(pu.type.color.opacity(0.3)))
                context.fill(Path(ellipseIn: orb), with: .color(pu.type.color))
                let dot = CGRect(x: orb.midX - 2, y: orb.minY + 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.7)))
            }

            // Snake body
            let snakeCount = viewModel.snake.count
            for i in stride(from: snakeCount - 1, through: 0, by: -1) {
                let p = viewModel.snake[i]
                let ratio = snakeCount > 1 ? Double(i) / Double(snakeCount - 1) : 0.0
                let color = interpolateColor(from: theme.snakeHead, to: theme.snakeTail, t: ratio)
                let gap: CGFloat = 0.5
                let rect = CGRect(x: CGFloat(p.x) * cell + gap,
                                  y: offsetY + CGFloat(p.y) * cell + gap,
                                  width: cell - gap * 2,
                                  height: cell - gap * 2)
                let corner: CGFloat = cell * 0.25
                let path = Path(roundedRect: rect, cornerRadius: corner)
                context.fill(path, with: .color(color))

                let hlRect = CGRect(x: rect.minX + rect.width * 0.15,
                                    y: rect.minY + 1,
                                    width: rect.width * 0.7,
                                    height: rect.height * 0.3)
                let hlPath = Path(roundedRect: hlRect, cornerRadius: corner * 0.5)
                context.fill(hlPath, with: .color(.white.opacity(0.15)))

                if i == 0 {
                    context.fill(path, with: .color(theme.snakeHead.opacity(0.2)))
                    drawEyes(in: &context, headRect: rect, direction: viewModel.currentDirection, cell: cell)
                }
            }

            // Food
            drawFood(in: &context, cell: cell, offsetX: 0, offsetY: offsetY)
        }
    }

    private func drawEyes(in context: inout GraphicsContext, headRect: CGRect, direction: Direction, cell: CGFloat) {
        let eyeRadius = cell * 0.13
        let pupilRadius = eyeRadius * 0.55

        let cx = headRect.midX
        let cy = headRect.midY

        var leftEye: CGPoint
        var rightEye: CGPoint
        var pupilOffset: CGPoint

        switch direction {
        case .up:
            leftEye  = CGPoint(x: cx - cell * 0.18, y: cy - cell * 0.12)
            rightEye = CGPoint(x: cx + cell * 0.18, y: cy - cell * 0.12)
            pupilOffset = CGPoint(x: 0, y: -pupilRadius * 0.4)
        case .down:
            leftEye  = CGPoint(x: cx - cell * 0.18, y: cy + cell * 0.12)
            rightEye = CGPoint(x: cx + cell * 0.18, y: cy + cell * 0.12)
            pupilOffset = CGPoint(x: 0, y: pupilRadius * 0.4)
        case .left:
            leftEye  = CGPoint(x: cx - cell * 0.12, y: cy - cell * 0.18)
            rightEye = CGPoint(x: cx - cell * 0.12, y: cy + cell * 0.18)
            pupilOffset = CGPoint(x: -pupilRadius * 0.4, y: 0)
        case .right:
            leftEye  = CGPoint(x: cx + cell * 0.12, y: cy - cell * 0.18)
            rightEye = CGPoint(x: cx + cell * 0.12, y: cy + cell * 0.18)
            pupilOffset = CGPoint(x: pupilRadius * 0.4, y: 0)
        }

        for eye in [leftEye, rightEye] {
            let whiteRect = CGRect(x: eye.x - eyeRadius, y: eye.y - eyeRadius,
                                   width: eyeRadius * 2, height: eyeRadius * 2)
            context.fill(Path(ellipseIn: whiteRect), with: .color(theme.snakeEyeWhite))
            let pupilRect = CGRect(x: eye.x + pupilOffset.x - pupilRadius,
                                   y: eye.y + pupilOffset.y - pupilRadius,
                                   width: pupilRadius * 2, height: pupilRadius * 2)
            context.fill(Path(ellipseIn: pupilRect), with: .color(theme.snakeEyePupil))
        }
    }

    private func drawFood(in context: inout GraphicsContext, cell: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let fp = viewModel.food
        let cx = offsetX + CGFloat(fp.x) * cell + cell / 2
        let cy = offsetY + CGFloat(fp.y) * cell + cell / 2
        let r = cell * 0.38

        // Body
        let bodyRect = CGRect(x: cx - r, y: cy - r * 0.85, width: r * 2, height: r * 1.85)
        context.fill(Path(ellipseIn: bodyRect), with: .color(theme.foodBody))

        // Highlight
        let hlRect = CGRect(x: cx - r * 0.45, y: cy - r * 0.8, width: r * 0.5, height: r * 0.5)
        context.fill(Path(ellipseIn: hlRect), with: .color(.white.opacity(0.35)))

        // Stem
        context.stroke(
            Path { p in
                p.move(to: CGPoint(x: cx, y: cy - r * 0.85))
                p.addLine(to: CGPoint(x: cx + r * 0.15, y: cy - r * 1.15))
            },
            with: .color(theme.foodStem), lineWidth: 1.5
        )

        // Leaf
        let leafPath = Path { p in
            p.move(to: CGPoint(x: cx + r * 0.15, y: cy - r * 1.1))
            p.addQuadCurve(to: CGPoint(x: cx + r * 0.55, y: cy - r * 1.25),
                           control: CGPoint(x: cx + r * 0.5, y: cy - r * 0.9))
            p.addQuadCurve(to: CGPoint(x: cx + r * 0.15, y: cy - r * 1.1),
                           control: CGPoint(x: cx + r * 0.2, y: cy - r * 1.35))
        }
        context.fill(leafPath, with: .color(theme.foodLeaf))
    }

    // MARK: - Header HUD

    private var headerHUD: some View {
        HStack(spacing: 8) {
            // Level badge with progress
            if viewModel.currentLevel.targetScore < .max {
                Text("\(viewModel.currentLevel.displayName) \(viewModel.levelScore)/\(viewModel.currentLevel.targetScore)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.accent.opacity(0.15), in: Capsule())
            } else {
                Text(viewModel.currentLevel.displayName)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.accent.opacity(0.15), in: Capsule())
            }

            Spacer()

            // Lives
            HStack(spacing: 3) {
                ForEach(0..<viewModel.maxLives, id: \.self) { i in
                    Image(systemName: i < viewModel.lives ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundStyle(i < viewModel.lives ? theme.heartFull : theme.heartEmpty)
                }
            }

            Spacer()

            // Score / High
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(viewModel.score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.hudText)
                Text("HI \(viewModel.highScore)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.hudDim)
            }
        }
    }

    // MARK: - Active Effects Bar

    private var effectsBar: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.activeEffects) { effect in
                HStack(spacing: 3) {
                    Text(effect.type.symbol)
                        .font(.system(size: 11))
                    Text(effect.type.label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(effect.type.color.opacity(0.3), in: Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: 12) {
            // D-pad
            dpad
                .frame(width: 130, height: 100)

            Spacer()

            // Action buttons
            VStack(spacing: 6) {
                pillButton(title: viewModel.isPlaying ? "Pause" : "Play") {
                    if viewModel.isPlaying { viewModel.pauseGame() }
                    else { viewModel.startGame() }
                }
                pillButton(title: "Restart") {
                    viewModel.restartGame()
                }
            }
        }
    }

    private var dpad: some View {
        let size: CGFloat = 32
        let gap: CGFloat = size * 1.08
        let isActive = viewModel.currentDirection

        return ZStack {
            // Up
            dpadButton(direction: .up, symbol: "chevron.up", isActive: isActive == .up, size: size)
                .offset(y: -gap)
            // Down
            dpadButton(direction: .down, symbol: "chevron.down", isActive: isActive == .down, size: size)
                .offset(y: gap)
            // Left
            dpadButton(direction: .left, symbol: "chevron.left", isActive: isActive == .left, size: size)
                .offset(x: -gap)
            // Right
            dpadButton(direction: .right, symbol: "chevron.right", isActive: isActive == .right, size: size)
                .offset(x: gap)
        }
    }

    private func dpadButton(direction: Direction, symbol: String, isActive: Bool, size: CGFloat) -> some View {
        Button {
            viewModel.changeDirection(direction)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: size, height: size)
                .background(isActive ? theme.dpadActive.opacity(0.3) : theme.dpadBg, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(isActive ? theme.dpadActive : theme.dpadArrow)
        }
    }

    private func pillButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(theme.pillText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(theme.pillBg, in: Capsule())
    }

    // MARK: - Level Up Banner

    private var levelUpBanner: some View {
        VStack(spacing: 4) {
            Text("\(viewModel.currentLevel.emoji) LEVEL \(viewModel.currentLevel.id)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.accent)
            Text(viewModel.currentLevel.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: theme.accent.opacity(0.4), radius: 12)
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 12) {
            if viewModel.isNewHighScore {
                Text("🏆")
                    .font(.system(size: 50))
                Text("NEW HIGH SCORE!")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.gold)
            } else {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.foodBody)
                Text("Game Over")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.hudText)
            }

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Score")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.hudDim)
                    Text("\(viewModel.score)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(viewModel.isNewHighScore ? theme.gold : theme.hudText)
                }
                VStack(spacing: 2) {
                    Text("Level")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.hudDim)
                    Text("\(viewModel.currentLevel.id)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.hudText)
                }
            }

            Button {
                viewModel.restartGame()
            } label: {
                Text("Play Again")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 4)

            Text("or press Space / Return")
                .font(.caption2)
                .foregroundStyle(theme.hudDim)
        }
        .padding(24)
        .frame(width: 260)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                if abs(h) > abs(v) {
                    viewModel.changeDirection(h > 0 ? .right : .left)
                } else {
                    viewModel.changeDirection(v > 0 ? .down : .up)
                }
            }
    }

    // MARK: - Color helpers

    private func configureGridOnce(screenSize: CGSize, safeTop: CGFloat, safeBot: CGFloat) {
        let headerEst: CGFloat = 44
        let controlsEst: CGFloat = 108
        let boardW = screenSize.width
        let boardH = screenSize.height - headerEst - controlsEst - safeTop - safeBot
        viewModel.configureGrid(boardWidth: boardW, boardHeight: boardH)
    }

    private func interpolateColor(from: Color, to: Color, t: Double) -> Color {
        let f = UIColor(from)
        let tC = UIColor(to)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        f.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        tC.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        let cg = CGFloat(t)
        return Color(red: Double(fr + (tr - fr) * cg),
                     green: Double(fg + (tg - fg) * cg),
                     blue: Double(fb + (tb - fb) * cg))
    }
}

#Preview {
    ContentView()
}
