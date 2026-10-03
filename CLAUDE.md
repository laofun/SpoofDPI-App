# CLAUDE.md

Personal fork of [SpoofDPIApp/SpoofDPI-App](https://github.com/SpoofDPIApp/SpoofDPI-App) (remote `upstream`; `origin` = laofun/SpoofDPI-App). macOS 13+ SwiftUI menu-bar app wrapping the [xvzc/SpoofDPI](https://github.com/xvzc/SpoofDPI) Go proxy.

## Commands

```sh
make            # xcodebuild Release (arm64 only, unsigned) → re-sign in dist/ → dist/SpoofDPI.App.zip
make SIGN_IDENTITY=-                  # ad-hoc instead of the default "SpoofDPI Local" identity
make update-core [CORE_VERSION=x.y.z] # replace embedded binaries + Constants.libraryVersion (needs gh)
make install | uninstall | bump | version | proxy-reset | run | clean | help
```

No tests. Verify changes with `make` (build + `codesign --verify`) and by running the app.

## Architecture

- `App.swift` — entry; boots singleton services in `applicationDidFinishLaunching`, stops the proxy on terminate. No third-party dependencies (Firebase was removed).
- `Framework/Services/*Service.swift` — `final class` singletons (`static let instance`), `ObservableObject`, Combine sinks on `SettingsService` `@Published` props.
  - `ProtectionService` — core logic: launches `Resources/spoofdpi-arm` via `/bin/sh -c` (`Utils.executeTerminalCommand`), detects it with `ps -A | grep spoofdpi-arm`, 3 s watchdog timer restarts it, stops with `killall` (SpoofDPI traps SIGTERM and restores the system proxy).
  - `SettingsService` — `@AppStorage`-backed settings, incl. free-text `libraryParameters` (cleared on init if it holds 0.x single-dash flags).
  - `UpdateService` — polls **this fork's** `Other/ActualBuildNumber.txt` on `main`; alert fires if it exceeds `CURRENT_PROJECT_VERSION`.
- `Constants.swift` — `libraryVersion` (shown in UI) and `libraryDefaultParameters`.
- `Scenes/` — UI; strings in `Localizable.xcstrings` via `Other/LocalizedString.swift`.

## Gotchas

- SpoofDPI ≥1.0 CLI differs from 0.x: system proxy is opt-in and a TUI runs by default, so the app always passes `--no-tui --auto-configure-network`. Re-check `--help` after every `update-core`.
- Apple Silicon only: one bundled binary `spoofdpi-arm` (`Constants.libraryProcessName`), `ARCHS=arm64` set by the Makefile.
- Version: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.pbxproj`; use `make bump` so `Other/ActualBuildNumber.txt` stays in sync, or the update alert misfires.
- Xcode ships GNU Make 3.81: no `.SHELLFLAGS`, `--eval` or `.ONESHELL`; prefix multi-command recipes with `$(STRICT)`.
- `.claude/settings.local.json` holds secrets — it is gitignored; never commit it.
- Code style: 4-space indent, `guard` early returns, `[weak self]` in closures, `.with { }` builder from `Framework/Configurable.swift`.
