# Clippy for macOS

<p align="center">
  <a href="https://buymeacoffee.com/12hrsofficp" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>
</p>

Clippy is a powerful macOS menu bar application designed for developers and heavy text users to manage their clipboard history. It saves everything you copy, allowing you to quickly access, edit, and use your clipboard items.

![1759521906350](image/README/1759521906350.png)

![1759522032838](image/README/1759522032838.png)

![1759522217489](image/README/1759522217489.png)

![1759522386365](image/README/1759522386365.png)

![1759522392271](image/README/1759522392271.png)

![1759522474906](image/README/1759522474906.png)

![1759522498669](image/README/1759522498669.png)

![1759522601059](image/README/1759522601059.png)

![1762463406364](image/README/1762463406364.png)

![1762464567469](image/README.tr/1762464567469.png)✨ Features

### 📋 Core Clipboard Management

- **History Recording:** Automatically saves all text and images you copy.
- **Quick Access & Interface:** Instantly access your clipboard history by clicking the menu bar icon or using a keyboard shortcut.
- **Search:** Instantly search through your entire history.
- **Favorites:** Star your frequently used items to prevent them from being deleted and find them quickly.
- **Code Detection:** Automatically detects if copied text is code and organizes it in a separate "Code" tab.
- **Custom Titles:** Add a custom title to any clipboard item for easier identification. Titles can be edited in the detail view and are prominently displayed above the content in the main list.
- **Source App Icons:** Easily track where each item was copied from with icons of the source application.

### 🚀 Advanced Functionality

- **Pinning:** Pin important items you're working on to the top of the list, keeping them there even as new items are copied.
- **Multi-Select:** Select multiple items by holding down the `Cmd (⌘)` key.
- **Paste All:** Paste all selected text items at once, separated by new lines.
- **Diff Viewer:** Compare two selected text items side-by-side with character-level highlighting of differences.
- **Drag & Drop:** Drag a single item or multiple selected text items from the list and drop them into any application.
- **Sequential Paste:**
  - **With Shortcut:** Copy multiple items in sequence with `Cmd+Shift+C`. Then, paste them one by one in the same order using `Cmd+Shift+B`.
  - **With Visual Selection:** Select your desired items from the list with `Cmd` and press the **"Add to Queue"** button at the bottom. The menu bar icon will update to show the queue status (e.g., "1/5").
- **Combine Images:** Select multiple images with `Cmd`, right-click, and combine them into a single new image, either vertically or horizontally.
- **Direct Paste:** Paste directly into the active application using the "Paste" button next to each item.

### 🪟 Window Management

- **Dock Preview:** Hover over any dock icon to see live previews of all open windows for that application
  - Click any preview to bring that window to front
  - Hover over preview to see window control buttons (minimize, close)
  - Multi-monitor support: Move windows between displays with the blue monitor button
  - **Keyboard Navigation:**
    - `1-9` keys to select windows
    - `←` `→` arrow keys to navigate between windows
    - `Enter` to activate selected window
    - `ESC` to close preview
  - **Trackpad Gestures:**
    - Swipe up: Close window (customizable)
    - Swipe down: Minimize window (customizable)
  - **Middle Click:** Quick close window (customizable)
  - **Customization:** Animation style (Spring/EaseInOut/Linear/None), preview size (Small/Medium/Large), show/hide titles

- **Window Switcher:** Press `Option (⌥) + Tab` to open an application switcher with window previews
  - See all open applications with their window counts
  - Navigate with arrow keys or `Tab`
  - Press `Enter` to switch to selected application
  - Press `ESC` to cancel
- **Quick Text Preview:** Hover over a text item to see its full content in the system's standard help tooltip.
- **Encryption:** Encrypt sensitive data with a single click from the context menu. The content of encrypted items remains hidden until you decrypt them.
- **Smart Detection:**
  - **Calendar Event:** When you copy text like "Meeting tomorrow at 2 PM," Clippy detects it and offers to add it to your calendar with one click.
  - **JSON Viewer:** Automatically detects copied JSON text and displays it in a hierarchical tree structure in the detail view. You can edit, validate, and copy keys/values/paths from this view.
  - **Text Recognition from Images (OCR):** In the detail view of an image, recognize the text within it and add it as a new, copyable text item.
  - **URL Detection:** If copied text is a URL, a button to open it in the browser appears next to it.
  - **Advanced Color Detection & Conversion:** When copied text is a color code, it's automatically detected and a color preview is displayed. Supported formats:
    - **HEX:** `#FF5733`, `#F57`, `#FF5733AA` (with alpha support)
    - **RGB/RGBA:** `rgb(255, 87, 51)`, `rgba(255, 87, 51, 0.8)`
    - **HSL/HSLA:** `hsl(9, 100%, 60%)`, `hsla(9, 100%, 60%, 0.8)`
    - Click the color preview to view and copy the color automatically converted to all formats
- **Text Transformations:** Instantly transform text by clicking the `✨` icon:
  - All Uppercase
  - All Lowercase
  - Title Case
  - Trim Whitespace
  - Base64 Encode / Decode
  - Remove Duplicate Lines
  - Join All Lines
  - **JSON String Encode/Decode:** Convert a raw string into a valid JSON string literal (`"text"`) for pasting into a JSON file, or reverse the process.
- **Tools Menu:** Generate test data (UUID, Lorem Ipsum) or delete all items in the active tab from a single menu.
- **Detailed Text Statistics:** View live character, word, and line counts in the detail screen for any text item.

### ⚙️ Customization and Settings

- **Interface Customization:** Adjust the main window's width and height. Choose your preferred theme (Light, Dark, or System Default) for a personalized look across the entire app.
- **Customizable Shortcuts:** Set your own keyboard shortcuts for both toggling the app and the "Paste All" function.
- **Language Support:** Use the app in English or Turkish.
- **Tab Management:** Hide the "Code," "Images," "Snippets," or "Favorites" tabs if you don't need them.
- **Limit Settings:** Define the maximum number of items to keep in your history and favorites.
- **Launch at Login:** Have Clippy start automatically when you log in to your Mac.
- **Modern Settings Window:** Settings are grouped under "General," "Shortcuts," and "Advanced" tabs for a cleaner and more user-friendly experience.
- **Sleep Mode Support:** After your computer wakes from sleep, all of Clippy's features (clipboard monitoring, shortcuts, keyword expansion) are automatically restarted and continue to work seamlessly.
- **Advanced Window Management:** When the Settings or About window is open in the background, right-clicking the menu bar icon and selecting the same option again will automatically bring the window to the front. This feature works for minimized windows and correctly brings windows across different workspaces.

### 📸 Advanced Screenshot Editor

- **Capture with a Shortcut:** Take a screenshot of any area of your screen with a customizable keyboard shortcut.
- **Rich Annotation Tools:**

  - **Select & Move:** Universal selection tool - select any annotation to move, edit, or delete it
  - **Arrow & Line:** Draw arrows and lines with customizable colors and thickness
  - **Shapes (Rectangle, Ellipse):** Add shapes with fill, stroke, or both modes, plus adjustable corner radius
  - **Text:** Add rich text annotations with custom background colors and font sizes that auto-resize to fit content
  - **Pin/Number:** Add numbered markers with customizable shapes (circle, square, rounded square)
  - **Highlighter:** Mark important areas with semi-transparent highlighting
  - **Spotlight:** Focus attention by darkening everything except selected areas (ellipse or rectangle)
  - **Pen:** Freehand drawing with solid, dashed, or marker styles
  - **Emoji:** Add emoji annotations with adjustable size
  - **Blur/Pixelate:** Easily hide sensitive information
  - **Eraser:** Remove any annotation with a click

- **Universal Annotation Interaction:**

  - **Click & Drag:** Click any annotation to select it, then drag to move it anywhere
  - **Double-Click Text:** Double-click text annotations to edit them instantly
  - **Resize Handles:** Most annotations have corner/edge handles for resizing
  - **Right Panel Controls:** Each tool has its own control panel that appears when selected
  - **Auto-Switch to Select:** After creating shapes, automatically switches to select mode for easy editing

- **Visual Effects Panel:**

  - **Backdrop:** Add solid color or gradient backdrops to your screenshot
  - **Inset:** Create an aesthetic margin between the image and the backdrop
  - **Shadow & Corner Radius:** Add depth and a modern look to your image and its backdrop

- **Fluent Navigation:**

  - Precisely zoom in/out to your cursor's position with `Cmd` + Mouse Wheel
  - Pan around the image with the mouse wheel
  - Hover over any annotation to see the move cursor

- **Smart Text Rendering:**

  - Text boxes auto-grow as you type (horizontally and vertically)
  - Multi-line text support with Enter key
  - Font size adjustments automatically resize the text box
  - Background colors with rounded corners for better readability

### 🖼️ Window Switcher: A Dock for Your App's Windows

While macOS's `Cmd+Tab` is great for switching between apps, it falls short when you're juggling multiple windows of the _same_ app (like several Finder windows or code projects). This feature acts as a temporary, on-demand dock for your active application's windows, giving you a crystal-clear overview and lightning-fast keyboard navigation.

This approach is heavily inspired by the elegant functionality of the beloved open-source app **DockDoor**.

- **Dock-like Previews:** Just like hovering over an app in the macOS Dock can show previews of its windows, this feature gives you an instant, full overview with live previews when you press `Option+Tab`. No more guessing which window is which.
- **Hold-and-Release Workflow:** The panel stays visible only while you hold the `Option` key. The moment you release it, the panel vanishes and you're switched to your chosen window. It's a workflow that never gets in your way.
- **Fluid Keyboard Navigation:** While holding `Option`, simply press `Tab` to cycle through your windows. It's fast, efficient, and keeps your hands on the keyboard.
- **Smart and Snappy:** The panel is highly optimized to feel instant. It intelligently ignores the first `Tab` press (the one that opens it) to prevent accidental switching and reuses its components to ensure a responsive experience every time.

### �️ Smart Tools & Developer Features

- **Diff Viewer:** Compare two selected text items side-by-side with character-level highlighting of differences.
- **JSON Viewer:** Automatically detects copied JSON text and displays it in a hierarchical tree structure in the detail view. You can edit, validate, and copy keys/values/paths from this view.
- **Calendar Event Detection:** When you copy text like "Meeting tomorrow at 2 PM," Clippy detects it and offers to add it to your calendar with one click.
- **Encryption:** Encrypt sensitive data with a single click from the context menu. The content of encrypted items remains hidden until you decrypt them.

### ⚡️ Performance & Optimization

- **Efficient Loading:** With Core Data batch fetching and thumbnail caching, the app now loads and scrolls through long lists of items, especially images, much faster and with significantly less memory usage.

### ⌨️ Keyword Expansion (Snippet Expansion)

This feature allows you to instantly paste frequently used text snippets using a keyword. Snippets are organized in their own dedicated **"Snippets"** tab for easy access and management.

#### 📁 Category System

Organize your snippets into categories for better organization and easier access!

**Features:**

- **Customizable Categories:** Create your own categories and personalize them with emoji icons
- **Horizontal Scrollable Filter:** A horizontal scrolling menu below the search box in the Snippets tab for filtering by category
- **Navigation Arrows:** Easily navigate between categories with left and right arrow buttons (window width remains fixed)
- **Category Assignment:** Assign or change categories for each snippet from the snippet detail screen
- **System-wide Toggle:** Completely disable the category system (when disabled, all snippets are shown without filtering)

**Usage:**

1. Go to **Settings > Snippets** section and open the "Snippet Categories" tab
2. Enable the category system (default: enabled)
3. To add a new category:
   - Enter a category name (e.g., "Email Templates")
   - Click the emoji icon to choose your desired emoji (default: 📁)
   - Click the "Add" button
4. To assign a category to a snippet:
   - Open the snippet's detail screen
   - Select the desired category from the "Category" dropdown menu
   - Click the "Save" button
5. To filter snippets by category:
   - Go to the Snippets tab
   - Select one of the category buttons below the search box
   - Use left/right arrow buttons to see more categories

**Default Categories:**

The app comes with these categories on first launch (all can be deleted and edited):

- 📧 Email
- 💼 Work
- 📝 Personal
- 💻 Code
- 📋 Templates

**Example Use Case:**

```
Category: 💻 Code
Keyword: ;func
Content:
function {name}({parameters}) {
  {code}
}

Category: 📧 Email
Keyword: ;thanks
Content:
Hello {name},

Thank you very much for your help!

Best regards,
{{;sig}}
```

#### Basic Usage

- **Keyword:** `;sig`
- **Content:**
  ```
  Best regards,
  John Appleseed
  ```
- **Result:** Typing `;sig` anywhere will automatically paste the text.

#### Backspace & Escape Support

- **Backspace (⌫):** If you make a mistake while typing a keyword, press backspace to delete the last character.
- **Escape (ESC):** If you want to cancel snippet typing, press ESC to reset the buffer.

#### Dynamic Content: Snippets with Live Data

Add "magic words" to your snippets to have up-to-date information automatically filled in every time.

##### Basic Placeholders

| Magic Word      | Description                     | Example Output                      |
| --------------- | ------------------------------- | ----------------------------------- |
| `{{DATE}}`      | Inserts the current date.       | `2025-10-05`                        |
| `{{TIME}}`      | Inserts the current time.       | `15:30:25`                          |
| `{{DATETIME}}`  | Inserts date and time together. | `2025-10-05 15:30`                  |
| `{{UUID}}`      | Generates a unique ID.          | `A9A4E42D-3C6F-4E8B-9F3C...`        |
| `{{CLIPBOARD}}` | Inserts the current clipboard.  | _(The last text on your clipboard)_ |

**Example:**

- **Keyword:** `;report`
- **Content:** `Report Date: {{DATE}} - {{TIME}}`
- **Result:** `Report Date: 2025-10-05 - 15:30:25`

##### Advanced Placeholders

**1. Random Number Generation**

- **Usage:** `{{RANDOM:min-max}}`
- **Example:**
  ```
  Order ID: {{RANDOM:1000-9999}}
  ```
- **Result:** `Order ID: 3847` (different each time)

**2. File Content Insertion**

- **Usage:** `{{FILE:/path/to/file}}`
- **Example:**
  ```
  Signature:
  {{FILE:~/Documents/signature.txt}}
  ```
- **Result:** Inserts the content of the specified file into the snippet.

**3. Shell Command Output**

- **Usage:** `{{SHELL:command}}`
- **Example:**
  ```
  Computer Name: {{SHELL:hostname}}
  IP Address: {{SHELL:ipconfig getifaddr en0}}
  Current User: {{SHELL:whoami}}
  ```
- **Result:** Inserts the output of the shell command into the snippet.

**4. Custom Snippet Variables**

- **Usage:** `{{VARIABLE_NAME}}`
- **How to Create:** Define global variables in **Settings > Snippets > Snippet Variables**
- **Example:**

  First, define the variable:

  ```
  Variable Name: COMPANY_NAME
  Value: Acme Corporation
  ```

  Then use it in any snippet:

  ```
  Email Signature:
  {{MY_NAME}}
  {{JOB_TITLE}}
  {{COMPANY_NAME}}
  ```

- **Features:**
  - Variable values can use dynamic placeholders (`{{DATE}}`, `{{UUID}}`, etc.)
  - Available in all snippets
  - Update from a central location
  - Example: Assign `{{CLIPBOARD}}` to `MY_NAME` variable to get the current clipboard value each time

**5. Nested Snippets**

- **Usage:** `{{;snippet_name}}`
- **Example:**

  First, create a `;name` snippet:

  ```
  John Appleseed
  ```

  Then use it in another snippet:

  ```
  Meeting Notes
  Attendee: {{;name}}
  Date: {{DATE}}
  ```

- **Result:** Nested snippets are automatically expanded (maximum 5 levels deep).

**Advanced Combined Example:**

```
📅 Meeting Notes

Date: {{DATETIME}}
Attendee: {name}
Meeting ID: {{RANDOM:1000-9999}}

Notes:
{notes}

---
Signature: {{;sig}}
System: {{SHELL:sw_vers -productVersion}}
```

#### Parameterized Expansion: Interactive Snippets

Create interactive templates by adding variables in the `{parameter}` format. When you type the keyword, Clippy will open a smart window for you to fill in these variables.

**Example:**

- **Keyword:** `;email`
- **Content:** `Hello {name}, how are you?`
- **How it works:** When you type `;email`, a window opens for you to enter the "name" parameter. If you type "Mehmet" and confirm, it will paste `Hello Mehmet, how are you?`.

##### Live Preview

While filling in parameters, you can see the final result of your snippet in the **live preview** section:

- Preview updates automatically as you type in parameters
- Dynamic placeholders ({{DATE}}, {{TIME}}, etc.) are shown with their actual values
- Empty parameters are shown as `[parameter_name]`
- Preview section can be expanded/collapsed by clicking (default: expanded)

##### Smart Input Types and Default Values

Speed up data entry even more by assigning types and default values to your parameters.

- **Date Picker:** `{delivery_date:date}`
- **Dropdown Menu:** `{priority:choice:Low,Medium,High}`
- **Dropdown with Default:** `{status:choice:Active,Inactive=Active}`

**An Advanced Example:**

- **Keyword:** `;bug`
- **Content:**
  ```
  Bug Report
  - Description: {description}
  - Severity: {severity:choice:Low,Medium,High=Medium}
  - ETA: {eta:date}
  ```
- **How it works:** Typing `;bug` opens a window with an empty text box for `description`, a dropdown menu with "Medium" pre-selected for `severity`, and a calendar for `eta`.

#### Contextual Expansion: App-Specific Snippets

Make your snippets work only in specific applications to create custom tools for different workflows.

- **Code Editor-Specific Snippet:**
  - **Keyword:** `;log`
  - **Content:** `console.log('{variable}', {variable});`
  - **Application Rule:** In the snippet's detail screen, enter `com.microsoft.VSCode` in the "Application Rules" field.
  - **Result:** Now, the `;log` keyword will only work in VS Code.

#### Snippet Statistics

View usage statistics for each snippet in the detail page:

- **Usage Count:** Shows how many times the snippet has been used (with blue chart icon)
- **Last Used:** Shows when it was last used (with green clock icon, in relative time format: "5 minutes ago", "2 hours ago", etc.)

These statistics help you see which snippets you use frequently and optimize your snippet collection.

#### Import & Export

You can backup or share your snippets across different devices:

- **Export:**

  - While in the Snippets tab, **right-click** on any snippet
  - **"Export Selected Snippet"** - Exports only that snippet
  - **"Export All Snippets"** - Saves all your snippets to a single JSON file
  - File name is automatically generated as `{keyword}_snippet.json` for single snippet, `snippets_export.json` for all snippets

- **Import:**
  - Click the **down arrow (↓)** button in the **top-right corner** of the Snippets tab
  - Select the JSON file
  - Snippets with the same keyword are skipped, new ones are added
  - Shows how many snippets were successfully imported

**Example JSON Format:**

```json
[
  {
    "keyword": ";sig",
    "content": "Best regards,\nJohn Appleseed",
    "category": "General",
    "applicationRules": ""
  },
  {
    "keyword": ";log",
    "content": "console.log('{variable}', {variable});",
    "category": "Code",
    "applicationRules": "com.microsoft.VSCode"
  }
]
```

#### How It Works

- **Easy to Use:** Go to the detail screen of any text item and assign a keyword (e.g., `;sig`). The item will automatically move to the "Snippets" tab.
- **System-Wide:** Type your assigned keyword in any text field, and Clippy will expand it.
- **Performance-Focused:** All keywords are cached in memory for instant performance.
- **You're in Control:** You can disable this feature entirely in the Settings menu or temporarily pause/resume it by right-clicking the menu bar icon.

## 🚀 How to Use

1. **Opening the App:**

- Click the Clippy icon in the menu bar.
- Or, press the default shortcut `Cmd (⌘) + Shift (⇧) + V`.

2. **Pasting Items:**

- **Single Item:** Hover over an item and click the "Paste" button.
- **Multiple Items:** Hold down `Cmd (⌘)` and click to select the items you want. Click the **"Paste All"** button that appears at the bottom of the window or use its shortcut (`Cmd (⌘) + Shift (⇧) + P`).

3. **Other Actions (Right-Click Menu):**

- Right-click on an item to access all advanced actions like **Copy, Encrypt/Decrypt, Compare, Delete**, etc.

4. **Favoriting and Pinning:**

- Click the star (`☆`) icon to the left of any item to add or remove it from your favorites.
- Click the pin (`📌`) icon next to the star to pin important items to the top of the list.

5. **Settings:**

- **Right-click** the Clippy icon in the menu bar and select "Settings...".
- Or, use the standard macOS shortcut `Cmd (⌘) + ,`.

## ⌨️ Default Shortcuts

| Action                  | Shortcut                      |
| ----------------------- | ----------------------------- |
| Show/Hide App           | `Cmd (⌘)` + `Shift (⇧)` + `V` |
| Paste Selected          | `Cmd (⌘)` + `Shift (⇧)` + `P` |
| Add to Sequential Queue | `Cmd (⌘)` + `Shift (⇧)` + `C` |
| Paste Next in Sequence  | `Cmd (⌘)` + `Shift (⇧)` + `B` |
| Clear Sequential Queue  | `Cmd (⌘)` + `Shift (⇧)` + `K` |
| Take Screenshot         | `Cmd (⌘)` + `Shift (⇧)` + `1` |
| Multi-Item Selection    | `Cmd (⌘)` + Click             |
| Open Settings           | `Cmd (⌘)` + `,`               |

> **Note:** All keyboard shortcuts are fully customizable in the Settings menu.

## 🛠️ Installation and Security

### Installation

Download the latest `.dmg` file from the Releases page. Open the DMG file and drag the **Clippy** app into your **Applications** folder.

### Security Permissions

Clippy needs **Accessibility** permission to paste text into other applications.

The app will automatically show you a system prompt when it needs this permission. You can click the **"Open System Settings"** button in the prompt to go directly to the relevant settings menu and enable permission for Clippy.

> **Privacy:** Clippy never sends your clipboard data to the internet. All your data is stored securely on your computer in the `~/Library/Application Support/Clippy/` folder, within a **Core Data** database (`Clippy.sqlite`).

## 💖 Support & Contribute

Do you enjoy using Clippy? There are several ways you can support the project's development:

- **⭐ Give it a Star:** Starring the project on GitHub helps it reach more people.
- **🐞 Report Bugs:** If you encounter a bug or think a feature could work better, please open an Issue.
- **💡 Share Your Ideas:** I'd love to hear your suggestions for new features!
- **☕ Buy Me a Coffee:** If the app is useful to you and you want to support its development, you can buy me a coffee.

Every bit of support is a huge motivation to make the project even better!

---

_This project was developed to enhance productivity and simplify clipboard management._
