# DockDrop

DockDrop is a macOS menu bar app that shows a floating app shelf while you drag files, then activates target apps when you hover their icon.

## Implemented MVP

- Global drag detection for file drags
- Floating non-activating shelf window
- Running-app icon provider
- Hover-to-activate with configurable delay
- Accessibility onboarding
- Settings window (position, delay, drag mode, icon size, labels, launch-at-login, appearance)

## Build

```bash
swift build
swift run DockDrop
```

## Notes

- Global monitoring and activation behavior depends on Accessibility permission.
- Launch-at-login uses `SMAppService.mainApp` and works best from a bundled app.
