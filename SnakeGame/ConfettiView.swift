import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var startTime: Date?
    @State private var isFinished = false
    private let duration: Double = 3.5
    private let count = 100

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard !isFinished, let start = startTime else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                if elapsed > duration {
                    DispatchQueue.main.async { isFinished = true }
                    return
                }

                let fade = elapsed > duration - 0.8
                    ? max(0, 1.0 - (elapsed - (duration - 0.8)) / 0.8)
                    : 1.0

                for p in particles {
                    let t = elapsed
                    let x = p.startX * size.width + p.driftX * CGFloat(t)
                    let y = p.startY + CGFloat(t * t) * p.gravity + p.velocityY * CGFloat(t)
                    let rotation = Angle.degrees(p.spin * t)

                    guard x > -20 && x < size.width + 20 && y < size.height + 20 else { continue }

                    var ctx = context
                    ctx.opacity = fade * p.opacity
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rotation)

                    let rect = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)
                    switch p.shape {
                    case 0:
                        ctx.fill(Path(rect), with: .color(p.color))
                    case 1:
                        ctx.fill(Path(ellipseIn: rect), with: .color(p.color))
                    default:
                        var tri = Path()
                        tri.move(to: CGPoint(x: 0, y: -p.h / 2))
                        tri.addLine(to: CGPoint(x: p.w / 2, y: p.h / 2))
                        tri.addLine(to: CGPoint(x: -p.w / 2, y: p.h / 2))
                        tri.closeSubpath()
                        ctx.fill(tri, with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startTime = Date()
            particles = (0..<count).map { _ in ConfettiParticle.random() }
        }
    }
}

private struct ConfettiParticle {
    let startX: CGFloat      // 0–1 fraction of width
    let startY: CGFloat      // pixels (starts above screen)
    let velocityY: CGFloat
    let driftX: CGFloat
    let gravity: CGFloat
    let spin: Double          // degrees per second
    let w: CGFloat
    let h: CGFloat
    let color: Color
    let opacity: Double
    let shape: Int            // 0=rect, 1=circle, 2=triangle

    static func random() -> ConfettiParticle {
        let colors: [Color] = [
            .red, .blue, .green, .yellow, .purple, .pink, .orange,
            Color(red: 1, green: 0.84, blue: 0), // gold
            Color(red: 0.3, green: 0.9, blue: 0.4), // lime
        ]
        return ConfettiParticle(
            startX: CGFloat.random(in: 0...1),
            startY: CGFloat.random(in: -80...(-10)),
            velocityY: CGFloat.random(in: 60...160),
            driftX: CGFloat.random(in: -40...40),
            gravity: CGFloat.random(in: 30...70),
            spin: Double.random(in: -360...360),
            w: CGFloat.random(in: 5...12),
            h: CGFloat.random(in: 8...16),
            color: colors.randomElement()!,
            opacity: Double.random(in: 0.7...1.0),
            shape: Int.random(in: 0...2)
        )
    }
}
