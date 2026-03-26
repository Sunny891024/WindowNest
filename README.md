# WindowNest

WindowNest is an original macOS window snapping utility built from scratch in SwiftUI and AppKit.

## Current MVP

- Menu bar app with a companion window
- Accessibility permission prompt and shortcut to System Settings
- Layout presets for the currently focused window
- Support for maximize, halves, quarters, and a centered layout
- Global shortcuts for the most common layouts
- Launch at login toggle for bundled app runs

## Open in Xcode

1. Open `Package.swift` in Xcode.
2. Run the `WindowNest` executable target.
3. Grant Accessibility access when macOS prompts you.

## Notes

- This project intentionally does not copy proprietary assets or protected implementation details from other apps.
- The current build environment in this workspace has a local Swift toolchain and SDK mismatch, so command-line compilation could not be fully verified here.
- Launch at login requires running WindowNest as an actual app bundle rather than only from a bare SwiftPM executable.
