# Clippy

> A warm, powerful clipboard manager for macOS. Card-based history, smart
> content detection, a built-in screenshot editor, dock preview, AI-powered
> text transformations — all local, open source, and free.

<p align="center">
  <img src="docs/screenshots/01-main-popover.png" alt="Clippy main popover" width="420">
</p>

<p align="center">
  <a href="https://github.com/yarasaa/Clippy/releases/latest">
    <img src="https://img.shields.io/github/v/release/yarasaa/Clippy?label=download&style=flat-square&color=E8833A" alt="Latest release">
  </a>
  <a href="https://github.com/yarasaa/Clippy/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/yarasaa/Clippy?style=flat-square&color=E8833A" alt="License">
  </a>
  <img src="https://img.shields.io/badge/macOS-13%2B-E8833A?style=flat-square" alt="macOS 13+">
  <a href="https://buymeacoffee.com/12hrsofficp">
    <img src="https://img.shields.io/badge/buy%20me%20a-coffee-E8833A?style=flat-square" alt="Buy me a coffee">
  </a>
</p>

**Türkçe:** [README.tr.md](README.tr.md)

---

## Why Clippy?

Everything you copy — text, images, code, colors, URLs — lives on briefly
in your clipboard and is gone. Clippy keeps it all, in a beautiful menu
bar history you can search, star, pin, and paste with a hotkey. Then it
goes further: annotate screenshots, convert files, stash downloads on a
shelf, transform text with local or cloud AI.

All **on your Mac**. No accounts. No cloud. No telemetry.

## ✨ Features at a glance

| | |
|---|---|
| 📋 **Smart clipboard history** with content-aware previews for URLs, colors, JSON, code, images | <img src="docs/screenshots/01-main-popover.png" width="280"> |
| 🎯 **Hover actions** — Paste, Star, Pin, AI transform appear the moment you need them | <img src="docs/screenshots/02-card-hover.png" width="280"> |
| ⚡ **Quick Preview** — hit the hotkey, paste from the last N items in a floating overlay | <img src="docs/screenshots/13-quick-preview.png" width="280"> |
| ✍️ **Screenshot editor** with Studio Bar, context-aware Inspector, 20+ annotation tools | <img src="docs/screenshots/14-editor.png" width="280"> |
| 🪟 **Dock Preview** — Windows 11–style thumbnails with live streaming and numbered badges | <img src="docs/screenshots/17-dock-preview.png" width="280"> |
| ✨ **AI transformations** — Summarize, translate, fix grammar, explain code. Local via Ollama or cloud | <img src="docs/screenshots/09-ai-menu.png" width="280"> |
| 🧩 **Snippets that type themselves** — save reusable text with a keyword, summon it anywhere | <img src="docs/screenshots/07-snippets-tab.png" width="280"> |
| 🗂 **File Converter** — images, docs, audio, video, data formats. Drag, drop, convert | <img src="docs/screenshots/16-file-converter.png" width="280"> |
| 📦 **Shelf** — a dedicated drawer for files you need to keep handy across apps | <img src="docs/screenshots/15-shelf.png" width="280"> |
| 🔐 **Encrypted items** & per-type filters — lock sensitive entries, filter by type | <img src="docs/screenshots/04-pinned.png" width="280"> |

---

## Highlights

### Smart clipboard history

Every copy is captured and rendered intelligently:

- **Text** shows its source app, time, and the first few lines
- **URLs** get a host chip + full URL preview
- **Colors** show a live swatch + HEX
- **Code** renders with a language chip and mono font
- **JSON** collapses structure into one line
- **Images** display as full-bleed thumbnails with dimensions

<p align="center">
  <img src="docs/screenshots/01-main-popover.png" alt="Main popover with mixed content" width="420">
</p>

Hover any card to reveal transform, star, pin, and paste actions.

<p align="center">
  <img src="docs/screenshots/02-card-hover.png" alt="Hover actions on a card" width="420">
</p>

### Live search

Type to filter instantly. The placeholder adapts to the active tab
(Search clipboard… / Search snippets… / Search images…) so you always
know what you're searching.

<p align="center">
  <img src="docs/screenshots/03-search.png" alt="Live search filtering" width="420">
</p>

### Pinned & starred

Pinned items float above the Recent stream so you never lose what matters —
including Clippy's **Encrypted content** entries for anything sensitive.

<p align="center">
  <img src="docs/screenshots/04-pinned.png" alt="Pinned section with encrypted item" width="420">
</p>

Star anything you want to keep long-term and jump to the Starred tab to
see only those.

<p align="center">
  <img src="docs/screenshots/05-starred.png" alt="Starred tab" width="420">
</p>

### Per-type filters

Tabs at the top narrow the list to a single content type — All,
**Images**, Snippets, Starred.

<p align="center">
  <img src="docs/screenshots/06-images-tab.png" alt="Images-only tab" width="420">
</p>

### Snippets that type themselves

Save any clipboard item as a reusable snippet with a keyword. Typing the
keyword anywhere triggers expansion. Variables like `{{DATE}}`,
`{{CLIPBOARD}}`, `{{UUID}}` interpolate at expansion time.

<p align="center">
  <img src="docs/screenshots/07-snippets-tab.png" alt="Snippets tab" width="420">
</p>

### Right-click power menu

Every card has a rich context menu: copy, paste, share, convert color
format, star, pin, encrypt, combine images, delete.

<p align="center">
  <img src="docs/screenshots/08-context-menu.png" alt="Right-click context menu" width="360">
</p>

### AI text transformations

Run Summarize, Expand, Fix Grammar, Translate (30+ languages), Bullet
Points, Draft Email, and code-specific actions (Explain, Add Comments,
Find Bugs, Optimize) on any clipboard item.

Choose your provider:

- **Ollama** — fully local, free, private
- **OpenAI**, **Anthropic**, **Google Gemini** — bring-your-own-key

There are text utilities built-in too: Base64 encode/decode, case
conversion, JSON format/minify, duplicate-line removal, line joining.

<p align="center">
  <img src="docs/screenshots/09-ai-menu.png" alt="Transform menu with AI actions" width="340">
</p>

### Detail window — action rail + inspector

Click any item to open its detail window. Left: persistent action rail
(star, pin, encrypt, share, delete). Center: rich editor. Right:
context-aware inspector (keyword, app scope, usage stats).

<p align="center">
  <img src="docs/screenshots/10-detail-url.png" alt="URL detail window" width="520">
</p>

Different content types get different treatments — JSON gets a tree
view, a Valid-JSON badge, and a Raw toggle.

<p align="center">
  <img src="docs/screenshots/11-detail-json.png" alt="JSON detail view" width="520">
</p>

Colors get a dedicated card with a glowing swatch and a one-tap Copy
menu that converts between HEX, RGB, HSL formats.

<p align="center">
  <img src="docs/screenshots/12-detail-color.png" alt="Color detail view" width="520">
</p>

### Quick Preview overlay

Hit the Quick Preview hotkey (default **⌘⌥V**) anywhere to see the last
10 items in a floating panel. Number keys `1`-`9` paste directly, `↑↓`
navigate, `esc` dismisses.

<p align="center">
  <img src="docs/screenshots/13-quick-preview.png" alt="Quick Preview overlay" width="380">
</p>

### Screenshot editor — "Studio"

The built-in editor has its own design language. Tool rail on the left,
live canvas in the middle, **context-aware Inspector** on the right that
shows either the active tool's properties or the selected annotation's
details.

<p align="center">
  <img src="docs/screenshots/14-editor.png" alt="Screenshot editor with Inspector" width="720">
</p>

20+ tools, every one of them configurable live:

- Arrow with 5 arrowhead styles and 5 stroke patterns
- Text with bold/italic/alignment, contrast-aware backgrounds, box sizing
- Pen with 3 brush styles (solid/dashed/marker)
- Shapes with corner radius, fill modes, gradient
- Sketch mode for a hand-drawn look on arrows/rects/ellipses
- Blur, pixelate, spotlight, pin (numbered markers), emoji, magnifier, ruler
- Eyedropper with pixel-accurate loupe and 9 color-format copy options
- Effects: backdrop padding, shadow, corner radius, border, watermark

### Shelf

A dedicated drawer for files you want to keep around across apps —
downloads, attachments, mockups, PDFs. Drag files onto the shelf from
anywhere; drag them back out when you need them. Shown with type pills
(PDF / ZIP / folder / image dimensions) and batch actions.

<p align="center">
  <img src="docs/screenshots/15-shelf.png" alt="Shelf window" width="520">
</p>

### File converter

Drag files in, pick output formats, convert in batch:

- **Image:** PNG, JPEG, TIFF, BMP, GIF, HEIC, WEBP, PDF
- **Document:** RTF, HTML, TXT, PDF, Markdown, DOCX
- **Audio:** M4A, WAV, AAC, AIFF, MP3, FLAC, CAF
- **Video:** MOV, MP4, M4V, AVI
- **Data:** JSON, YAML, XML, CSV, PLIST

<p align="center">
  <img src="docs/screenshots/16-file-converter.png" alt="File converter" width="640">
</p>

### Dock Preview & App Switcher

Hover any app in the Dock to see Windows 11–style thumbnails — with
numbered keyboard hints, inline title bars, and (optionally) live
streaming at 5 FPS.

<p align="center">
  <img src="docs/screenshots/17-dock-preview.png" alt="Dock preview" width="520">
</p>

---

## Settings

Everything is configurable from a single NavigationSplitView-based
Settings window — General, Features, AI, Shortcuts, Snippets, Windows,
Privacy, About.

### General

Launch at login, theme, popover size, visible tabs, auto-update checks.

<p align="center">
  <img src="docs/screenshots/19-settings-general.png" alt="Settings → General" width="520">
</p>

### Features

Fine-grained toggles: auto code detection, content detection, duplicate
skip, source-app tracking, screenshot editor, OCR, file converter,
drag-drop shelf, Quick Preview.

<p align="center">
  <img src="docs/screenshots/20-settings-features.png" alt="Settings → Features" width="520">
</p>

### AI

Pick a provider (Ollama, OpenAI, Anthropic, Google Gemini), paste your
API key, choose a model, test the connection. Available actions at the
bottom tell you exactly what Clippy will offer on your cards.

<p align="center">
  <img src="docs/screenshots/21-settings-ai.png" alt="Settings → AI" width="520">
</p>

### Shortcuts

Rebind every hotkey — Show/Hide, Paste Selected, Quick Preview,
Sequential Copy/Paste, Clear Queue, Screenshot, App Switcher.

<p align="center">
  <img src="docs/screenshots/22-settings-shortcuts.png" alt="Settings → Shortcuts" width="520">
</p>

### Windows (Dock Preview)

Tune the Dock Preview: animation style, preview size, hover delay,
trackpad gestures, window caching, max cache size.

<p align="center">
  <img src="docs/screenshots/23-settings-windows.png" alt="Settings → Windows" width="520">
</p>

---

## Installation

### Download the DMG

1. Grab the latest `.dmg` from **[Releases](https://github.com/yarasaa/Clippy/releases/latest)**
2. Double-click, drag **Clippy.app** to `/Applications`
3. Launch — a short onboarding walks you through setup

<p align="center">
  <img src="docs/screenshots/18-onboarding.png" alt="Onboarding" width="420">
</p>

### Auto-updates

Clippy ships with [Sparkle](https://sparkle-project.org/). New versions are
checked in the background every 24 hours, or on demand via
**Settings → General → Check Now**. Updates are cryptographically signed
(EdDSA) so only the real Clippy can push them to your install.

### Build from source

```bash
git clone https://github.com/yarasaa/Clippy.git
cd Clippy
open Clippy.xcodeproj
# Product → Run (⌘R) in Xcode
```

Requirements: macOS 13+, Xcode 16+, Swift 5.9+.

---

## Keyboard shortcuts

All rebindable from **Settings → Shortcuts**.

| Action | Default |
|---|---|
| Show/Hide Clippy popover | `⌘⇧V` |
| Quick Preview overlay | `⌘⌥V` |
| Paste All selected | `⌘⏎` |
| Sequential Copy | `⌘⇧C` |
| Sequential Paste | `⌘⇧V` (overridden) |
| Take Screenshot | `⌘⇧S` |
| App Switcher | `⌘⇥` (when enabled) |

Quick Preview overlay has its own nav keys — `1`-`9` to paste, `↑↓` to
move, `esc` to dismiss.

---

## Privacy

Clippy stores everything on your Mac, in CoreData, under your user account.

- **No network calls** except for:
  - Optional AI transformations (only if you enable them and only to the
    provider you choose — Ollama runs fully local)
  - Auto-update checks to `raw.githubusercontent.com/yarasaa/Clippy`
- **No analytics, telemetry, or account system**
- **Source app tracking** can be disabled in Settings → Features
- **Encrypted items** — lock sensitive clipboard entries so they show
  up as "Encrypted content" until you authenticate

See [PRIVACY.md](PRIVACY.md) (coming soon) for the full breakdown.

---

## Contributing

Clippy is open source and community contributions are very welcome.

- Bugs / feature requests: [GitHub Issues](https://github.com/yarasaa/Clippy/issues)
- Code contributions: fork, branch, PR against `main`
- Larger changes: open an issue first to discuss direction

Releasing (maintainers only) — see [docs/SPARKLE_SETUP.md](docs/SPARKLE_SETUP.md).

---

## Credits

- **Sparkle** for the auto-update framework
- **HotKey** for global keyboard shortcuts
- **Ollama**, **OpenAI**, **Anthropic**, **Google** for AI access
- Everyone who filed bugs, tested builds, and pushed for the Ember redesign

## Support the work

If Clippy makes your life easier, a coffee keeps it going:

<p align="center">
  <a href="https://buymeacoffee.com/12hrsofficp">
    <img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" height="41">
  </a>
</p>

---

## License

MIT — see [LICENSE](LICENSE).
