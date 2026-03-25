# SnakeGame

Minimal iPhone Snake game built with SwiftUI.

## Open and run

1. Open `SnakeGame.xcodeproj` in Xcode.
2. If Xcode prompts for first-launch setup or license acceptance, complete that once on this Mac.
3. Choose an iPhone Simulator such as `iPhone 16`.
4. Press `Run`.

## Command-line build

List valid destinations first:

```bash
cd /Users/rahul/Documents/Repo/AppTest
xcodebuild -showdestinations -project SnakeGame.xcodeproj -scheme SnakeGame
```

Then build with one of the listed simulator names, for example:

```bash
cd /Users/rahul/Documents/Repo/AppTest
xcodebuild -project SnakeGame.xcodeproj -scheme SnakeGame -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Controls

- Swipe on the board to steer.
- Or use the on-screen arrow buttons.
- `Pause` stops the timer.
- `Restart` starts a fresh run.