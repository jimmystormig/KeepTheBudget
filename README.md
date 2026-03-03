# KeepTheBudget

Office 365 Calendar Time Tracker - macOS Menu Bar Application

## Overview

KeepTheBudget is a native macOS menu bar application that helps you track your scheduled time from Office 365 Calendar. It displays daily and weekly time summaries with visual warnings when you exceed your configured goals.

## Features

- **Daily Summary**: Total hours/minutes for today (midnight to now)
- **Weekly Summary**: Total hours/minutes for current week (Monday-Sunday)
- **Smart Filtering**: Only counts your own calendar entries (filters out meeting invites from others)
- **Real-time Updates**: Automatically polls every 10 minutes for calendar changes
- **Goal Tracking**: Visual warning (red icon) when scheduled hours exceed daily/weekly goals
- **All-day Events**: Automatically counts all-day events as 8 hours
- **Secure Authentication**: Uses Microsoft OAuth 2.0 with MSAL for secure access
- **Calendar Selection**: Choose which calendar to track during setup
- **Configurable Goals**: Set custom target hours per day and week

## Requirements

- macOS 12.0 or later
- Office 365 account
- Xcode 14.0 or later (for building from source)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/jimmystormig/KeepTheBudget.git
   cd KeepTheBudget
   ```

2. Open the project in Xcode:
   ```bash
   open KeepTheBudget.xcodeproj
   ```

3. Build and run the project:
   - Select "KeepTheBudget" scheme
   - Click Run (⌘R)

Alternatively, build from command line:
```bash
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Release build
```

The built app will be located at:
```
./Build/Products/Release/KeepTheBudget.app
```

## First-Time Setup

1. **Launch the App**: The app will appear in your menu bar (top-right corner)

2. **Sign In**: On first launch, you'll see a sign-in prompt
   - Click "Sign In"
   - A browser window will open for Microsoft authentication
   - Sign in with your Office 365 account
   - Grant the requested permissions:
     - Calendars.Read (to read your calendar events)
     - User.Read (to identify your account)
     - offline_access (to refresh tokens automatically)

3. **Select Calendar**: After authentication, choose which calendar to track
   - Select your primary work calendar or any other calendar
   - Click "Continue"

4. **Start Tracking**: The app will immediately start tracking your scheduled time
   - The menu bar shows: "6h 30m / 32h 15m" (Daily / Weekly)
   - Click the menu bar item to see detailed stats

## Usage

### Menu Bar Display

The menu bar shows your current time totals:
```
[Icon] 6h 30m / 32h 15m
       ↑ Daily  ↑ Weekly
```

**Icon States:**
- 🕐 Normal clock (blue) - Within goals
- 🔴 Red warning - Exceeding daily or weekly goals
- ⏳ Spinner - Loading/updating
- ⚠️  Gray X - Error

### Popover Menu

Click the menu bar item to see:
- Detailed daily and weekly summaries
- Progress bars showing percentage of goals
- Last update timestamp
- Quick actions:
  - Refresh Now
  - Open Preferences
  - Quit

### Preferences

Access preferences from the popover menu:

**Goals Tab:**
- Set daily goal (default: 8 hours)
- Set weekly goal (default: 40 hours)
- Configure update interval (default: 10 minutes)

**Calendar Tab:**
- Change which calendar to track
- Select a different Office 365 calendar

**Account Tab:**
- View signed-in account
- Sign out (requires re-authentication on next launch)

**About Tab:**
- App version and information

## How It Works

### Time Calculation

- **Daily Total**: Sum of all events from midnight (local time) until now
- **Weekly Total**: Sum of all events from Monday 00:00 to Sunday 23:59
- **All-Day Events**: Counted as 8 hours (480 minutes)
- **Timed Events**: Actual duration from start to end time

### Event Filtering

The app only counts events where YOU are the organizer:
- Your own calendar entries: ✅ Counted
- Meeting invites from others: ❌ Not counted
- This ensures you only track time you've scheduled, not meetings others invited you to

### Goal Status

- **Normal**: Your scheduled time is within your goals
- **Over Goal**: Either daily OR weekly time exceeds the configured goal
  - Menu bar icon turns RED
  - Warning indicator shown in popover

### Updates

- **Automatic**: Every 10 minutes (configurable)
- **Manual**: Click "Refresh Now" in popover
- **Efficient**: Uses Microsoft Graph API delta queries to minimize data transfer

## Troubleshooting

### Authentication Issues

**Problem**: "Authentication failed" error

**Solutions**:
1. Check your internet connection
2. Ensure you're using a valid Office 365 account
3. Try signing out and signing in again
4. Check that you granted all requested permissions

### No Events Showing

**Problem**: Time shows "0h 0m" despite having events

**Solutions**:
1. Verify you selected the correct calendar
2. Check that events are in YOUR calendar (not just invites)
3. Ensure events have you listed as the organizer
4. Click "Refresh Now" to force an update

### Token Expired

**Problem**: "No account found" or "Please re-authenticate"

**Solution**:
- The app will automatically show the sign-in prompt
- Sign in again to refresh your authentication

### App Not Updating

**Problem**: Last update time is old

**Solutions**:
1. Click "Refresh Now" manually
2. Check update interval in Preferences
3. Restart the app
4. Check your network connection

## Privacy & Security

- **Token Storage**: Access and refresh tokens are securely stored in macOS Keychain
- **Permissions**: App only requests minimal necessary permissions
- **Data**: No calendar data is stored locally; all data is fetched in real-time
- **Network**: All communication uses HTTPS with Microsoft's official endpoints

## Architecture

### Tech Stack

- **Language**: Swift 5.9
- **UI**: SwiftUI + AppKit (for menu bar)
- **Authentication**: MSAL (Microsoft Authentication Library)
- **API**: Microsoft Graph API v1.0
- **Storage**: Keychain (tokens) + UserDefaults (preferences)

### Project Structure

```
KeepTheBudget/
├── App/                     # Main app entry point
├── Models/                  # Data models
├── Services/                # Business logic
│   ├── AuthManager          # OAuth authentication
│   ├── GraphAPIService      # Microsoft Graph API
│   ├── TimeCalculator       # Time calculations
│   ├── StorageManager       # Data persistence
│   └── UpdateScheduler      # Periodic updates
├── Views/                   # SwiftUI views
│   ├── PopoverView          # Main menu
│   ├── SettingsView         # Preferences
│   ├── CalendarSelectionView
│   └── Components/          # Reusable UI components
└── Utilities/               # Helper classes
```

## Development

### Building

```bash
# Build debug version
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Debug build

# Build release version
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Release build
```

### Running

```bash
# Run from Xcode
open KeepTheBudget.xcodeproj

# Or run the built app
open Build/Products/Debug/KeepTheBudget.app
```

### Code Signing

For distribution, you'll need an Apple Developer account:

1. Open project in Xcode
2. Select target "KeepTheBudget"
3. Go to "Signing & Capabilities"
4. Select your development team
5. Xcode will handle code signing automatically

For personal use only (current Mac):
- The default ad-hoc signing is sufficient
- App can be run directly from build directory

## Known Limitations

1. **Single Calendar**: Currently tracks one calendar at a time
2. **Local Time Zone**: All calculations use local time zone
3. **Manual Refresh**: No real-time push notifications (polls every 10 minutes)
4. **No Historical Data**: Only shows current day/week (no past weeks view)

## Future Enhancements

- [ ] Multiple calendar support
- [ ] Historical view (past weeks/months)
- [ ] Export reports (CSV/PDF)
- [ ] Notifications when approaching goals
- [ ] Event categorization by project
- [ ] Configurable all-day event duration
- [ ] Launch at login option
- [ ] Customizable menu bar format

## Support

For issues, questions, or feature requests:
- [Create an issue](https://github.com/jimmystormig/KeepTheBudget/issues)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

- Built with ❤️ using Swift and SwiftUI
- Authentication powered by MSAL
- Calendar data from Microsoft Graph API

---

**Version**: 1.0.0
**Last Updated**: January 2026
