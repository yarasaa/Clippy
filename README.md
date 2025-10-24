# Clippy for macOS

<p align="center">
  <a href="https://buymeacoffee.com/12hrsofficp" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>
</p>

Clippy is a powerful macOS menu bar application designed for developers and power users to manage their clipboard history. It saves everything you copy, allowing you to quickly access, organize, and use your clipboard items.

![1759521906350](image/README/1759521906350.png)

![1759522032838](image/README/1759522032838.png)

![1759522217489](image/README/1759522217489.png)

![1759522386365](image/README/1759522386365.png)

![1759522392271](image/README/1759522392271.png)

![1759522474906](image/README/1759522474906.png)

![1759522498669](image/README/1759522498669.png)

![1759522601059](image/README/1759522601059.png)

## ✨ Features

### 📋 Core Clipboard Management

- **History Recording:** Automatically saves all text and images you copy.
- **Quick Access & Interface:** Instantly access your clipboard history by clicking the menu bar icon or using a keyboard shortcut.
- **Search:** Instantly search through your entire history.
- **Favorites:** Star your frequently used items to prevent them from being deleted and find them quickly.
- **Code Detection:** Automatically detects if copied text is code and organizes it in a separate "Code" tab.
- **Custom Titles:** Add a custom title to any clipboard item for easier identification. Titles can be edited in the detail view and are prominently displayed above the content in the main list.
- **Source App Icons:** Easily track where each item was copied from with icons of the source application.

### Advanced Functionality

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
- **Quick Text Preview:** Hover over a text item to see its full content in the system's standard help tooltip.
- **Encryption:** Encrypt sensitive data with a single click from the context menu. The content of encrypted items remains hidden until you decrypt them.
- **Smart Detection:**
  - **Calendar Event:** When you copy text like "Meeting tomorrow at 2 PM," Clippy detects it and offers to add it to your calendar with one click.
  - **JSON Viewer:** Automatically detects copied JSON text and displays it in a hierarchical tree structure in the detail view. You can edit, validate, and copy keys/values/paths from this view.
  - **Text Recognition from Images (OCR):** In the detail view of an image, recognize the text within it and add it as a new, copyable text item.
  - **URL & Color Detection:** If copied text is a URL, a button to open it in the browser appears. If it's a color code (hex/rgb), a color swatch is displayed.
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

### 🛠️ Smart Tools & Developer Features

- **Diff Viewer:** Compare two selected text items side-by-side with character-level highlighting of differences.
- **JSON Viewer:** Automatically detects copied JSON text and displays it in a hierarchical tree structure in the detail view. You can edit, validate, and copy keys/values/paths from this view.
- **Calendar Event Detection:** When you copy text like "Meeting tomorrow at 2 PM," Clippy detects it and offers to add it to your calendar with one click.
- **Encryption:** Encrypt sensitive data with a single click from the context menu. The content of encrypted items remains hidden until you decrypt them.

### ⚙️ Customization and Settings

- **Interface Customization:** Adjust the main window's width and height. Choose your preferred theme (Light, Dark, or System Default) for a personalized look across the entire app.
- **Customizable Shortcuts:** Set your own keyboard shortcuts for both toggling the app and the "Paste All" function.
- **Language Support:** Use the app in English or Turkish.
- **Tab Management:** Hide the "Code," "Images," "Snippets," or "Favorites" tabs if you don't need them.
- **Limit Settings:** Define the maximum number of items to keep in your history and favorites.
- **Launch at Login:** Have Clippy start automatically when you log in to your Mac.
- **Modern Settings Window:** Settings are grouped under "General," "Shortcuts," and "Advanced" tabs for a cleaner and more user-friendly experience.
- **Sleep Mode Support:** After your computer wakes from sleep, all of Clippy's features (clipboard monitoring, shortcuts, keyword expansion) are automatically restarted and continue to work seamlessly.

### ⚡️ Performance & Optimization

- **Efficient Loading:** With Core Data batch fetching and thumbnail caching, the app now loads and scrolls through long lists of items, especially images, much faster and with significantly less memory usage.

### ⌨️ Keyword Expansion (Snippet Expansion)

This feature takes your productivity to the next level by turning static text snippets into dynamic, interactive, and context-aware templates. Snippets are now organized in their own dedicated **"Snippets"** tab for easy access and management.

#### 1. Dynamic Content: Snippets with Live Data

Embed "magic words" into your snippets to have them automatically filled with up-to-date information.

- **Add the Current Date:**

  - **Keyword:** `;today`
  - **Content:** `Report Date: {{DATE}}`
  - **Result:** `Report Date: 2025-10-05`

- **Generate a Unique ID (UUID):**
  - **Keyword:** `;guid`
  - **Content:** `New User ID: {{UUID}}`
  - **Result:** `New User ID: A9A4E42D-3C6F-4E8B-9F3C-1A2B3C4D5E6F`

#### 2. Parameterized Expansion: Interactive Snippets

Create interactive templates by adding parameters like `{parameter}` to your snippets. When you type the keyword, Clippy opens a smart dialog to fill in the variables.

##### Smart Input Types

Speed up and simplify data entry by assigning types to your parameters.

- **Date/Time Picker:** Use `{due_date:date}` or `{meeting:time}` to open a calendar or time picker.
- **Dropdown Menu:** Provide predefined options with `{priority:choice:Low,Medium,High}`.

##### Default Values

Save time by assigning default values to your parameters.

- **Example:** With `{subject=Weekly Report}`, the "subject" field will come pre-filled with "Weekly Report".

##### All-in-One: An Advanced Example

- **Bug Report Template:**
  - **Keyword:** `;bug`
  - **Content:**
    ```
    Bug Report
    - Description: {description}
    - Criticality: {criticality:choice:Low,Medium,High=Medium}
    - Assignee: {assignee=Mehmet Akbaba}
    ```
  - **How it works:** Typing `;bug` opens a dialog with a text field for `description`, a dropdown for `criticality` (pre-selected to "Medium"), and a pre-filled text field for `assignee`.

#### 3. Contextual Expansion: App-Specific Snippets

Create specialized tools for different workflows by making your snippets work only in specific applications.

- **Code-Editor-Only Snippet:**
  - **Keyword:** `;log`
  - **Content:** `console.log('{variable}', {variable});`
  - **Application Rule:** In the snippet's detail screen, enter `com.microsoft.VSCode` in the "Application Rules" field.
  - **Result:** The `;log` keyword will now only work in Visual Studio Code.

#### How It Works

- **Easy to Use:** Go to the detail screen of any text item and assign a keyword (e.g., `;sig`). The item will automatically move to the "Snippets" tab.
- **System-Wide:** Type your assigned keyword in any text field, and Clippy will expand it.
- **Performance-Focused:** All keywords are cached in memory for instant performance.
- **You're in Control:** You can disable this feature entirely in the Settings menu or temporarily pause/resume it by right-clicking the menu bar icon.

## 🚀 How to Use

1. **Toggling the App:**

   - Click the Clippy icon in the menu bar.
   - Or, press the default shortcut `Cmd (⌘) + Shift (⇧) + V`.

2. **Pasting Items:**

   - **Single Item:** Hover over an item and click the "Paste" button.
   - **Multiple Items:** Hold down `Cmd (⌘)` and click to select the items you want. Click the **"Paste All"** button that appears at the bottom of the window or use its shortcut (`Cmd (⌘) + Shift (⇧) + P`).

3. **Other Actions (Context Menu):**

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
