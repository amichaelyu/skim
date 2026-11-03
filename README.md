# Skim (amichaelyu fork)

[Skim](https://skim-app.sourceforge.io/) 1.7.17 with one change: **reloading a PDF that changed on
disk no longer flashes.** Built for live LaTeX previews, where the PDF is rebuilt every time you save.

```
brew install --cask amichaelyu/tap/skim
```

Updates come through Homebrew and through the app's own updater, which reads this repository's
releases instead of the upstream feed.

## The change

Upstream, a reload hands the new document to PDFKit, which shows an empty view while it draws the
new pages in the background, then scrolls back to where you were. On a large page that is a blank
gray frame for a few hundred milliseconds on every rebuild.

This fork covers the view while the document is swapped:

1. Before the swap, Skim draws the visible pages itself (PDFKit's page drawing, at the view's
   current positions and zoom) and lays that picture over the PDF view.
2. The new document is swapped in and scrolled back underneath.
3. The visible pages of the new document are drawn into the picture straight away, so the update
   appears at once.
4. After PDFKit has had time to draw them itself, the picture fades out.

Capturing the view instead does not work: PDFKit draws pages into tiled layers that
`-cacheDisplayInRect:` does not see, which gives a white page.

Tuning, in seconds:

```
defaults write -app Skim SKReloadOverlayDuration -float 0.5   # how long the picture stays up
defaults write -app Skim SKReloadOverlayFade -float 0.08      # crossfade to PDFKit's drawing
```

The patch is in `SKMainWindowController.m` (`showReloadOverlay`, `pictureOfVisiblePages`).

## Other differences from upstream

- Minimum macOS 12 (Xcode 27 builds nothing older).
- Version `1.7.17.1`, update feed `releases/latest/download/appcast.xml` with this fork's EdDSA key.
- `Scripts/release.sh` builds, signs with a Developer ID, notarizes, staples, zips and writes the
  appcast.

Skim is BSD licensed; see `LICENSE`.
