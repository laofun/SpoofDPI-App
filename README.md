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
make            # build (arm64) → re-sign → dist/SpoofDPI.App.zip
make install    # build, sign, replace /Applications/SpoofDPI App.app and relaunch
make help       # list all targets
```

| Target | Description |
| --- | --- |
| `build` | Release build with `xcodebuild`, unsigned, into `build/` |
| `dist` | Copy the app into `dist/` |
| `sign` | Re-sign `dist/SpoofDPI App.app` (inside-out) and verify |
| `zip` | Create `dist/SpoofDPI.App.zip` |
| `run` | Launch the signed app from `dist/` |
| `install` / `uninstall` | Quit the running app, then install into / remove from `/Applications` |
| `bump` | Increment the build number in the project and `Other/ActualBuildNumber.txt` |
| `version` | Print app version, build number and embedded SpoofDPI version |
| `check-core` | Check whether a newer SpoofDPI release exists |
| `update-core` | Download a SpoofDPI release, verify checksums, replace the embedded binary |
| `upgrade` | `update-core` + `install` |
| `proxy-reset` | Turn off the system proxy on all network services (after a crash) |
| `clean` | Remove `build/` and `dist/` |

### Signing

The app is signed with the self-signed Keychain identity **`SpoofDPI Local`** when it exists, otherwise ad-hoc (a stable signature across rebuilds, so the login item and macOS permissions persist). Create it once in Keychain Access → Certificate Assistant → Create a Certificate… (Identity Type: *Self Signed Root*, Certificate Type: *Code Signing*).

To force ad-hoc signing:

```sh
make SIGN_IDENTITY=-
```

Extra `codesign` flags can be passed through `SIGN_FLAGS`, e.g. `SIGN_FLAGS="--options runtime"`.

### Updating SpoofDPI

The app checks the latest SpoofDPI release every 3 days (and via *Check for Updates*) and shows an alert when a newer core is out. Then run:

```sh
make upgrade                         # latest core → rebuild → reinstall into /Applications
make check-core                      # just check (exit 1 if a newer release exists)
make update-core CORE_VERSION=1.5.4  # pin a specific version, without installing
```

This updates `SpoofDPI App/Other/Binaries/spoofdpi-arm` and `Constants.libraryVersion`. Check the upstream changelog for CLI changes — the app always passes `--no-tui --auto-configure-network` (see `Constants.libraryDefaultParameters`).

## Install

1. Run `make install` (or unzip `dist/SpoofDPI.App.zip` into `/Applications`).
2. First launch: right-click the app → **Open** → confirm. Locally signed apps are not notarized, so a plain double-click may be blocked the first time.
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
