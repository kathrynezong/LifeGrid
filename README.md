# LifeGrid

LifeGrid is a reflective life-journaling app that combines a calendar grid, daily planning/reflection, and memory photos to help users make each day meaningful.

## Why LifeGrid

LifeGrid is designed around one idea: seeing time clearly helps people spend it better.

The app gives users:
- a visual life timeline,
- a daily practice for planning and reflection,
- and a memory layer through photos and monthly recap.

## Core Features

### 1. Life Progress Dashboard
- Shows age, estimated life expectancy range, and total logged days.
- Displays a progress bar for lived vs remaining time.
- Shows average days left and key milestone markers.

### 2. Calendar Life Grid
- Monthly calendar with day-by-day entries.
- Color-coded day quality at a glance.
- Month navigation controls (`Previous`, `Next`, `Today`).
- Optional day thumbnail image (user-selected; default is no thumbnail).

### 3. Day View (Planning + Reflection)
- Morning planning section.
- Evening reflection section.
- Mood and quality score tracking.
- Tag-based activity tracking.
- Auto-save on close (no separate Save button required).

### 4. Memories
- Add multiple photos to a day.
- Swipeable memory carousel in day view.
- Card-style full photo viewer popup.
- Monthly auto-cycling recap popup (Month at a Glance).

### 5. Tags and Categories
- Quick tags grouped by category.
- Users can create custom tags.
- Users can choose which category custom tags belong to.
- Added tags appear in the same chip style as built-in tags.

### 6. Analytics
- 30-day score trend chart.
- Quality distribution chart.
- Streak and total logged day stats.
- Search and filters across history (mood, tag, minimum score).

### 7. Settings and Reminders
- Profile and expectancy context.
- Morning/evening reminder scheduling.
- Data management actions.
- AI reflection settings for guided prompts.

## Tech Stack

- SwiftUI
- Core Data
- Charts framework
- PhotosUI
- iOS Speech + AVFoundation (voice entry)

## Getting Started

### Requirements
- Xcode 15+
- iOS 17+ (recommended)
- macOS (for development)

### Run Locally
1. Open `LifeGrid.xcodeproj` in Xcode.
2. Select an iOS Simulator (or device).
3. Build and run.

## Project Structure

- `ContentView.swift`: Main UI, tabs, calendar grid, day editor, memories, analytics.
- `Persistence.swift`: Core Data stack and model extensions.
- `LifeGridApp.swift`: App entry point.
- `LifeGrid.xcdatamodeld/`: Data model definitions.

## Current UX Notes

- Day entries auto-save when the editor closes.
- Calendar thumbnails are opt-in via day-level thumbnail selection.
- Month Recap auto-cycles photos so users can watch passively.

## Roadmap

### MVP (Current)
- Life dashboard
- Daily logging + reflection
- Memory photos + monthly recap
- Analytics + reminders

### V2
- Export/backup (JSON/CSV)
- Richer photo interactions (zoom, captions)
- More flexible tag/category management (edit/delete categories)
- Improved onboarding and expectancy explanation UI

### V3
- Habit/goal overlays on the life grid
- Insight summaries from trends and tags
- Optional sharing/private timeline views

## Contributing

If this is used by multiple collaborators:
1. Create a feature branch.
2. Keep PRs focused by feature area (`calendar`, `memories`, `analytics`, etc.).
3. Include screenshots for UI changes.

## License

No license specified yet.
