# Skim (amichaelyu fork)

[Skim](https://skim-app.sourceforge.io/) 1.7.17 with one change: **reloading a PDF that changed on
disk no longer flashes.** Built for live LaTeX previews, where the PDF is rebuilt every time you save.

```
brew tap amichaelyu/tap
brew trust amichaelyu/tap   # Homebrew won't load third-party tap formulae until trusted
brew install --cask amichaelyu/tap/skim
```

Updates come through Homebrew and through the app's own updater, which reads this repository's
releases instead of the upstream feed.

## Layout

- `src/`: Skim's sources and Xcode project (`src/Skim.xcodeproj`), as upstream has them.
- `Scripts/release.sh`: the release build.

## License

Skim's original BSD license, unchanged: see [LICENSE](LICENSE) and [upstream](https://sourceforge.net/p/skim-app/code/HEAD/tree/trunk/LICENSE).
