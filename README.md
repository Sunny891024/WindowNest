# WindowNest

WindowNest is a private macOS menu bar app for arranging windows by dragging them onto a simple floating layout board.

## What It Does

- Shows a centered floating layout board while you drag a window
- Lets you drop onto three layout groups: `左 / 右屏`, `全屏`, `上 / 下屏`
- Supports one-click manual layouts from the menu bar as a fallback
- Includes launch-at-login support
- Uses Accessibility and Input Monitoring permissions for cross-app window control

## Current Direction

This project is intentionally built as an original product. It does not copy proprietary code or protected assets from other apps.

The current product direction is:

- Drag first
- Menu bar only
- Chinese-first UI
- Minimal setup and fast window snapping

## Run The App

1. Open [WindowNest.xcodeproj](/Users/sunny/本地文件/Codex/WindowNest/WindowNest.xcodeproj) in Xcode.
2. Build and run the `WindowNest` target.
3. Grant `辅助功能` and `输入监控` to the built app.
4. Drag a window and move it onto the floating layout board.

For local installs outside Xcode, the app bundle can also be copied to:

- [WindowNest.app](/Applications/WindowNest.app)

## Notes

- Bundle identifier: `com.windownest.app`
- Recommended for testing: the Xcode-built app or the installed `/Applications/WindowNest.app`
- The repository still contains earlier prototype pieces, but active testing should focus on the Xcode app target
