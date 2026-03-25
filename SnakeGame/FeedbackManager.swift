import UIKit
import AudioToolbox

@MainActor
final class FeedbackManager {
    static let shared = FeedbackManager()

    private let lightImpact  = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact  = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }

    func playEat() {
        lightImpact.impactOccurred()
        AudioServicesPlaySystemSound(1104) // short pop
    }

    func playPowerUp() {
        mediumImpact.impactOccurred()
        AudioServicesPlaySystemSound(1025) // short chime
    }

    func playDie() {
        heavyImpact.impactOccurred()
        AudioServicesPlaySystemSound(1521) // heavy buzz
    }

    func playLevelUp() {
        notification.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1111) // success
    }

    func playHighScore() {
        notification.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1111)
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            AudioServicesPlaySystemSound(1111)
            try? await Task.sleep(for: .milliseconds(200))
            AudioServicesPlaySystemSound(1025)
        }
    }
}
