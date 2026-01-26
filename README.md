# Desktop Declutter

A macOS app to help declutter your desktop. Review files quickly with a swipe-based interface, get smart suggestions for related files, and organize your desktop efficiently.

Built with SwiftUI using Cursor and Composer-1. May have bugs - feel free to improve or modify as needed.


## Features

### Core
- Swipe-based file review (left to bin, right to keep)
- Smart suggestions that detect:
  - 📋 Duplicate files (same name and size)
  - 🔤 Files with similar names (e.g., screenshots with timestamps)
  - 📅 Old files (older than 1 year)
  - 💾 Large files (over 50MB)
  - 🕐 Files from the same session (created within same time period)
  - 🗑️ Temporary files (common temp file patterns)
- Group review mode - review related files together with smart actions
- Quick Look preview (in-app, doesn't open Finder)
- Stack files for later review
- Review binned files before final deletion (when immediate binning is off)
- Undo/redo support
- File type filtering (images, videos, documents, etc.)
- Progress tracking and statistics

### UI/UX
- Material blur effects
- Thumbnail generation for images/documents
- Keyboard shortcuts for all actions
- Resizable window
- Settings to toggle immediate vs delayed binning

## How It Works

1. Launch the app - scans your Desktop folder
2. Review files one by one:
   - Swipe right or press `→` to keep
   - Swipe left or press `←` to bin
   - Press `S` to stack for later
   - Press `Spacebar` to preview
3. When you see suggestion badges, tap them to review related files together
4. In group review, use smart action cards or manually select files
5. Review stacked/binned files before final deletion

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `→` | Keep current file |
| `←` | Bin current file |
| `S` | Stack current file |
| `Spacebar` | Preview file |
| `⌘Z` | Undo last action |
| `ESC` | Close Quick Look |

## Installation

### Requirements
- macOS 13.0+ (Ventura or later)
- Swift 5.9+
- Xcode Command Line Tools

### Build

```bash
git clone https://github.com/yourusername/DesktopDeclutter.git
cd DesktopDeclutter
swift build
swift run
```

### Permissions

On first launch, grant **Full Disk Access** in System Settings:
- System Settings → Privacy & Security → Full Disk Access
- Add Desktop Declutter
- Restart the app

## Usage

### Basic Flow
- Files appear as cards - swipe or use keyboard shortcuts
- Preview files with spacebar (Quick Look opens in-app)
- Tap suggestion badges to review related files together
- Use smart action cards in group review for quick decisions
- Review stacked/binned files before final deletion

### Settings
- Toggle "Trash Immediately" - when OFF, files are collected for review before deletion

## Technical Details

- Built with SwiftUI
- Uses QuickLookThumbnailing for thumbnails
- Uses QuickLookUI for in-app preview
- Swift Package Manager for dependencies
- No external dependencies (pure Swift/macOS)

## Known Issues / Limitations

- May have bugs - this was built with AI assistance (Cursor/Composer-1)
- Thumbnail generation can be slow for many files
- Quick Look preview might not work perfectly in all scenarios
- Performance may degrade with very large desktop collections (100+ files)

## Contributing

Feel free to:
- Report bugs
- Suggest improvements
- Submit pull requests
- Fork and modify for your needs

This is an open project - contributions welcome.

## License

MIT License

---

Built with Cursor and Composer-1. Use at your own risk.
