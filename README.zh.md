# Clippy

> 一款温暖而强大的 macOS 剪贴板管理器。卡片式历史记录、智能内容检测、
> 内置截图编辑器、Dock 预览、AI 驱动的文本转换 — 全部本地运行、开源、
> 免费。

<p align="center">
  <img src="docs/screenshots/01-main-popover.png" alt="Clippy 主面板" width="420">
</p>

<p align="center">
  <a href="https://github.com/yarasaa/Clippy/releases/latest">
    <img src="https://img.shields.io/github/v/release/yarasaa/Clippy?label=download&style=flat-square&color=E8833A" alt="最新版本">
  </a>
  <a href="https://github.com/yarasaa/Clippy/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/yarasaa/Clippy?style=flat-square&color=E8833A" alt="许可证">
  </a>
  <img src="https://img.shields.io/badge/macOS-13%2B-E8833A?style=flat-square" alt="macOS 13+">
  <a href="https://buymeacoffee.com/12hrsofficp">
    <img src="https://img.shields.io/badge/buy%20me%20a-coffee-E8833A?style=flat-square" alt="请我喝咖啡">
  </a>
</p>

**🌐** [English](README.md) · [Türkçe](README.tr.md) · [日本語](README.ja.md) · [简体中文](README.zh.md)

> 🌐 这是 [英文版 README](README.md) 的翻译。
> 应用界面目前为英文 — Clippy 使用图标丰富的简洁标签,
> 无论你的母语是什么都能轻松上手。

---

## 为什么选择 Clippy?

你复制的一切 — 文本、图片、代码、颜色、URL — 在剪贴板中短暂停留后
就消失了。Clippy 将所有内容保留下来,以美观的菜单栏历史记录呈现,
你可以搜索、收藏、固定,并通过热键粘贴。更进一步:为截图添加注释、
转换文件格式、在 Shelf 中暂存下载,使用本地或云端 AI 转换文本。

全部在**你的 Mac 上**。无需账号。无云端。无遥测。

## ✨ 功能速览

| | |
|---|---|
| 📋 **智能剪贴板历史** — 针对 URL、颜色、JSON、代码、图片的内容感知预览 | <img src="docs/screenshots/01-main-popover.png" width="280"> |
| 🎯 **悬停操作** — Paste、Star、Pin、AI 转换按需出现 | <img src="docs/screenshots/02-card-hover.png" width="280"> |
| ⚡ **Quick Preview** — 按下热键,从浮动面板中直接粘贴最近复制的条目 | <img src="docs/screenshots/13-quick-preview.png" width="280"> |
| ✍️ **截图编辑器** — Studio Bar、上下文感知 Inspector、20+ 注释工具 | <img src="docs/screenshots/14-editor.png" width="280"> |
| 🪟 **Dock 预览** — Windows 11 风格的缩略图,支持实时画面预览和编号标记 | <img src="docs/screenshots/17-dock-preview.png" width="280"> |
| ✨ **AI 转换** — 总结、翻译、语法修正、代码解释。Ollama 本地运行或云端 (自带 API 密钥) | <img src="docs/screenshots/09-ai-menu.png" width="280"> |
| 🧩 **自动输入的片段** — 用关键字保存,在任何地方召唤 | <img src="docs/screenshots/07-snippets-tab.png" width="280"> |
| 🗂 **文件转换器** — 图片、文档、音频、视频、数据格式。拖放即转换 | <img src="docs/screenshots/16-file-converter.png" width="280"> |
| 📦 **Shelf** — 跨应用随手可取的文件专属抽屉 | <img src="docs/screenshots/15-shelf.png" width="280"> |
| 🔐 **加密条目** 和类型筛选 — 锁定敏感条目、按类型筛选 | <img src="docs/screenshots/04-pinned.png" width="280"> |

---

## 亮点

### 智能剪贴板历史

每次复制都会被智能地捕获和呈现:

- **文本** 显示源应用、时间和前几行
- **URL** 获得主机标签和完整 URL 预览
- **颜色** 显示实时色样和 HEX
- **代码** 以语言标签和等宽字体呈现
- **JSON** 将结构折叠为单行
- **图片** 作为带尺寸的全幅缩略图显示

<p align="center">
  <img src="docs/screenshots/01-main-popover.png" alt="混合内容的主面板" width="420">
</p>

悬停在任意卡片上即可显示转换、星标、固定和粘贴操作。

<p align="center">
  <img src="docs/screenshots/02-card-hover.png" alt="卡片悬停操作" width="420">
</p>

### 实时搜索

输入即时筛选。占位符会根据当前选项卡调整
(Search clipboard… / Search snippets… / Search images…) —
你始终清楚自己在搜索什么。

<p align="center">
  <img src="docs/screenshots/03-search.png" alt="实时搜索筛选" width="420">
</p>

### 固定 & 星标

固定的条目悬浮在 Recent 流之上,让你永远不会丢失重要内容 —
包括 Clippy 的 **加密内容** 条目,用于任何敏感信息。

<p align="center">
  <img src="docs/screenshots/03-pinned.png" alt="带加密条目的固定区" width="420">
</p>

将你想长期保存的内容加星标,然后跳转到 Starred 选项卡只查看这些。

<p align="center">
  <img src="docs/screenshots/05-starred.png" alt="Starred 选项卡" width="420">
</p>

### 按类型筛选

顶部的选项卡可将列表缩小到单一内容类型 — All、
**Images**、Snippets、Starred。

<p align="center">
  <img src="docs/screenshots/06-images-tab.png" alt="仅图片选项卡" width="420">
</p>

### 自动输入的片段

将任何剪贴板条目保存为带关键字的可复用片段。在任何地方输入关键字都会
触发展开。`{{DATE}}`、`{{CLIPBOARD}}`、`{{UUID}}` 等变量会在展开时
自动填充。

<p align="center">
  <img src="docs/screenshots/07-snippets-tab.png" alt="Snippets 选项卡" width="420">
</p>

### 右键菜单的强大功能

每张卡片都有丰富的上下文菜单:复制、粘贴、分享、颜色格式转换、星标、
固定、加密、合并图片、删除。

<p align="center">
  <img src="docs/screenshots/06-context-menu.png" alt="右键上下文菜单" width="360">
</p>

### AI 文本转换

在任何剪贴板条目上运行:Summarize、Expand、Fix Grammar、Translate
(30+ 种语言)、Bullet Points、Draft Email,以及针对代码的操作
(Explain、Add Comments、Find Bugs、Optimize)。

选择你的提供商:

- **Ollama** — 完全本地、免费、私密
- **OpenAI**、**Anthropic**、**Google Gemini** — 自带 API 密钥

还内置了文本实用工具:Base64 编码/解码、大小写转换、JSON 格式化/压缩、
去除重复行、合并行。

<p align="center">
  <img src="docs/screenshots/07-ai-menu.png" alt="带 AI 操作的转换菜单" width="340">
</p>

### 详情窗口 — 操作栏 + 检查器

点击任何条目打开其详情窗口。左侧:常驻操作栏 (星标、固定、加密、分享、
删除)。中间:富文本编辑器。右侧:上下文感知检查器 (关键字、应用范围、
使用统计)。

<p align="center">
  <img src="docs/screenshots/08-detail-url.png" alt="URL 详情窗口" width="520">
</p>

不同的内容类型有不同的处理方式 — JSON 有树状视图、Valid JSON 徽章和
Raw 切换按钮。

<p align="center">
  <img src="docs/screenshots/09-detail-json.png" alt="JSON 详情视图" width="520">
</p>

颜色有专属卡片:发光的色样,以及可在 HEX、RGB、HSL 之间一键切换并
复制的菜单。

<p align="center">
  <img src="docs/screenshots/12-detail-color.png" alt="颜色详情视图" width="520">
</p>

### Quick Preview 浮层

在任何地方按下 Quick Preview 热键 (默认 **⌘⌥V**) 即可在浮动面板中
查看最近 10 个条目。数字键 `1`-`9` 直接粘贴,`↑↓` 导航,`esc` 关闭。

<p align="center">
  <img src="docs/screenshots/13-quick-preview.png" alt="Quick Preview 浮层" width="380">
</p>

### 截图编辑器 — "Studio"

内置编辑器有自己独特的设计语言。左侧工具栏、中间实时画布、右侧
**上下文感知检查器** — 显示当前工具的属性或所选注释的详细信息。

<p align="center">
  <img src="docs/screenshots/10-editor.png" alt="带 Inspector 的截图编辑器" width="720">
</p>

20+ 种工具,每一种都可实时配置:

- 5 种箭头样式和 5 种描边图案的 Arrow
- 粗体/斜体/对齐、对比度感知背景、盒子尺寸的 Text
- 3 种笔刷样式 (solid/dashed/marker) 的 Pen
- 圆角半径、填充模式、渐变的 Shapes
- 为箭头/矩形/椭圆提供手绘风格的 Sketch 模式
- 模糊、像素化、聚光、图钉 (编号标记)、表情、放大镜、标尺
- 像素精度放大镜和 9 种颜色格式复制选项的 Eyedropper
- 效果:背景内边距、阴影、圆角、边框、水印

### Shelf

跨应用随手可取的文件专属抽屉 — 下载、附件、样机、PDF。从任何地方将
文件拖到 Shelf;需要时再拖出。显示类型徽章 (PDF / ZIP / 文件夹 /
图片尺寸) 和批量操作。

<p align="center">
  <img src="docs/screenshots/11-shelf.png" alt="Shelf 窗口" width="520">
</p>

### 文件转换器

拖入文件,选择输出格式,批量转换:

- **图片:** PNG、JPEG、TIFF、BMP、GIF、HEIC、WEBP、PDF
- **文档:** RTF、HTML、TXT、PDF、Markdown、DOCX
- **音频:** M4A、WAV、AAC、AIFF、MP3、FLAC、CAF
- **视频:** MOV、MP4、M4V、AVI
- **数据:** JSON、YAML、XML、CSV、PLIST

<p align="center">
  <img src="docs/screenshots/12-file-converter.png" alt="文件转换器" width="640">
</p>

### Dock 预览 & 应用切换器

悬停 Dock 上的任意应用,即可看到 Windows 11 风格的缩略图 — 编号键盘
提示、内嵌标题栏,以及 (可选) 5 FPS 实时流。

<p align="center">
  <img src="docs/screenshots/13-dock-preview.png" alt="Dock 预览" width="520">
</p>

---

## 设置

所有内容都可以从基于 NavigationSplitView 的单一 Settings 窗口进行配置 —
General、Features、AI、Shortcuts、Snippets、Windows、Privacy、About。

### General

登录时启动、主题、面板尺寸、可见选项卡、自动更新检查。

<p align="center">
  <img src="docs/screenshots/19-settings-general.png" alt="Settings → General" width="520">
</p>

### Features

细粒度开关:自动代码检测、内容检测、去重、源应用追踪、截图编辑器、
OCR、文件转换器、Shelf、Quick Preview。

<p align="center">
  <img src="docs/screenshots/20-settings-features.png" alt="Settings → Features" width="520">
</p>

### AI

选择提供商 (Ollama、OpenAI、Anthropic、Google Gemini)、粘贴 API 密钥、
选择模型、测试连接。底部的 available actions 精确告诉你 Clippy 在卡片上
会提供什么。

<p align="center">
  <img src="docs/screenshots/21-settings-ai.png" alt="Settings → AI" width="520">
</p>

### Shortcuts

重新绑定每一个热键 — Show/Hide、Paste Selected、Quick Preview、
Sequential Copy/Paste、Clear Queue、Screenshot、App Switcher。

<p align="center">
  <img src="docs/screenshots/22-settings-shortcuts.png" alt="Settings → Shortcuts" width="520">
</p>

### Windows (Dock 预览)

调整 Dock 预览:动画风格、预览尺寸、悬停延迟、触控板手势、窗口缓存、
最大缓存大小。

<p align="center">
  <img src="docs/screenshots/23-settings-windows.png" alt="Settings → Windows" width="520">
</p>

---

## 安装

### 下载 DMG

1. 从 **[Releases](https://github.com/yarasaa/Clippy/releases/latest)** 获取最新的 `.dmg`
2. 双击,将 **Clippy.app** 拖到 `/Applications`
3. 启动 — 简短的引导会帮你完成设置

<p align="center">
  <img src="docs/screenshots/18-onboarding.png" alt="引导界面" width="420">
</p>

### 自动更新

Clippy 内置了 [Sparkle](https://sparkle-project.org/)。新版本每 24 小时
在后台检查一次,或通过 **Settings → General → Check Now** 手动检查。
所有更新都经过加密签名 (EdDSA),因此只有真正的 Clippy 才能将更新推送
到你的设备上。

### 从源码构建

```bash
git clone https://github.com/yarasaa/Clippy.git
cd Clippy
open Clippy.xcodeproj
# 在 Xcode 中 Product → Run (⌘R)
```

要求:macOS 13+、Xcode 16+、Swift 5.9+。

---

## 键盘快捷键

全部可从 **Settings → Shortcuts** 重新绑定。

| 操作 | 默认 |
|---|---|
| 显示/隐藏 Clippy 面板 | `⌘⇧V` |
| Quick Preview 浮层 | `⌘⌥V` |
| 粘贴所有已选 | `⌘⏎` |
| Sequential Copy | `⌘⇧C` |
| Sequential Paste | `⌘⇧V` (覆盖) |
| 截图 | `⌘⇧S` |
| App Switcher | `⌘⇥` (启用时) |

Quick Preview 浮层有自己的导航键 — `1`-`9` 粘贴、`↑↓` 移动、
`esc` 关闭。

---

## 隐私

Clippy 将所有内容存储在你的 Mac 上,位于你的用户账户下的 CoreData 中。

- **无网络调用**,除了:
  - 可选的 AI 转换 (仅在你启用时,且只发送给你选择的提供商 —
    Ollama 完全本地运行)
  - 对 `raw.githubusercontent.com/yarasaa/Clippy` 的自动更新检查
- **无分析、遥测或账号系统**
- **源应用追踪** 可在 Settings → Features 中禁用
- **加密条目** — 锁定敏感的剪贴板条目,在认证之前显示为
  "Encrypted content"

完整说明请参阅 [PRIVACY.md](PRIVACY.md) (即将推出)。

---

## 贡献

Clippy 是开源项目,非常欢迎社区贡献。

- Bug / 功能请求: [GitHub Issues](https://github.com/yarasaa/Clippy/issues)
- 代码贡献:fork、branch、向 `main` 发 PR
- 较大改动:先开 issue 讨论方向

发布 (仅限维护者) — 请参阅 [docs/SPARKLE_SETUP.md](docs/SPARKLE_SETUP.md)。

---

## 致谢

- **Sparkle** — 自动更新框架
- **HotKey** — 全局键盘快捷键
- **Ollama**、**OpenAI**、**Anthropic**、**Google** — AI 访问
- 所有报告 bug、测试构建、推动 Ember 重设计的人们

## 支持这个项目

如果 Clippy 让你的生活更轻松,一杯咖啡就能让它继续:

<p align="center">
  <a href="https://buymeacoffee.com/12hrsofficp">
    <img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" height="41">
  </a>
</p>

---

## 许可证

MIT — 请参阅 [LICENSE](LICENSE)。
