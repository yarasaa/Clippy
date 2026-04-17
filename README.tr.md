# Clippy

> macOS için sıcak ve güçlü bir pano yöneticisi. Kart tabanlı geçmiş,
> akıllı içerik algılama, yerleşik ekran görüntüsü editörü, dock önizleme,
> yerel veya bulut AI destekli metin dönüşümleri — hepsi tamamen local,
> open source ve ücretsiz.

<p align="center">
  <img src="docs/screenshots/01-main-popover.png" alt="Clippy ana panel" width="420">
</p>

<p align="center">
  <a href="https://github.com/yarasaa/Clippy/releases/latest">
    <img src="https://img.shields.io/github/v/release/yarasaa/Clippy?label=indir&style=flat-square&color=E8833A" alt="Son sürüm">
  </a>
  <a href="https://github.com/yarasaa/Clippy/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/yarasaa/Clippy?style=flat-square&color=E8833A" alt="Lisans">
  </a>
  <img src="https://img.shields.io/badge/macOS-13%2B-E8833A?style=flat-square" alt="macOS 13+">
  <a href="https://buymeacoffee.com/12hrsofficp">
    <img src="https://img.shields.io/badge/kahve-ısmarla-E8833A?style=flat-square" alt="Kahve ısmarla">
  </a>
</p>

**English:** [README.md](README.md)

---

## Neden Clippy?

Kopyaladığın her şey — metin, görsel, kod, renk, URL — panoda birkaç
saniye yaşayıp kayboluyor. Clippy hepsini tutuyor: menü çubuğunda, hotkey
ile hızla açılan, arama yapabildiğin, yıldızlayıp pinleyebildiğin güzel
bir geçmiş olarak. Sonra daha ileri gidiyor: ekran görüntülerini
annotate ediyor, dosya formatlarını dönüştürüyor, Shelf'te dosyalarını
biriktiriyor, lokal veya bulut AI ile metinleri dönüştürüyor.

Her şey **Mac'inde**. Hesap yok. Cloud yok. Telemetri yok.

## ✨ Özellikler bir bakışta

| | |
|---|---|
| 📋 **Akıllı pano geçmişi** — URL, renk, JSON, kod, görsel için özel önizleme | <img src="docs/screenshots/01-main-popover.png" width="280"> |
| 🎯 **Hover eylemler** — Paste, Yıldız, Pin, AI dönüşüm tam ihtiyaç anında belirir | <img src="docs/screenshots/02-card-hover.png" width="280"> |
| ⚡ **Quick Preview** — hotkey bas, son N öğeden birini floating panelden yapıştır | <img src="docs/screenshots/13-quick-preview.png" width="280"> |
| ✍️ **Ekran görüntüsü editörü** — Studio Bar, bağlama duyarlı Inspector, 20+ araç | <img src="docs/screenshots/14-editor.png" width="280"> |
| 🪟 **Dock Preview** — Windows 11 tarzı thumbnail'lar, canlı streaming ve numaralı rozetler | <img src="docs/screenshots/17-dock-preview.png" width="280"> |
| ✨ **AI dönüşümler** — Özetle, çevir, dilbilgisi düzelt, kod açıkla. Ollama ile lokal veya bulut | <img src="docs/screenshots/09-ai-menu.png" width="280"> |
| 🧩 **Kendi kendine yazan snippet'ler** — keyword'le kaydet, her yerde çağır | <img src="docs/screenshots/07-snippets-tab.png" width="280"> |
| 🗂 **Dosya Dönüştürücü** — görsel, belge, ses, video, veri formatları. Sürükle, bırak, dönüştür | <img src="docs/screenshots/16-file-converter.png" width="280"> |
| 📦 **Shelf** — uygulamalar arası elinin altında tutmak istediğin dosyalar için çekmece | <img src="docs/screenshots/15-shelf.png" width="280"> |
| 🔐 **Şifreli öğeler** & filtreler — hassas girişleri kilitle, türe göre filtrele | <img src="docs/screenshots/04-pinned.png" width="280"> |

---

## Öne çıkanlar

### Akıllı pano geçmişi

Kopyalanan her şey, türüne göre akıllıca render ediliyor:

- **Metin** — kaynak uygulama, zaman ve ilk birkaç satır
- **URL** — host rozeti + tam URL önizleme
- **Renkler** — canlı swatch + HEX
- **Kod** — dil rozeti ve mono font
- **JSON** — yapıyı tek satıra toplar
- **Görseller** — boyut bilgisiyle tam kaplayan thumbnail

<p align="center">
  <img src="docs/screenshots/01-main-popover.png" alt="Karışık içerikli ana panel" width="420">
</p>

Bir kartın üzerine gelince transform, yıldız, pin ve paste eylemleri belirir.

<p align="center">
  <img src="docs/screenshots/02-card-hover.png" alt="Kart hover eylemleri" width="420">
</p>

### Canlı arama

Yazarken anında filtreler. Placeholder aktif sekmeye göre değişir
(Search clipboard… / Search snippets… / Search images…) — ne
aradığını her zaman bilirsin.

<p align="center">
  <img src="docs/screenshots/03-search.png" alt="Canlı arama filtresi" width="420">
</p>

### Pinli & yıldızlı

Pinli öğeler Recent akışının üstünde kalıcı olarak duruyor — önemli
şeyleri kaybetmek imkansız. Hassas girişler için Clippy'nin
**Encrypted content** öğeleri de pinlenebiliyor.

<p align="center">
  <img src="docs/screenshots/04-pinned.png" alt="Şifreli öğe ile pinli bölüm" width="420">
</p>

Uzun süre saklamak istediğin şeyleri yıldızla, Starred sekmesinden sadece
onları gör.

<p align="center">
  <img src="docs/screenshots/05-starred.png" alt="Starred sekmesi" width="420">
</p>

### İçerik türü filtreleri

Üstteki sekmeler listeyi tek bir içerik türüne daraltır — All,
**Images**, Snippets, Starred.

<p align="center">
  <img src="docs/screenshots/06-images-tab.png" alt="Sadece görseller sekmesi" width="420">
</p>

### Kendi kendine yazan snippet'ler

Herhangi bir pano öğesini keyword ile yeniden kullanılabilir snippet
olarak kaydet. Keyword'ü her yerde yazınca genişletir. `{{DATE}}`,
`{{CLIPBOARD}}`, `{{UUID}}` gibi değişkenler anında çözülür.

<p align="center">
  <img src="docs/screenshots/07-snippets-tab.png" alt="Snippets sekmesi" width="420">
</p>

### Sağ tık güç menüsü

Her kartın zengin bir context menüsü var: copy, paste, share, renk
formatı dönüştür, yıldızla, pinle, şifrele, görselleri birleştir, sil.

<p align="center">
  <img src="docs/screenshots/08-context-menu.png" alt="Sağ tık menüsü" width="360">
</p>

### AI metin dönüşümleri

Herhangi bir pano öğesi üzerinde çalıştır: Summarize, Expand, Fix Grammar,
Translate (30+ dil), Bullet Points, Draft Email, ve kod için Explain,
Add Comments, Find Bugs, Optimize.

Sağlayıcını seç:

- **Ollama** — tamamen lokal, ücretsiz, özel
- **OpenAI**, **Anthropic**, **Google Gemini** — kendi API anahtarın

Yerleşik metin araçları da var: Base64 encode/decode, case dönüşümü,
JSON format/minify, tekrar eden satırları temizle, satır birleştir.

<p align="center">
  <img src="docs/screenshots/09-ai-menu.png" alt="AI eylemleriyle dönüşüm menüsü" width="340">
</p>

### Detay penceresi — action rail + inspector

Herhangi bir öğeye tıkla → detay penceresi açılır. Sol: kalıcı action
rail (yıldız, pin, şifrele, paylaş, sil). Orta: zengin editör. Sağ:
bağlama duyarlı inspector (keyword, uygulama scope'u, kullanım
istatistikleri).

<p align="center">
  <img src="docs/screenshots/10-detail-url.png" alt="URL detay penceresi" width="520">
</p>

Farklı içerik türleri farklı muamele görüyor — JSON için ağaç görünümü,
"Valid JSON" rozeti ve Raw toggle'ı var.

<p align="center">
  <img src="docs/screenshots/11-detail-json.png" alt="JSON detay görünümü" width="520">
</p>

Renkler için özel bir kart: parlayan swatch + tek tıkla HEX, RGB, HSL
arasında dönüştüren Copy menüsü.

<p align="center">
  <img src="docs/screenshots/12-detail-color.png" alt="Renk detay görünümü" width="520">
</p>

### Quick Preview overlay

Quick Preview hotkey'ine (varsayılan **⌘⌥V**) her yerden bas, son 10
öğeyi floating panelde gör. `1`-`9` rakamları doğrudan yapıştırır,
`↑↓` gezinir, `esc` kapatır.

<p align="center">
  <img src="docs/screenshots/13-quick-preview.png" alt="Quick Preview overlay" width="380">
</p>

### Ekran görüntüsü editörü — "Studio"

Yerleşik editörün kendine özgü bir tasarım dili var. Solda araç barı,
ortada canvas, sağda **bağlama duyarlı Inspector** — aktif aracın
özelliklerini veya seçili annotation'ın detaylarını gösterir.

<p align="center">
  <img src="docs/screenshots/14-editor.png" alt="Inspector ile ekran editörü" width="720">
</p>

20+ araç, hepsi canlı yapılandırılabilir:

- 5 ok başı stili + 5 çizgi deseni olan Arrow
- Bold/italic/hizalama, kontrast-duyarlı arka plan, kutu boyutu olan Text
- 3 fırça stili (solid/dashed/marker) olan Pen
- Corner radius, fill mod, gradient olan şekiller
- Arrow/rect/ellipse için el çizimi görünüm veren Sketch modu
- Blur, pixelate, spotlight, pin (numaralı işaret), emoji, magnifier, ruler
- Pixel-doğruluğunda loupe ve 9 renk formatı kopyalama ile Eyedropper
- Efektler: backdrop padding, shadow, corner radius, border, watermark

### Shelf

Uygulamalar arası elinin altında tutmak istediğin dosyalar için özel bir
çekmece — indirilenler, ekler, mockup'lar, PDF'ler. Dosyaları her
yerden Shelf'e sürükle; gerektiğinde geri çek. Tür rozetleriyle
(PDF / ZIP / folder / görsel boyutu) ve toplu eylemlerle listelenir.

<p align="center">
  <img src="docs/screenshots/15-shelf.png" alt="Shelf penceresi" width="520">
</p>

### Dosya dönüştürücü

Dosyaları sürükle, çıktı formatlarını seç, toplu dönüştür:

- **Görsel:** PNG, JPEG, TIFF, BMP, GIF, HEIC, WEBP, PDF
- **Belge:** RTF, HTML, TXT, PDF, Markdown, DOCX
- **Ses:** M4A, WAV, AAC, AIFF, MP3, FLAC, CAF
- **Video:** MOV, MP4, M4V, AVI
- **Veri:** JSON, YAML, XML, CSV, PLIST

<p align="center">
  <img src="docs/screenshots/16-file-converter.png" alt="Dosya dönüştürücü" width="640">
</p>

### Dock Preview & App Switcher

Dock'taki herhangi bir uygulamanın üzerine gelince Windows 11 tarzı
thumbnail'ları gör — numaralı klavye ipuçları, inline başlık çubukları,
ve (opsiyonel) 5 FPS canlı streaming ile.

<p align="center">
  <img src="docs/screenshots/17-dock-preview.png" alt="Dock önizleme" width="520">
</p>

---

## Ayarlar

Her şey tek bir NavigationSplitView tabanlı Settings penceresinden
yapılandırılabilir — General, Features, AI, Shortcuts, Snippets, Windows,
Privacy, About.

### General

Açılışta başlat, tema, popover boyutu, görünür sekmeler, auto-update
kontrolleri.

<p align="center">
  <img src="docs/screenshots/19-settings-general.png" alt="Settings → General" width="520">
</p>

### Features

İnce ayar: otomatik kod algılama, içerik algılama, duplicate atla,
kaynak-uygulama takibi, ekran editörü, OCR, dosya dönüştürücü, shelf,
Quick Preview.

<p align="center">
  <img src="docs/screenshots/20-settings-features.png" alt="Settings → Features" width="520">
</p>

### AI

Sağlayıcı seç (Ollama, OpenAI, Anthropic, Google Gemini), API key
yapıştır, model seç, bağlantıyı test et. Aşağıdaki available actions
Clippy'nin kartlarında tam olarak ne sunacağını söyler.

<p align="center">
  <img src="docs/screenshots/21-settings-ai.png" alt="Settings → AI" width="520">
</p>

### Shortcuts

Her kısayolu yeniden bağla — Show/Hide, Paste Selected, Quick Preview,
Sequential Copy/Paste, Clear Queue, Screenshot, App Switcher.

<p align="center">
  <img src="docs/screenshots/22-settings-shortcuts.png" alt="Settings → Shortcuts" width="520">
</p>

### Windows (Dock Preview)

Dock Preview'ı ayarla: animasyon stili, önizleme boyutu, hover delay,
trackpad gestures, pencere cache, max cache boyutu.

<p align="center">
  <img src="docs/screenshots/23-settings-windows.png" alt="Settings → Windows" width="520">
</p>

---

## Kurulum

### DMG indir

1. En son `.dmg`'yi **[Releases](https://github.com/yarasaa/Clippy/releases/latest)** sayfasından al
2. Çift tıkla, **Clippy.app**'ı `/Applications`'a sürükle
3. Aç — kısa bir onboarding kurulumda sana yol gösterir

<p align="center">
  <img src="docs/screenshots/18-onboarding.png" alt="Onboarding" width="420">
</p>

### Otomatik güncelleme

Clippy [Sparkle](https://sparkle-project.org/) ile geliyor. Yeni sürümler
24 saatte bir arka planda kontrol edilir, veya **Settings → General →
Check Now** ile manuel. Güncellemeler kriptografik olarak imzalanıyor
(EdDSA) — sadece gerçek Clippy senin Mac'ine güncelleme pushlayabilir.

### Kaynaktan derle

```bash
git clone https://github.com/yarasaa/Clippy.git
cd Clippy
open Clippy.xcodeproj
# Xcode'da Product → Run (⌘R)
```

Gereksinimler: macOS 13+, Xcode 16+, Swift 5.9+.

---

## Klavye kısayolları

Hepsi **Settings → Shortcuts**'tan değiştirilebilir.

| Eylem | Varsayılan |
|---|---|
| Clippy popover'ını aç/kapa | `⌘⇧V` |
| Quick Preview overlay | `⌘⌥V` |
| Seçilileri hepsini yapıştır | `⌘⏎` |
| Sequential Copy | `⌘⇧C` |
| Sequential Paste | `⌘⇧V` (override) |
| Ekran görüntüsü al | `⌘⇧S` |
| App Switcher | `⌘⇥` (etkinse) |

Quick Preview overlay'in kendi nav tuşları var — `1`-`9` ile yapıştır,
`↑↓` gezin, `esc` ile kapat.

---

## Gizlilik

Clippy her şeyi Mac'inde, kullanıcı hesabının altında, CoreData'da saklar.

- **Ağ çağrısı yok**, şunlar hariç:
  - Opsiyonel AI dönüşümler (sadece sen aktifleştirirsen ve sadece
    seçtiğin sağlayıcıya — Ollama tamamen lokal)
  - `raw.githubusercontent.com/yarasaa/Clippy`'e auto-update kontrolleri
- **Analitik, telemetri veya hesap sistemi yok**
- **Kaynak uygulama takibi** Settings → Features'tan kapatılabilir
- **Şifreli öğeler** — hassas pano girişlerini kilitle, kimlik
  doğrulamasına kadar "Encrypted content" olarak görünürler

Tam döküm için [PRIVACY.md](PRIVACY.md) (yakında) bakacaksın.

---

## Katkı

Clippy açık kaynak, katkılar çok kıymetli.

- Bug / özellik istekleri: [GitHub Issues](https://github.com/yarasaa/Clippy/issues)
- Kod katkıları: fork → branch → `main`'e PR
- Büyük değişiklikler: önce issue aç, yönü konuşalım

Yayınlama (sadece maintainer'lar) — [docs/SPARKLE_SETUP.md](docs/SPARKLE_SETUP.md) bak.

---

## Teşekkürler

- **Sparkle** — auto-update framework'ü için
- **HotKey** — global klavye kısayolları için
- **Ollama**, **OpenAI**, **Anthropic**, **Google** — AI erişimi için
- Bug bildiren, build test eden ve Ember yeniden tasarımını itekleyen herkes

## Destek ol

Clippy hayatını kolaylaştırıyorsa, bir kahve devam ettirmeye yeter:

<p align="center">
  <a href="https://buymeacoffee.com/12hrsofficp">
    <img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" height="41">
  </a>
</p>

---

## Lisans

MIT — [LICENSE](LICENSE) dosyasına bak.
