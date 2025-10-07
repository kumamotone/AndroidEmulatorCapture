# AndroidEmulatorCapture

English | [日本語](README.ja.md)

A simple macOS menu bar app for capturing screen recordings and screenshots from Android emulators and devices.

## Features

### 📹 Screen Recording

- **Left-click** the menu bar icon to start/stop recording
- Recording files are automatically saved to `~/Desktop/EmulatorScreenRecords/`
- Filenames include automatic timestamps (e.g., `screenrecord_20241007_123456.mp4`)
- After recording stops, the file is automatically displayed in Finder and copied to clipboard

### 📸 Screenshot

- **Alt (Option) + Left-click** the menu bar icon to capture screenshot
- Screenshots are automatically saved to `~/Desktop/EmulatorScreenRecords/`
- Filenames include automatic timestamps (e.g., `screenshot_20241007_123456.png`)
- After capture, the file is automatically displayed in Finder and copied to clipboard

### 🔄 Device Selection

- **Right-click** the menu bar icon to display the menu
- Select from a list of connected Android devices/emulators
- Device model names are displayed

### ⚙️ Additional Features

- **Settings**: Select "Settings..." from the right-click menu
  - Change ADB path
  - Change save destination folder
- **Launch at Login**: Configurable from right-click menu
- **Launch Notification**: A notification appears below the menu bar when the app starts (5 seconds)

## Requirements

- macOS 13.0 or later
- Android SDK Platform Tools (adb) must be installed

## Installation

1. Open the project in Xcode
2. Build and run
3. The app will appear in the menu bar

## Usage

### Initial Setup

1. When the app launches, a recording icon appears in the menu bar
2. Open "Settings..." from the right-click menu and verify the ADB path (change if necessary)
3. Connect your Android emulator or device
4. Select your device from the right-click menu

### Controls

| Action | Function |
|--------|----------|
| **Left Click** | Start/Stop recording |
| **Alt + Left Click** | Capture screenshot |
| **Right Click** | Show menu |
| **⌘ + ,** (in Settings) | Open settings |

## Recording Indicator

The menu bar icon changes to a filled circle during recording:

- 🔴 Not recording: `record.circle`
- ⏺️ Recording: `record.circle.fill`

## Save Location

By default, all files are saved to the following directory:

```
~/Desktop/EmulatorScreenRecords/
```

The save location can be customized in the **Settings screen**. The directory will be created automatically if it doesn't exist.

## Settings Customization

Select "Settings..." from the right-click menu to customize the following:

### ADB Path

- Default: `~/Library/Android/sdk/platform-tools/adb`
- Use the "Choose..." button to select from file picker
- Can also be entered manually

### Save Destination Folder

- Default: `~/Desktop/EmulatorScreenRecords/`
- Use the "Choose..." button to select from folder picker
- Can also be entered manually

Settings are automatically saved and persist after app restart. You can also use the "Reset to Defaults" button to restore initial settings.

## Key Features

✅ **Simple & Intuitive** - One-click operation from menu bar  
✅ **Auto-Save** - Recordings and screenshots are automatically saved  
✅ **Clipboard Integration** - Files are automatically copied to clipboard  
✅ **Auto Finder Display** - Files are displayed in Finder immediately after saving  
✅ **Customizable** - Freely configure ADB path and save destination  
✅ **Multiple Device Support** - Switch between multiple devices/emulators  

## FAQ

### Q: Device is not displayed

**A:** Please check the following:

- Is the adb command installed correctly?
- Is the ADB path correct in the Settings screen?
- Is the Android device/emulator running?
- For USB connections, is USB debugging enabled?

### Q: Recordings/Screenshots are not being saved

**A:** Check the save destination folder path in the Settings screen. You need to specify a directory with write permissions.

### Q: Is there a recording time limit?

**A:** Due to Android's `screenrecord` command limitations, recording is limited to a maximum of 3 minutes.

### Q: Can I change the file format?

**A:** Currently, recordings are in MP4 format and screenshots are in PNG format (fixed).

## Troubleshooting

### adb command not found

1. Verify that Android Studio is installed
2. Verify that Android SDK Platform Tools are installed
3. Manually set the ADB path in the Settings screen

### Device list not updating

Select "Refresh Device List" (⌘R) from the device submenu in the right-click menu.

## Notes

- An alert will be displayed if no Android emulator or device is connected
- Recording files are temporarily saved on the emulator/device at `/sdcard/screenrecord1.mp4` and transferred to Mac after recording stops
- If the ADB path is incorrect, device detection and recording/screenshot features will not work

## License

MIT License

---

**Enjoy capturing! 🎬📱**
