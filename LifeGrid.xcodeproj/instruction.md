# LifeGrid - Life Tracking iOS App
 
A comprehensive iOS app to plan, track, and assess each day of your life.
 
## Features
 
### Core Features (MVP)
- **Life Expectancy Calculator**: Calculates estimated life expectancy based on health factors
- **Visual Life Grid**: See your entire life as a grid of colored cells (last 365 days)
- **Daily Entry System**: Log quality score (1-10), mood, activities, and diary text
- **Photo Support**: Add photos to your daily entries
- **Daily Notifications**: Morning planning and evening reflection reminders
- **Analytics Dashboard**: View trends, streaks, and quality distribution
- **Local Storage**: All data stored securely with Core Data
 
### Tech Stack
- SwiftUI for UI
- Core Data for persistence
- UserNotifications for reminders
- PhotosUI for photo selection
- Charts framework for analytics (iOS 16+)
 
## Setup Instructions
 
### Prerequisites
- macOS with Xcode 14+ installed
- iOS 16.0+ target device or simulator
- Apple Developer account (for App Store deployment)
 
### Installation
 
1. Open the project in Xcode:
   ```bash
   cd LifeGrid
   open LifeGrid.xcodeproj
   ```
 
2. If Xcode doesn't open, create a new iOS App project in Xcode:
   - File > New > Project
   - Choose "iOS App"
   - Product Name: LifeGrid
   - Interface: SwiftUI
   - Language: Swift
   - Storage: Core Data
   - Then copy all the source files into the project
 
3. Build and run:
   - Select a simulator or connected device
   - Press Cmd+R to build and run
 
### Project Structure
```
LifeGrid/
├── LifeGridApp.swift          # App entry point
├── Models/
│   ├── UserProfile.swift      # User profile Core Data model
│   └── DayEntry.swift         # Daily entry Core Data model
├── Views/
│   ├── ContentView.swift      # Main tab view
│   ├── OnboardingView.swift   # Initial setup
│   ├── LifeGridView.swift     # Grid visualization
│   ├── TodayView.swift        # Daily entry form
│   ├── DayDetailView.swift    # View/edit past entries
│   ├── AnalyticsView.swift    # Trends and insights
│   └── SettingsView.swift     # App settings
├── Services/
│   ├── PersistenceController.swift      # Core Data setup
│   ├── LifeExpectancyCalculator.swift   # Life expectancy logic
│   └── NotificationService.swift        # Daily reminders
└── LifeGrid.xcdatamodeld/     # Core Data schema
 
```
 
## Usage
 
### First Launch
1. Complete onboarding with your birth date, country, gender, and health factors
2. Grant notification permissions for daily reminders
3. Start logging your first day!
 
### Daily Workflow
1. **Morning**: Receive "Plan your day" notification
2. **Throughout the day**: Live your life!
3. **Evening**: Receive "Time to Reflect" notification
4. **Log your day**: Rate quality (1-10), add mood, activities, diary entry, and photo
 
### Views
- **Grid Tab**: Visual representation of your life with stats
- **Today Tab**: Quick entry form for today
- **Analytics Tab**: 30-day trends, streaks, and quality distribution
- **Settings Tab**: Manage notifications and view profile
 
## Customization
 
### Notification Times
- Default: 8:00 AM (morning), 8:00 PM (evening)
- Customize in Settings tab
 
### Life Expectancy Factors
Adjust in `LifeExpectancyCalculator.swift`:
- Base expectancy by country and gender
- Smoking: -10 years
- Chronic conditions: -5 years
 
## Future Enhancements (Phase 2 & 3)
 
### Phase 2
- [ ] Audio/video diary entries
- [ ] iCloud sync
- [ ] Data export (PDF, CSV)
- [ ] Advanced analytics
- [ ] Multiple photos per day
 
### Phase 3
- [ ] Apple Watch app
- [ ] Home screen widgets
- [ ] Siri shortcuts
- [ ] Goal tracking
- [ ] Habit integration
- [ ] Weather integration
- [ ] Location tagging
 
## App Store Deployment
 
### Requirements
1. Apple Developer account ($99/year)
2. App icons (1024x1024 required)
3. Privacy policy URL
4. Screenshots for App Store listing
5. App description and keywords
 
### Steps
1. Archive the app (Product > Archive)
2. Upload to App Store Connect
3. Fill in app metadata
4. Submit for review (typically 1-2 weeks)
 
## Privacy & Security
- All data stored locally on device
- No analytics or tracking
- Optional iCloud sync (Phase 2)
- Face ID/Touch ID lock (Phase 3)
 
## License
MIT License - Feel free to modify and distribute
 
## Support
For issues or questions, contact: support@lifegrid.app
 
---
 
**Built with ❤️ to help you make every day count**