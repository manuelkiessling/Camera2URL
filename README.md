# Camera2URL [![macOS CI](https://github.com/manuelkiessling/camera2url/actions/workflows/macos-ci.yml/badge.svg?branch=main)](https://github.com/manuelkiessling/camera2url/actions/workflows/macos-ci.yml) [![iOS CI](https://github.com/manuelkiessling/camera2url/actions/workflows/ios-ci.yml/badge.svg?branch=main)](https://github.com/manuelkiessling/camera2url/actions/workflows/ios-ci.yml)

[![Download the iOS version on the App Store](https://raw.githubusercontent.com/manuelkiessling/gh-assets/refs/heads/main/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg)](https://apps.apple.com/app/camera2url/id6756015636)

Camera2URL is a Swift app suite that allows users to capture still images from Apple device cameras
and upload them to configurable HTTP endpoints. The repository hosts code for two platforms:

- `macos/` – the macOS desktop app. See [the macOS README](macos/README.md) for full usage, build, and testing instructions.
- `ios/` – the iOS counterpart for iPhone and iPad. See [the iOS README](ios/README.md) for details.

## Demo video

The below video shows how Camera2URL can be used to trigger an n8n workflow by immediately posting images to the n8n Webhook node endpoint URL: 

[![Camera2URL n8n demo video](https://raw.githubusercontent.com/manuelkiessling/gh-assets/refs/heads/main/Camera2URL-demo-video-screenshot.png)](https://www.youtube.com/watch?v=Y5nCw8NY8zk)

## Quick Start

### Build and test the macOS app

```bash
cd macos
make build
make test
```

Additional commands (UI tests, quality targets, etc.) are documented in `macos/README.md`.

### Build and test the iOS app

```bash
cd ios
make build
make test
```

Refer to `ios/README.md` for simulator setup, UI tests, and quality targets.

## License

See `LICENSE.txt` for licensing details.
