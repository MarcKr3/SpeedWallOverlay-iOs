# SpeedWall Overlay

An iOS app that overlays a climbing route template onto a live camera feed at real-world scale. Calibrate with a known distance, pick a section of your route image, and see it projected onto the wall in front of you.

## Features

- **Two-point calibration** — tap two points of a known distance (m, cm, in, ft) to establish real-world scale
- **Template overlay** — display a section of a tall route image over the camera feed
- **Perspective tilt** — horizontal/vertical 3D tilt controls with optional auto-level via device motion
- **Overlay controls** — toggle grid and label layers, pick overlay color, drag to reposition
- **Screenshot capture** — save the camera + overlay composite to your photo library
- **No ARKit required** — works on any iOS device with a camera (iPhone 8+, iPad 6th gen+)

## Requirements

- iOS 15.6+
- Xcode 15+
- Camera and photo library permissions (configured in Info.plist)

## Build & Run

1. Clone the repo
2. Open `SpeedWall Overlay.xcodeproj` in Xcode
3. Add your route template image to `Assets.xcassets` named `template` (a placeholder gradient is used if omitted)
4. Build and run on a physical device (camera requires a real device)

## Usage

1. **Calibrate** — point the camera at a reference of known length, tap both ends, enter the distance
2. **Overlay** — the template appears over the camera feed; drag to reposition, use controls to adjust tilt, color, and layer visibility
3. **Screenshot** — tap the camera button to save the current view

## License

MIT
