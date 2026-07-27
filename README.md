# Clippy: Open Source AI Clipboard Manager for macOS

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

**🌐** [English](README.md) · [Türkçe](README.tr.md) · [日本語](README.ja.md) · [简体中文](README.zh.md)

> **New in 1.0.14** — ask your clipboard questions in plain language, grab
> text from any region of your screen, reusable templates, and a real
> keyboard flow. [See what changed →](https://github.com/yarasaa/Clippy/releases/latest)

**Contents** — [Why Clippy?](#why-clippy) · [Features](#-features-at-a-glance) · [Highlights](#highlights) · [Settings](#settings) · [Installation](#installation) · [Shortcuts](#keyboard-shortcuts) · [Privacy](#privacy)

---

## Why Clippy?

Everything you copy — text, images, code, colors, URLs — lives on briefly
in your clipboard and is gone. Clippy keeps it all, in a beautiful menu
bar history you can search, star, pin, and paste with a hotkey.

Then it goes further: ask it questions in plain language, lift text out of
any screenshot or region of your screen, annotate images, convert files,
and transform text with local or cloud AI.

All **on your Mac**. No accounts. No cloud. No telemetry.

## ✨ Features at a glance

| | |
|---|---|
| 📋 **Smart clipboard history** — content-aware previews for text, URLs, colors, JSON, code and images | <img src="docs/screenshots/01-main-popover.png" width="280"> |
| 💬 **Ask your clipboard** — "what was that phone number?" Ask in plain language, get the answer with its sources | <img src="docs/screenshots/32-ask.png" width="280"> |
| 🔍 **Searchable screenshots** — auto-OCR reads every image on-device, so you can search text you only ever *saw* in a picture | <img src="docs/screenshots/27-searchable-ocr.png" width="280"> |
| 🎯 **Smart detection** — phones, emails, dates, addresses and sensitive data (cards, IBANs, API keys) become one-tap actions | <img src="docs/screenshots/28-ocr-badges.png" width="280"> |
| ✍️ **Screenshot editor** — Studio Bar, context-aware Inspector, 20+ annotation tools | <img src="docs/screenshots/14-editor.png" width="280"> |
| ⚡ **Quick Preview** — hit the hotkey, paste from your recent items in a floating overlay | <img src="docs/screenshots/13-quick-preview.png" width="280"> |
| ✨ **AI transformations** — summarize, translate, fix grammar, explain code. Local via Ollama or cloud | <img src="docs/screenshots/09-ai-menu.png" width="280"> |
| 🪟 **Dock Preview** — Windows 11–style thumbnails with live streaming and numbered badges | <img src="docs/screenshots/17-dock-preview.png" width="280"> |
| 🧩 **Snippets that type themselves** — save reusable text with a keyword, summon it anywhere | <img src="docs/screenshots/07-snippets-tab.png" width="280"> |

### Also included

- 🔎 **Screen Text Grab** — press ⇧⌘2, drag over any region of your screen, and the text inside it lands in your clipboard
- 📐 **Templates** — Clippy spots text you copy repeatedly and offers to turn it into a reusable template
- 📱 **Send to Phone** — any link becomes a QR code you can scan
- 🏷 **Automatic titles** — every item gets a short, readable name
- 🔤 **Live Text** — select text right on any screenshot, just like Photos
- 🌍 **Language badges** — screenshots are tagged with their detected language
- 🎯 **Hover actions** — Paste, Star, Pin and AI transform appear the moment you need them
- 🗂 **File Converter** — images, documents, audio, video, data formats
- 📦 **Shelf** — a drawer for files you need handy across apps
- 🔐 **Encrypted items** & per-type filters — lock sensitive entries, filter by type

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

### 💬 Ask your clipboard

Stop scrolling for that one thing you copied. Ask for it:

> *"what was that phone number"* · *"the link from yesterday"* · *"my pinned items"*

Clippy works out what you're asking for — timeframe, content type, which
app it came from — ranks your history by meaning rather than keyword
overlap, and shows the answer alongside the items it used.

Concrete values are pulled **verbatim** from the original text instead of
being retyped by a model, so a phone number is always the number you
actually copied.

Works with local models through Ollama or with a cloud provider, and falls
back to on-device matching when no model is configured.

<p align="center">
  <img src="docs/screenshots/32-ask.png" alt="Asking Clippy a question about clipboard history" width="420">
</p>

### 🔍 Searchable screenshots (Auto-OCR)

Copy any image and Clippy reads the text inside it in the background — on-device, private, and free. Search for a word you only ever *saw* in a screenshot and it comes right up. Powered by Apple Vision, it recognizes **30+ languages** automatically with no setup.

<p align="center">
  <img src="docs/screenshots/27-searchable-ocr.png" alt="Searching screenshots by their OCR text" width="420">
</p>

### 🔎 Screen Text Grab

Press **⇧⌘2**, drag over any region of your screen, and the text inside it
goes straight to your clipboard. Text in a video, a PDF that won't let you
select, a screenshot someone sent you — if you can see it, you can copy
it. QR codes in the selection are decoded too.

Handy for:

- text in a video or a slide someone is presenting
- a PDF that refuses to let you select
- a screenshot sent to you in chat
- an error dialog you'd otherwise retype by hand

### 🎯 Smart content detection

Clippy spots actionable content — in both **text and screenshots** — and turns it into one-tap actions:

- **📞 Phone / ✉️ Email / 🔗 URL** — tap to call, mail, or open
- **📅 Dates** — add straight to Calendar
- **📍 Addresses** — open in Maps
- **🔒 Sensitive data** — credit cards, IBANs, API keys, and TC kimlik are detected (with checksum validation) and Clippy offers to encrypt them

<p align="center">
  <img src="docs/screenshots/28-ocr-badges.png" alt="Actionable badges on a screenshot, with the encrypt suggestion" width="420">
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

### Quick Preview overlay

Hit the Quick Preview hotkey (default **⌘⌥V**) anywhere to see the last
10 items in a floating panel. Number keys `1`-`9` paste directly, `↑↓`
navigate, `esc` dismisses.

<p align="center">
  <img src="docs/screenshots/13-quick-preview.png" alt="Quick Preview overlay" width="380">
</p>

### AI text transformations

Run Summarize, Expand, Fix Grammar, Translate (30+ languages), Bullet
Points, Draft Email, "Explain this" on a confusing error screenshot,
and code-specific actions (Explain, Add Comments, Find Bugs, Optimize)
on any clipboard item — text **or** screenshot.

Choose your provider:

- **Apple Intelligence** — on macOS 26+, the default. Runs entirely
  on-device, no API key, no signup, nothing leaves your Mac
- **Ollama** — fully local, free, private
- **OpenAI**, **Anthropic**, **Google Gemini** — bring-your-own-key

<p align="center">
  <img src="docs/screenshots/30-apple-intelligence.png" alt="AI settings with Apple Intelligence selected — on-device model ready" width="520">
</p>

There are text utilities built-in too: Base64 encode/decode, case
conversion, JSON format/minify, duplicate-line removal, line joining.

<p align="center">
  <img src="docs/screenshots/09-ai-menu.png" alt="Transform menu with AI actions" width="340">
</p>

### Dock Preview & App Switcher

Hover any app in the Dock to see Windows 11–style thumbnails — with
numbered keyboard hints, inline title bars, and (optionally) live
streaming at 5 FPS.

<p align="center">
  <img src="docs/screenshots/17-dock-preview.png" alt="Dock preview" width="520">
</p>

### Snippets that type themselves

Save any text as a reusable snippet with a keyword. Type `;keyword`
anywhere on your Mac — Clippy detects the trigger, deletes it, and
pastes the expanded content. Think TextExpander, but built in and free.

<p align="center">
  <img src="docs/screenshots/07-snippets-tab.png" alt="Snippets tab" width="420">
</p>

Each snippet gets its own detail window: keyword, app scope, template
body, and live usage stats (how many times fired, last used).

<p align="center">
  <img src="docs/screenshots/24-snippet-detail.png" alt="Snippet detail window with template and usage stats" width="640">
</p>

**Dynamic placeholders** — resolved automatically at paste time:

| Placeholder | Expands to |
|---|---|
| `{{DATE}}` | Today's date, `yyyy-MM-dd` |
| `{{TIME}}` | Current time, `HH:mm:ss` |
| `{{DATETIME}}` | Combined, `yyyy-MM-dd HH:mm` |
| `{{UUID}}` | A new random UUID |
| `{{CLIPBOARD}}` | Your most recent clipboard text |
| `{{RANDOM:1-100}}` | Random integer in that range |
| `{{FILE:~/notes.txt}}` | Contents of a local file |
| `{{SHELL:date +%s}}` | Output of a shell command |
| `{{MY_NAME}}` | A custom variable defined in Settings → Snippets |
| `{{;other}}` | Expand another snippet by keyword (nested, up to 5 levels deep) |

**Fill-in-the-blank parameters** — prompt a quick form at paste time
using single braces:

```
Hi {name},

Attached is invoice #{number:number} for {project:choice:Website,App,Consulting}.
Due date: {due:date}.

{signature=Best,\nMehmet}
```

Typing `;invoice` pops up a short dialog with a text field, a number
input, a dropdown, a date picker, and a pre-filled signature. A live
**Preview** at the bottom shows the final text as you fill it in.
Press **Paste** — every placeholder is replaced inline and inserted
into the focused app.

<p align="center">
  <img src="docs/screenshots/25-snippet-parameter-dialog.png" alt="Parameter input dialog with live preview" width="440">
</p>

Supported parameter types:
`{name}`, `{name:text}`, `{name:number}`, `{name:date}`, `{name:time}`,
`{name:choice:A,B,C}`, plus `{name=default}` to pre-fill any of them.

**Global variables** — define reusable placeholders once in
**Settings → Snippets → Variables** (`{{MY_NAME}}`, `{{MY_EMAIL}}`,
`{{MY_COMPANY}}` …) and reference them from any snippet. Change a
variable once, every snippet picks up the new value.

<p align="center">
  <img src="docs/screenshots/26-snippet-variables.png" alt="Custom snippet variables in Settings" width="640">
</p>

**App-scoped** — tie a snippet to specific apps (e.g. Mail + Outlook)
so `;signature` only fires where you want it.

**Nested composition** — build longer templates out of smaller snippets
(`{{;greeting}}` + `{{;signature}}` inside a bigger email body).

**Usage-aware** — Clippy tracks how often each snippet fires, so you
can see your power-users at a glance from the detail inspector.

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

### Right-click power menu

Every card has a rich context menu: copy, paste, share, convert color
format, star, pin, encrypt, combine images, delete.

<p align="center">
  <img src="docs/screenshots/08-context-menu.png" alt="Right-click context menu" width="360">
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

### 🏷 Automatic titles

Every item gets a short, readable title, so your history scans at a glance
instead of showing you the first 40 characters of a URL. Titles are
searchable, and the whole thing can be switched off in **Settings →
Features**.

### 🔤 Live Text

Open any screenshot in the detail window and select the text **right on the image** — just like Photos. Copy it, tap links, done. Language flags tell you what Clippy detected at a glance.

<p align="center">
  <img src="docs/screenshots/29-live-text.png" alt="Selecting text directly on a screenshot with Live Text" width="640">
</p>

<p align="center">
  <img src="docs/screenshots/31-language-badge.png" alt="Screenshots tagged with detected-language flags" width="420">
</p>

### 🧩 Templates

Clippy notices when you copy the same *shape* of text again and again —
invoice lines, ticket references, standup notes — and offers to turn it
into a template with the variable parts filled in. You review the
suggestion before anything is saved, and dismissing it keeps Clippy quiet.

For example, after you copy a few of these:

```
INV-2026-0142 · Acme Ltd · €1,240.00 · due 2026-08-15
INV-2026-0143 · Globex · €880.00 · due 2026-08-18
```

Clippy offers a template with the parts that change turned into fields:

```
INV-{number} · {company} · €{amount} · due {date}
```

### 📱 Send to Phone

Right-click any link → **Send to Phone**. A QR code appears; point your
camera at it and the link opens over there. No pairing, no account, no
network round trip.

<p align="center">
  <img src="docs/screenshots/35-send-to-phone.png" alt="QR code for sending a link to a phone" width="420">
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

### Shelf

A dedicated drawer for files you want to keep around across apps —
downloads, attachments, mockups, PDFs. Drag files onto the shelf from
anywhere; drag them back out when you need them. Shown with type pills
(PDF / ZIP / folder / image dimensions) and batch actions.

<p align="center">
  <img src="docs/screenshots/15-shelf.png" alt="Shelf window" width="520">
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
| Screen Text Grab | `⇧⌘2` |
| App Switcher | `⌘⇥` (when enabled) |

### In the popover

| Action | Key |
|---|---|
| Move through history | `↑` `↓` |
| Paste the selected item | `⏎` |
| Paste item 1–9 directly | `⌘1`–`⌘9` |
| Move focus between search and list | `⇥` |
| Close | `esc` |

Search doesn't take focus when the popover opens, so the number shortcuts
work the moment Clippy appears.

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
