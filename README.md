# Camera2URL [![macOS CI](https://github.com/manuelkiessling/camera2url/actions/workflows/macos-ci.yml/badge.svg?branch=main)](https://github.com/manuelkiessling/camera2url/actions/workflows/macos-ci.yml) [![iOS CI](https://github.com/manuelkiessling/camera2url/actions/workflows/ios-ci.yml/badge.svg?branch=main)](https://github.com/manuelkiessling/camera2url/actions/workflows/ios-ci.yml)

Camera2URL is a Swift app suite that allows users to capture still images from Apple device cameras
and upload them to configurable HTTP endpoints. The repository hosts code for two platforms:

- `macos/` – the macOS desktop app. See [the macOS README](macos/README.md) for full usage, build, and testing instructions.
- `ios/` – the iOS counterpart for iPhone and iPad. See [the iOS README](ios/README.md) for details.

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
