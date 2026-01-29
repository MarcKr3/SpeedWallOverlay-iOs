# Camera Overlay App

A calibrated camera overlay app for iOS that lets users place a template image over the camera feed at real-world scale.

## Features

- **Real-world calibration**: Tap two points of a known distance to calibrate the app
- **Tall template support**: Scroll through an 800x4000px template image
- **Section selection**: Choose which portion of the template to overlay
- **Adjustable overlay**: Control opacity, scale, and position
- **Broad device support**: Works on iPhone 8 and later (no ARKit required)

## Project Setup

### 1. Create Xcode Project

1. Open Xcode
2. Create a new project: **File → New → Project**
3. Select **iOS → App**
4. Configure:
   - Product Name: `CameraOverlayApp`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployment: **iOS 16.0** (or your preference)

### 2. Add Source Files

Copy all `.swift` files from this folder into your Xcode project:
- `CameraOverlayApp.swift` - App entry point
- `AppState.swift` - State management
- `CameraManager.swift` - AVFoundation camera handling
- `ContentView.swift` - Main view controller
- `CalibrationView.swift` - Calibration UI
- `TemplateSelectionView.swift` - Template browser
- `OverlayView.swift` - Main overlay mode

### 3. Configure Info.plist

Add camera permission to your project's Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to display the live preview and overlay your template guide.</string>
```

Or in Xcode: Target → Info → add "Privacy - Camera Usage Description"

### 4. Add Your Template Image

1. Add your 800x4000px template image to Assets.xcassets
2. Name it `template`
3. The app will automatically use it

If no image is added, a placeholder gradient will be shown.

## Usage Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      CALIBRATION MODE                           │
│                                                                 │
│  1. Point camera at a known distance (e.g., a 1-meter ruler)   │
│  2. Tap the START of the known distance                        │
│  3. Tap the END of the known distance                          │
│  4. Enter the actual distance (supports m, cm, in, ft)         │
│  5. Tap "Continue"                                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   TEMPLATE SELECTION MODE                       │
│                                                                 │
│  1. View your full template image on the left                  │
│  2. Use the slider to scroll through the template              │
│  3. Adjust the selection window size                           │
│  4. Set the real-world height the template should represent    │
│  5. Adjust overlay opacity                                      │
│  6. Tap "Start Overlay"                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       OVERLAY MODE                              │
│                                                                 │
│  • Drag to reposition the overlay                              │
│  • Pinch to scale                                              │
│  • Use slider to scroll through template                       │
│  • Adjust opacity and scale with controls                      │
│  • Double-tap to hide/show controls                            │
│  • Tap back arrow to return to template selection              │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                           AppState                               │
│  • Calibration data (pixels per meter)                          │
│  • Template scroll position                                      │
│  • Overlay settings (opacity, scale)                            │
│  • Mode management                                               │
└──────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ↓                   ↓                   ↓
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ CalibrationView │  │TemplateSelect.. │  │   OverlayView   │
│                 │  │                 │  │                 │
│ • Tap handlers  │  │ • Image browser │  │ • Overlay render│
│ • Point markers │  │ • Section select│  │ • Drag/pinch    │
│ • Distance input│  │ • Settings      │  │ • Controls      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
                              │
                              ↓
                    ┌─────────────────┐
                    │  CameraManager  │
                    │                 │
                    │ • AVFoundation  │
                    │ • Session mgmt  │
                    │ • Preview layer │
                    └─────────────────┘
```

## Customization

### Template Image Size

To change the expected template dimensions, modify these constants in:
- `TemplateSelectionView.swift`
- `OverlayView.swift`

```swift
private let templateWidth: CGFloat = 800
private let templateHeight: CGFloat = 4000
```

### Calibration Units

The app supports meters, centimeters, inches, and feet. To add more units, modify `CalibrationView.DistanceUnit`:

```swift
enum DistanceUnit: String, CaseIterable {
    case meters = "m"
    case centimeters = "cm"
    // Add more cases here
    
    func toMeters(_ value: Double) -> Double {
        // Add conversion logic
    }
}
```

### Overlay Appearance

Modify the overlay border and appearance in `OverlayView.swift`:

```swift
.border(Color.yellow.opacity(0.5), width: 2)
```

## Device Compatibility

| Device | Supported | Notes |
|--------|-----------|-------|
| iPhone 8+ | ✅ | Full support |
| iPhone SE (2nd+) | ✅ | Full support |
| iPad (6th gen+) | ✅ | Full support |
| iPhone 7 and earlier | ⚠️ | May work, not tested |

The app uses AVFoundation (not ARKit), so it works on any device with a camera running iOS 16+.

## Troubleshooting

### Camera not showing
- Check that camera permission was granted in Settings
- Ensure the app has the correct `NSCameraUsageDescription` in Info.plist

### Calibration seems off
- Ensure both calibration points are clearly visible on screen
- Use a longer reference distance for better accuracy
- Recalibrate if you change distance from the subject

### Template not loading
- Verify the image is named `template` in Assets.xcassets
- Check that the image format is supported (PNG, JPEG)

## Future Enhancements

- [ ] Save/load calibration profiles
- [ ] Multiple template support
- [ ] Grid overlay option
- [ ] Measurement tools
- [ ] Photo capture with overlay
- [ ] ARKit mode for supported devices (3D tracking)

## License

MIT License - Use freely for personal or commercial projects.
