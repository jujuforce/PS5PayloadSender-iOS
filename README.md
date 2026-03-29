<p align="center">
  <img src="PS5PayloadSender/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="128" height="128" alt="PS5 Payload Sender" />
</p>

<h1 align="center">PS5 Payload Sender</h1>

<p align="center">
  Send <code>.elf</code> and <code>.lua</code> payloads to your PS5 from your iPhone or Mac.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-15%2B-blue" />
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-6-orange" />
  <img src="https://img.shields.io/badge/license-MIT-green" />
</p>

## Screenshots

<p align="center">
  <img src="screenshots/main.png" width="200" alt="Dark mode" />
  &nbsp;&nbsp;
  <img src="screenshots/main_light.png" width="200" alt="Light mode" />
  &nbsp;&nbsp;
  <img src="screenshots/mac.png" width="340" alt="macOS" />
</p>

## What It Does

Sends payload files to your PS5 over Wi-Fi using a raw TCP connection. Works with `.lua` (port 9026) and `.elf` (port 9021) files.

Load your payloads from **Dropbox**, **iCloud Drive**, **Google Drive**, or any folder visible in the Files app. Also runs natively on macOS 13+ via Mac Catalyst.

## Installation

### iOS — TrollStore (no PC, no Apple account)

Download `PS5PayloadSender.ipa` from the [Releases](https://github.com/jujuforce/PS5PayloadSender-iOS/releases) page and install with [TrollStore](https://github.com/opa334/TrollStore), Sideloadly, or AltStore.

### macOS

Download `PS5PayloadSender-macOS.zip`, unzip, and move to your Applications folder. On first launch **right-click → Open** to bypass Gatekeeper (ad-hoc signed, not notarized).

### Build yourself

```bash
git clone https://github.com/jujuforce/PS5PayloadSender-iOS.git
cd PS5PayloadSender
cp Local.xcconfig.template Local.xcconfig
```

Edit `Local.xcconfig`:
```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.PS5PayloadSender
```

Open `PS5PayloadSender.xcodeproj` in Xcode, build & run on your device or Mac.

## Usage

1. Select a folder with your payload files (first launch only)
2. Enter your PS5's IP address
3. Tap a payload, then **Send**

The port updates automatically based on file type (`.lua` → `9026`, `.elf` → `9021`). You can override it manually if needed.

## License

[MIT](LICENSE)
