<img src="Other/Readme/Logo.png" width="110" height="110"/>

# SpoofDPI App

A simple **macOS** menu-bar app that bypasses Deep Packet Inspection (DPI) so blocked or throttled sites (e.g. **YouTube**) work normally again. It is a thin GUI around the [SpoofDPI](https://github.com/xvzc/SpoofDPI) proxy by [@xvzc](https://github.com/xvzc).

> This is a personal fork of [SpoofDPIApp/SpoofDPI-App](https://github.com/SpoofDPIApp/SpoofDPI-App), updated to SpoofDPI **1.5.4**, trimmed to **Apple Silicon only**, without Firebase analytics, and built locally with ad-hoc signing.

## How it works

The app bundles the SpoofDPI binary for Apple Silicon. When protection is enabled it launches it as a local HTTP proxy (`127.0.0.1:8080`) and lets SpoofDPI configure the macOS system proxy. A watchdog restarts the proxy if it exits; disabling protection or quitting the app stops it and restores the network settings.

The window can be closed — the app keeps running behind the glasses icon in the menu bar.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon Mac (M1 or newer)
- To build: Xcode 16+, [GitHub CLI](https://cli.github.com) (`gh`, only for `make update-core`)

## Build

```sh
make            # build (arm64) → re-sign ad-hoc → dist/SpoofDPI.App.zip
make run        # build, sign and launch dist/SpoofDPI App.app
make help       # list all targets
```

| Target | Description |
| --- | --- |
| `build` | Release build with `xcodebuild`, unsigned, into `build/` |
| `dist` | Copy the app into `dist/` |
| `sign` | Re-sign `dist/SpoofDPI App.app` (inside-out) and verify |
| `zip` | Create `dist/SpoofDPI.App.zip` |
| `update-core` | Download a SpoofDPI release, verify checksums, replace the embedded binaries |
| `core-version` | Print the embedded SpoofDPI version |
| `clean` | Remove `build/` and `dist/` |

### Signing

By default the app is signed **ad-hoc** (`SIGN_IDENTITY=-`). To use a self-signed certificate from your Keychain (keeps the signature stable across rebuilds, so macOS permissions persist):

```sh
make sign SIGN_IDENTITY="My Self-Signed Cert"
```

Extra `codesign` flags can be passed through `SIGN_FLAGS`, e.g. `SIGN_FLAGS="--options runtime"`.

### Updating SpoofDPI

```sh
make update-core                     # latest release
make update-core CORE_VERSION=1.5.4  # specific version
```

This updates `SpoofDPI App/Other/Binaries/spoofdpi-arm` and `Constants.libraryVersion`. Check the upstream changelog for CLI changes — the app always passes `--no-tui --auto-configure-network` (see `Constants.libraryDefaultParameters`).

## Install

1. Run `make`, then unzip `dist/SpoofDPI.App.zip` (or copy `dist/SpoofDPI App.app`) into `/Applications`.
2. First launch: right-click the app → **Open** → confirm. Ad-hoc signed apps are not notarized, so a plain double-click is blocked the first time.
3. If macOS still refuses to open it, remove the quarantine flag:

   ```sh
   xattr -dr com.apple.quarantine "/Applications/SpoofDPI App.app"
   ```

## Custom parameters

The gear button → *SpoofDPI launch parameters* accepts extra SpoofDPI flags, appended after the defaults. Examples:

```
--https-split-mode chunk --https-chunk-size 1
--dns-mode https
--https-disorder
```

Run `"SpoofDPI App/Other/Binaries/spoofdpi-arm" --help` or see the [SpoofDPI docs](https://spoofdpi.xvzc.dev) for all options.

> **Upgrading from 0.x:** old flags such as `-window-size`, `-enable-doh` or `-system-proxy` no longer exist. Parameters saved with an older version are cleared automatically on first launch.

## Credits

- [SpoofDPI](https://github.com/xvzc/SpoofDPI) by @xvzc — the core proxy (Apache-2.0)
- [SpoofDPI App](https://github.com/SpoofDPIApp/SpoofDPI-App) — the original macOS app
