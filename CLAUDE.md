# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KeepTheBudget is a macOS menu bar application that tracks scheduled time from Office 365 Calendar. It displays daily and weekly time summaries with visual warnings when exceeding configured goals.

**Tech Stack:**
- Swift 5.9 / SwiftUI + AppKit
- macOS 12.0+ deployment target
- MSAL (Microsoft Authentication Library) for OAuth 2.0
- Microsoft Graph API v1.0 for calendar data

## Build Commands

### Building the Project

```bash
# Build debug version
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Debug build

# Build release version
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Release build

# Open in Xcode
open KeepTheBudget.xcodeproj
```

### Running the App

```bash
# From Xcode: Press ⌘R

# From command line (after building)
open ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Debug/KeepTheBudget.app
```

### Project Generation

This project uses XcodeGen. If you modify `project.yml`, regenerate the Xcode project:

```bash
xcodegen generate
```

## Architecture

### Service Layer Pattern

The app uses a clean service-oriented architecture with clear separation of concerns:

**AppDelegate** (`App/AppDelegate.swift`)
- Central coordinator for the entire application lifecycle
- Manages menu bar status item and popover
- Orchestrates authentication flow, calendar selection, and data refresh
- Creates and coordinates all services
- Handles all NSWindow lifecycle operations (must run on main thread)

**Services** (`Services/`)
- `AuthManager`: OAuth 2.0 authentication with MSAL, token management, silent refresh, lazy initialization
- `GraphAPIService`: Microsoft Graph API client (user profile, calendars, events)
- `TimeCalculator`: Daily/weekly time range calculations and event duration totals
- `StorageManager`: Keychain (tokens, MSAL config) and UserDefaults (preferences) persistence
- `UpdateScheduler`: Background timer for periodic data refresh

**Utilities** (`Utilities/`)
- `ConfigurationValidator`: UUID format validation for Client ID and Tenant ID
- `MigrationManager`: Auto-migration from hardcoded credentials to Keychain
- `KeychainHelper`: Secure credential storage wrapper
- `TimeFormatter`: Time formatting utilities

**Models** (`Models/`)
- `CalendarEvent`: Graph API event with organizer filtering
- `TimeSummary`: Daily/weekly totals with goal status calculation
- `AppPreferences`: User settings (goals, calendar ID, refresh interval)
- `GoalStatus`: Enum for tracking goal state (underGoal, onTarget, overGoal)

**Views** (`Views/`)
- `PopoverView`: Main menu displaying time summary and actions
- `SettingsView`: Custom tabbed preferences window (Goals, Calendar, Account, Configuration, About)
- `DeviceCodeView`: OAuth authentication UI with browser redirect
- `CalendarSelectionView`: Calendar picker during setup
- `ConfigurationSetupView`: First-launch MSAL configuration screen

### Data Flow

1. **Configuration Check**: App launch → `MigrationManager` auto-migrates existing users → Check Keychain for Client ID/Tenant ID
2. **Lazy Initialization**: `AuthManager.initialize()` called after config verified → Loads credentials from Keychain → Initializes MSAL
3. **Authentication**: `AuthManager` → MSAL interactive auth → Tokens saved to Keychain
4. **Calendar Selection**: `GraphAPIService` fetches calendars → User selects → ID saved to UserDefaults
5. **Data Refresh**: `UpdateScheduler` triggers → `GraphAPIService` fetches events → `TimeCalculator` computes totals → `AppDelegate` updates UI
6. **Event Filtering**: Only counts events where user is the organizer (filters out meeting invites)

## Critical Threading Requirements

**IMPORTANT**: AppKit is not thread-safe. All UI operations must run on the main thread.

### Main Thread Operations

Always wrap NSWindow, NSStatusItem, and NSView operations in `await MainActor.run {}`:

```swift
// ✅ CORRECT
private func showWindow() async {
    await MainActor.run {
        let window = NSWindow(...)
        window.makeKeyAndOrderFront(nil)
    }
}

// ❌ WRONG
private func showWindow() async {
    let window = NSWindow(...)  // CRASH: Not on main thread
    window.makeKeyAndOrderFront(nil)
}
```

**Key Locations:**
- `AppDelegate.showConfigurationSetup()` - Configuration UI creation
- `AppDelegate.showDeviceCodeFlow()` - Authentication UI creation
- `AppDelegate.showCalendarSelection()` - Calendar picker UI creation
- `AppDelegate.refreshData()` - All UI updates
- `AppDelegate.updateStatusItemDisplay()` - Called from main thread
- `AppDelegate.openSettings()` - Settings window creation

**Critical Pattern**: All SwiftUI views must be created inside `MainActor.run {}` before passing to `NSHostingView`:

```swift
// ✅ CORRECT
await MainActor.run {
    let view = MySwiftUIView(...)
    window.contentView = NSHostingView(rootView: view)
    window.makeKeyAndOrderFront(nil)
}

// ❌ WRONG - View created off main thread
let view = MySwiftUIView(...)
await MainActor.run {
    window.contentView = NSHostingView(rootView: view)  // CRASH
}
```

### State Management

The `@Published` properties in `AppDelegate` must be updated on main thread:
- `timeSummary: TimeSummary?`
- `isLoading: Bool`
- `lastUpdateTime: Date?`
- `errorMessage: String?`

See `BUGFIX_THREAD_SAFETY.md` for detailed explanation of threading fixes.

## Microsoft Graph API Integration

### Authentication Flow

**Prerequisites**: `AuthManager.initialize()` must be called before any auth operations
- Loads Client ID and Tenant ID from Keychain
- Creates MSAL authority URL
- Initializes `MSALPublicClientApplication`
- Validates redirect URI against Info.plist

**Flow Steps**:
1. **Interactive Auth**: Opens system browser for OAuth 2.0 consent
2. **Token Storage**: Access token + expiry saved to Keychain (managed by StorageManager)
3. **Silent Refresh**: Automatic token refresh when expired using MSAL cache
4. **Scopes Required**: `Calendars.Read`, `User.Read`

**Error Handling**: `AuthManager` throws `AuthError.notInitialized` if auth methods called before `initialize()`

### API Endpoints Used

- `GET /me` - User profile (for organizer email filtering)
- `GET /me/calendars` - List available calendars
- `GET /me/calendars/{id}/events` - Fetch events with OData filters

### Event Filtering Logic

Events are filtered server-side with OData and client-side:

```swift
// Server-side: Date range filter
$filter=start/dateTime ge '2026-01-20T00:00:00' and end/dateTime le '2026-01-20T23:59:59'

// Client-side: Organizer filter (AppDelegate.swift:303)
let ownEvents = events.filter {
    $0.organizerEmail.caseInsensitiveCompare(userProfile.mail) == .orderedSame
}
```

**Critical**: Only user-organized events count toward time totals.

### Pagination Handling

Graph API returns max 100 events per page. `GraphAPIService.fetchEvents()` handles pagination with `@odata.nextLink` (lines 45-93).

## Secure Configuration Architecture

### MSAL Credentials Storage

**CRITICAL**: Client ID and Tenant ID are **NOT hardcoded** in source code. They are stored securely in macOS Keychain.

**Storage Location**: Keychain (via `StorageManager`)
- `KeychainKeys.clientId` = "msal_client_id"
- `KeychainKeys.tenantId` = "msal_tenant_id"

**First Launch Flow**:
1. App checks `StorageManager.hasConfiguration()`
2. If missing → Shows `ConfigurationSetupView` (user must enter credentials)
3. Values validated with `ConfigurationValidator.isValidClientId()` and `isValidTenantId()`
4. Saved to Keychain
5. `AuthManager.initialize()` called to load credentials and setup MSAL

**Existing User Migration**:
- `MigrationManager.migrateConfigurationIfNeeded()` runs on app launch
- Detects existing users by checking for saved tokens
- Auto-migrates legacy hardcoded values to Keychain (one-time only)
- See `MigrationManager.swift` for hardcoded legacy values used during migration

**Reconfiguration**:
- Settings → Configuration tab allows viewing/changing credentials
- Changes require sign-out and app restart
- Warning shown if Client ID doesn't match Info.plist URL scheme

### Constants.swift

**Current Contents**:
- Graph API endpoints and scopes only
- **NO client ID or tenant ID** (removed for security)
- `GraphConstants.scopes`: `["Calendars.Read", "User.Read"]`

### Info.plist

Required URL scheme for MSAL redirect:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msal{clientId}</string>
        </array>
    </dict>
</array>
```

### Entitlements

Required for network access and sandboxing:
- `com.apple.security.network.client` - Outgoing connections
- `com.apple.security.app-sandbox` - App sandboxing

## Time Calculation Logic

### Daily Time

- **Range**: Midnight (00:00) to current time today
- **Calculation**: Sum of all event durations in range
- **All-day events**: Counted as 8 hours (480 minutes)

### Weekly Time

- **Range**: Monday 00:00 to Sunday 23:59 of current week
- **Week Start**: Monday (ISO 8601 standard)
- **Calculation**: Sum of all event durations in range

**Implementation**: `TimeCalculator.swift:getDailyRange()` and `getWeeklyRange()`

### Goal Status

Computed in `TimeSummary.swift`:
- `underGoal`: < 95% of goal
- `onTarget`: 95% - 100% of goal
- `overGoal`: > 100% of goal

**Visual Warning**: Menu bar shows red text when either daily OR weekly is overGoal.

## Menu Bar UI

### Status Item Display

Format: `🕐 6h 30m / 32h 15m` (daily / weekly)

**Color Coding**:
- Normal: System color
- Over goal: Red text for exceeding value(s)
- Loading: Clock icon with "Loading..."
- Error: Warning triangle with "Error"

**Implementation**: `AppDelegate.updateStatusItemDisplay()` (line 95)

### Attributed String Color

Only the over-goal value(s) turn red, not the separator:

```swift
// Daily red if over
let dailyAttributes: [NSAttributedString.Key: Any] =
    summary.dailyStatus == .overGoal ? [.foregroundColor: NSColor.red] : [:]

// Separator stays normal
attributedTitle.append(NSAttributedString(string: " / "))

// Weekly red if over
let weeklyAttributes: [NSAttributedString.Key: Any] =
    summary.weeklyStatus == .overGoal ? [.foregroundColor: NSColor.red] : [:]
```

## Known Issues and Fixes

### Thread Safety (FIXED)

**Issue**: NSWindow operations crashed with "not on main thread" exception.

**Fix**: All NSWindow and NSStatusItem operations wrapped in `await MainActor.run {}`.

**Documentation**: See `BUGFIX_THREAD_SAFETY.md`

### MSAL Authentication (FIXED)

**Issue**: Initial plan used device code flow, but MSAL for macOS doesn't support it natively.

**Fix**: Switched to interactive browser-based auth (`MSALInteractiveTokenParameters`).

**Documentation**: See `BUGFIX_MSAL_AUTH.md`

### SwiftUI Views in NSHostingView (FIXED)

**Issue**: Creating SwiftUI views off the main thread before passing to NSHostingView caused CoreGraphics "entangle context" errors and crashes.

**Fix**: All SwiftUI view creation moved inside `MainActor.run {}` blocks.

**Affected Methods**: `showConfigurationSetup()`, `showDeviceCodeFlow()`, `showCalendarSelection()`, `openSettings()`

### Settings TabView Display (FIXED)

**Issue**: SwiftUI TabView rendered as dropdown menu instead of horizontal tabs at top.

**Fix**: Replaced native TabView with custom tab bar using HStack of buttons + switch statement for content.

## Development Tips

### Testing Authentication

**Reset All Credentials**:
```bash
# Delete all Keychain items (tokens + MSAL config)
security delete-generic-password -s "office365_access_token" 2>/dev/null
security delete-generic-password -s "msal_client_id" 2>/dev/null
security delete-generic-password -s "msal_tenant_id" 2>/dev/null
defaults delete com.nexer.KeepTheBudget
```

**Reset Tokens Only** (keep MSAL config):
1. Call `authManager.signOut()` programmatically
2. Or sign out via Settings → Account → Sign Out
3. Relaunch app to trigger fresh auth flow

**Test First-Launch Flow**:
1. Delete all credentials (see above)
2. Launch app
3. Should show `ConfigurationSetupView`
4. Enter Client ID and Tenant ID
5. Complete authentication and calendar selection

### Testing Time Calculations

Create test events in Office 365 Calendar:
- Regular events: Use start/end times
- All-day events: Should count as 8 hours
- Others' events: Should NOT count (verify organizer filtering)

### Debugging Graph API

All Graph API calls have detailed logging in `GraphAPIService.swift`:
- 🔑 Token acquisition
- 📡 Request URLs
- 📦 Response data
- ❌ Errors with status codes

Enable console logging in Xcode to see request/response flow.

### Update Scheduler

Default interval: 10 minutes (configurable in Preferences)

To test immediate refresh:
- Click "Refresh Now" in popover
- Or call `refreshData()` programmatically

### Concurrency Guards

`refreshData()` has built-in guard against concurrent refreshes (line 250):

```swift
if wasLoading {
    print("⏭️  Skipping refresh - already in progress")
    return
}
```

## Code Style Notes

- Uses Swift async/await throughout (no completion handlers)
- All services injected via initializer (dependency injection)
- File headers include purpose comment
- Print statements use emoji prefixes for log categorization (🔐 auth, 📅 calendar, ⏱️ time, etc.)

## Deployment

### Building for Distribution

```bash
# Build release version
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Release build

# Re-sign frameworks for local distribution (fixes MSAL code signing)
codesign --force --deep --sign - ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Release/KeepTheBudget.app/Contents/Frameworks/MSAL.framework
codesign --force --deep --sign - ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Release/KeepTheBudget.app

# Install to Applications
cp -R ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Release/KeepTheBudget.app /Applications/
```

**Note**: Release builds may crash due to optimization issues. For local deployment, use Debug builds which are fully tested and stable.

## Files Not to Modify

- `Package.swift` - SPM dependencies (MSAL 1.3.0+)
- `project.yml` - XcodeGen config (regenerate Xcode project if changed)
- `KeepTheBudget.entitlements` - Security entitlements
- `Info.plist` - Must contain `msal{clientId}://auth` URL scheme matching configured Client ID

## Additional Documentation

- `README.md` - User-facing documentation and feature overview
- `QUICKSTART.md` - Quick start guide for building and running
- `IMPLEMENTATION_SUMMARY.md` - Complete implementation details and architecture
- `INSTALLATION.md` - Installation and setup instructions
- `BUGFIX_THREAD_SAFETY.md` - Thread safety fixes for NSWindow operations
- `BUGFIX_MSAL_AUTH.md` - MSAL authentication implementation details
