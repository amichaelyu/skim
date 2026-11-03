# Skim (amichaelyu fork)

[Skim](https://skim-app.sourceforge.io/) 1.7.17 with one change: **reloading a PDF that changed on
disk no longer flashes.** Built for live LaTeX previews, where the PDF is rebuilt every time you save.

```
brew install --cask amichaelyu/tap/skim
```

Updates come through Homebrew and through the app's own updater, which reads this repository's
releases instead of the upstream feed.

## Layout

- `src/`: Skim's sources and Xcode project (`src/Skim.xcodeproj`), as upstream has them.
- `Scripts/release.sh`: the release build.

## Other differences from upstream

- Minimum macOS 12 (Xcode 27 builds nothing older).
- Version `1.7.17.1`, update feed `releases/latest/download/appcast.xml` with this fork's EdDSA key.
- `Scripts/release.sh` builds, signs with a Developer ID, notarizes, staples, zips and writes the
  appcast.

Skim is BSD licensed; see `LICENSE`.
