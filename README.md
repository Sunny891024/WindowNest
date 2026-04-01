# WindowNest

WindowNest is a lightweight macOS menu bar app that helps you snap and organize windows with a floating layout board.

When you drag a window, WindowNest shows three large targets on the current screen so you can quickly drop the window into `Left / Right`, `Maximize`, or `Top / Bottom`.

## English

WindowNest is built for people who want faster window management on macOS without a heavy or complicated interface. It lives quietly in the menu bar and focuses on a drag-first experience: start dragging a window, move it onto one of the floating layout targets, and release to snap it into place.

The app currently supports `Left / Right`, `Maximize`, and `Top / Bottom` layouts, with support for multi-display workflows, launch at login, and a lightweight native macOS interface.

## 中文介绍

WindowNest 是一款轻量的 macOS 菜单栏应用，帮助你通过浮动布局板快速整理窗口。它专注于直观、轻巧的拖动式体验，不依赖复杂笨重的界面，而是让你在开始拖动窗口时，直接看到清晰的布局目标区。

当前版本支持 `左 / 右半屏`、`全屏`、`上 / 下半屏` 三组布局，并支持多显示器场景、开机启动，以及原生 macOS 风格的轻量界面。

## Highlights

- Drag-first window snapping with a centered floating layout board
- Works across multiple displays
- Menu bar quick actions for manual fallback layouts
- Launch at login support
- English, Simplified Chinese, and Traditional Chinese UI
- Minimal, native macOS interface built with SwiftUI and AppKit

## How It Works

1. Start dragging a window from its title bar area.
2. WindowNest shows three layout targets on the active screen.
3. Move the pointer onto the target you want.
4. Release the mouse to snap the window into place.

The three target groups are:

- `Left / Right`
- `Maximize`
- `Top / Bottom`

## Installation

The easiest way to install WindowNest is with the packaged DMG.

Installer files are written to `dist` with the app version in the filename, for example:

- `dist/WindowNest-0.4.4-Installer.dmg`
- `dist/WindowNest-0.4.4-macOS.zip`

Open the DMG and drag `WindowNest.app` into `Applications`.

You can also run the installed app directly from:

- [WindowNest.app](/Applications/WindowNest.app)

## Permissions

WindowNest needs these macOS permissions to control other apps' windows:

- `Accessibility`
- `Input Monitoring`

Grant both permissions to `WindowNest.app` in `System Settings -> Privacy & Security`.

## Development

1. Open [WindowNest.xcodeproj](/Users/sunny/本地文件/Codex/WindowNest/WindowNest.xcodeproj) in Xcode.
2. Build and run the `WindowNest` target.
3. Grant the required permissions to the built app.
4. Drag a window to test the floating layout board.

## Product Notes

- Bundle identifier: `com.windownest.app`
- App name stays `WindowNest` in every supported language
- The product is intentionally original and does not copy proprietary code or assets from other apps
