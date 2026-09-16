# Baby Lights 💡

A minimalist app designed for everyday situations when a small baby grabs a parent's phone. Instead of clicking notifications, accidentally uninstalling apps, sending messages, or opening social media, the baby sees only a black screen that responds to touch with gentle, calming lights.

Baby Lights provides a simple, distraction-free visual experience. When a baby touches the screen, a soft glow appears and disappears after a few seconds. The app is intentionally not very engaging - it's something very simple that babies should get bored with relatively quickly, encouraging them to move on to other activities.

## Key Features

- **Black screen with touch-responsive lights** - gentle glows that appear and fade on touch
- **Immersive sticky mode** with key suppression on Android to prevent accidental exits
- **Parental safety controls** - hidden exit mechanism (press top-left and bottom-right corners simultaneously for 0.5 seconds)
- **Zero data collection** - completely private and secure
- **No sounds, ads, or tracking** - truly distraction-free experience
- **Screen pinning** prevents accidental app switching or system access

## Screenshots

<div align="center">

### Splash Screen
<img src="screenshots/splash-screen.jpg" alt="App splash screen" width="300">

### Main Screen
<img src="screenshots/first-screen.jpg" alt="Baby Lights main screen" width="300">


### Immersive Mode
<img src="screenshots/immersive-mode.jpg" alt="Full-screen immersive mode" width="300">

### Shader Effects
<img src="screenshots/shader-example-1.jpg" alt="Gentle touch responsive lights" width="300">
<img src="screenshots/shader-example-2.jpg" alt="Soft glows on black background" width="300">


### About Screen
<img src="screenshots/about-screen.jpg" alt="About screen with app information" width="300">
</div>

## Installation

### Prerequisites

- UV: https://docs.astral.sh/uv/getting-started/installation/

### Development Setup

1. Clone the repository:
```bash
git clone https://github.com/FilipeMarch/baby-lights
cd baby-lights
```

2. Use Python 3.13 and install the project dependencies:
```bash
uv sync
```

To run the desktop development version with hot reload:

```bash
uv run main.py
```

The packaged `baby_lights` entry point uses plain Kivy by default. To run the
desktop launcher with the production app base for a local smoke test:

```bash
BABY_LIGHTS_MODE=production uv run main.py
```

### Building for Android

The primary Android build path uses `ksproject`, which generates a native Gradle project and targets Android API 36:

```bash
uv run ksproject android build
```

For a Google Play App Bundle:

```bash
uv run ksproject android build release --bundle
```

The output is written to `project_dist/gradle/app/build/outputs/bundle/release/app-release.aab`.

To install and launch the debug build on an emulator or USB device:

```bash
uv run ksproject android devices
uv run ksproject android run --uuid DEVICE_SERIAL
```

`buildozer.spec` is retained as a legacy fallback and is also configured for API 36.

## Usage

### For Parents

1. **Starting the app**: Tap the "START" button to enter safe mode
2. **Safety confirmation**: The app will explain the exit mechanism before starting
3. **Giving to baby**: Hand the device to your child - they will see only a black screen
4. **Touch interaction**: Baby touches create gentle glows that fade after a few seconds
5. **Exiting safely**: Press and hold both top-left AND bottom-right corners for 0.5 seconds

### The Problem Baby Lights Solves

When a small baby grabs your phone, they typically:
- Click on notifications
- Accidentally uninstall apps
- Send random messages
- Open social media apps
- Access system settings

**Baby Lights prevents all of this** by showing only a black screen with gentle touch responses.

### For Developers

The app uses a modular architecture:

- `baby_lights/app.py` - Main application class (BabyLightsApp)
- `baby_lights/screens/` - Implementation of Main and Shader screens
- `baby_lights/uix/` - Custom UI components (BabyButton, ShaderCanvas)
- `baby_lights/android_utils.py` - Android-specific integrations
- `baby_lights/popups/` - Popup dialogs and confirmations

## Technical Details

### Architecture

- **Framework**: Kivy with Python
- **Graphics**: OpenGL ES shaders for smooth animations
- **Platform Integration**: PyJnius for Android native API access
- **Build System**: ksproject with native Gradle and CPython-for-Android

### Android Integration

The app heavily integrates with Android's native UI system:

- **Edge-to-edge display** using `WindowInsetsController` (API 30+)
- **System bar management** for immersive experience
- **Screen pinning** to prevent task switching

### Shader System

Simple, gentle visual effects:
- Touch-responsive soft glows
- Smooth fade-out animations
- Calming visual patterns on black background
- Optimized for mobile GPUs

## Safety & Privacy

- **No network access** - completely offline
- **No data collection** - no analytics or tracking
- **No external dependencies** at runtime
- **Parental controls** built-in for safe usage
- **Screen pinning** prevents accidental system access
- **Black screen protection** - prevents accidental app interactions
- **Intentionally brief engagement** - designed to be interesting for only a few seconds ~ minutes, encouraging babies to move on to physical toys

## Development

### Project Structure

```
baby-lights/
├── main.py                # Entry point
├── buildozer.spec         # Legacy Android build configuration
├── AndroidManifest.tmpl.xml # ksproject manifest template
├── build.tmpl.gradle.kts  # ksproject Gradle template
├── wheelhouse/             # Local platform wheel repository
├── pyproject.toml         # Python project configuration
├── baby_lights/
│   ├── app.py            # Main application
│   ├── android_utils.py  # Android integration
│   ├── logger.py         # Logging utilities
│   ├── popups/           # Dialog systems
│   ├── screens/          # Screen management
│   │   ├── main_screen.py
│   │   ├── shader_screen.py
│   │   └── *.kv          # Kivy layout files
│   └── uix/              # Custom UI components
│       └── baby_button.py
└── bin/                  # Build outputs
```

### Key Dependencies

- **Kivy**: Cross-platform UI framework
- **PyJnius**: Python-Java bridge for Android
- **Kivy Reloader**: Hot reload during development
- **ksproject**: Native Gradle Android build tool
- **Buildozer**: Legacy Android build fallback

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both desktop and Android
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Designed for everyday situations when babies grab phones
- Safety and simplicity in mind for babies aged 6-24 months
- Inspired by the need for truly safe, distraction-free baby apps
- Built to prevent accidental system interactions and app usage
- Focused on gentle, calming visual responses rather than stimulating content
- Intentionally designed for brief engagement to encourage transition to physical toys
- Built using the Kivy framework and modern Android APIs

## Support

For issues, questions, or contributions, please open an issue on the project repository.

---

**⚠️ Parental Supervision Recommended**: While designed to be safe, always supervise young children when using electronic devices.
