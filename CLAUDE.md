# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KeepTheBudget is a macOS menu bar application that tracks scheduled time from Office 365 Calendar. It displays daily and weekly time summaries with visual warnings when exceeding configured goals.

**Tech Stack:**
- Swift 5.9 / SwiftUI + AppKit
- macOS 12.0+ deployment target
- MSAL (Microsoft Authentication Library) for OAuth 2.0 fallback
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
- `AuthManager`: OAuth 2.0 device code flow, manual token management, proactive refresh, MSAL fallback
- `GraphAPIService`: Microsoft Graph API client (user profile, calendars, events)
- `TimeCalculator`: Daily/weekly time range calculations and event duration totals
- `StorageManager`: Keychain (tokens, MSAL config) and UserDefaults (preferences) persistence
- `UpdateScheduler`: Background timer for periodic data refresh

**Utilities** (`Utilities/`)
- `ConfigurationValidator`: UUID format validation for Client ID and Tenant ID
- `KeychainHelper`: Secure credential storage wrapper
- `TimeFormatter`: Time formatting utilities

**Models** (`Models/`)
- `CalendarEvent`: Graph API event with organizer filtering
- `TimeSummary`: Daily/weekly totals with goal status calculation
- `AppPreferences`: User settings (goals, calendar ID, refresh interval)
- `GoalStatus`: Enum for tracking goal state (underGoal, onTarget, overGoal)
- `OAuthModels`: DeviceCodeResponse, TokenResponse, OAuthErrorResponse

**Views** (`Views/`)
- `PopoverView`: Main menu displaying time summary and actions
- `SettingsView`: Custom tabbed preferences window (Goals, Calendar, Account, Configuration, About)
- `DeviceCodeView`: OAuth device code display with polling and browser redirect
- `CalendarSelectionView`: Calendar picker during setup
- `ConfigurationSetupView`: First-launch MSAL configuration screen

### Data Flow

1. **Configuration Check**: App launch → Check Keychain for Client ID/Tenant ID
2. **Lazy Initialization**: `AuthManager.initialize()` called after config verified → Loads credentials from Keychain → Initializes MSAL
3. **Authentication**: Device code flow → User enters code at microsoft.com/devicelogin → Access + refresh tokens saved to Keychain
4. **Calendar Selection**: `GraphAPIService` fetches calendars → User selects → ID saved to UserDefaults
5. **Data Refresh**: `UpdateScheduler` triggers → `GraphAPIService` fetches events → `TimeCalculator` computes totals → `AppDelegate` updates UI
6. **Event Filtering**: Only counts events where user is the organizer (filters out meeting invites)
7. **Token Refresh**: Proactive refresh at 45 min → Manual refresh using refresh token → New tokens saved atomically

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

### Why This Matters

Violating main thread requirements causes crashes:
```
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException',
reason: 'NSWindow geometry should only be modified on the main thread!'
```

**Prevention**: Always wrap NSWindow/NSView operations in `await MainActor.run {}` when called from async functions.

## Authentication & Token Management

### Device Code Flow (Primary Method)

The app uses OAuth 2.0 Device Code Flow as the primary authentication method:

**Why Device Code?**
- MSAL cache doesn't persist without Apple code signing
- Manual token management provides full control
- 90-day refresh tokens vs hourly re-auth
- Simple UX: enter code in browser
- **~2000x reduction** in authentication frequency (from ~24x/day to ~4x/year)

**Flow Sequence:**

1. **Initiate**: POST to `/oauth2/v2.0/devicecode` → Get user_code
2. **Display**: Show code to user with verification URL
3. **Poll**: POST to `/oauth2/v2.0/token` every 5 seconds
4. **Complete**: Save access_token + refresh_token to Keychain

**Critical Files:**
- `Models/OAuthModels.swift` - DeviceCodeResponse, TokenResponse
- `Services/AuthManager.swift` - startDeviceCodeAuth(), pollForDeviceCodeCompletion()
- `Views/DeviceCodeView.swift` - Code display UI with polling
- `Utilities/Constants.swift` - OAuthConstants endpoints

### Manual Token Refresh

**Proactive Refresh**: Triggers at 45 minutes (before 60-min expiry)

**Refresh Strategy (Fallback):**
1. Try `refreshUsingRefreshToken()` (if refresh token exists)
2. Fall back to MSAL silent refresh (if step 1 fails)
3. Show device code UI (if both fail)

**IMPORTANT**: Microsoft rotates refresh tokens on each use. Old token becomes invalid. Both new access + refresh tokens must be saved atomically.

**Token Lifecycle:**
- Access token: 60 minutes
- Refresh token: ~90 days
- Storage: Keychain (encrypted, persistent)

### OAuth Configuration

**Endpoints** (OAuthConstants):
- Device code: `/oauth2/v2.0/devicecode`
- Token: `/oauth2/v2.0/token`

**Scopes** (CRITICAL):
- `Calendars.Read` - Calendar events
- `User.Read` - User profile
- `Mail.Read` - Future features
- `Chat.Read` - Future features
- `offline_access` - **REQUIRED for refresh tokens**

### MSAL Fallback

MSAL remains as fallback for:
- Users without refresh tokens
- Migration from old auth
- Refresh token expiry/revocation

**Prerequisites**: `AuthManager.initialize()` must be called before auth operations
- Loads Client ID and Tenant ID from Keychain
- Creates MSAL authority URL
- Initializes MSALPublicClientApplication

## Microsoft Graph API Integration

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

**Reconfiguration**:
- Settings → Configuration tab allows viewing/changing credentials
- Changes require sign-out and app restart
- Warning shown if Client ID doesn't match Info.plist URL scheme

### Constants.swift

**Current Contents**:
- Graph API endpoints and scopes only
- OAuth endpoints for device code flow
- **NO client ID or tenant ID** (removed for security)
- `GraphConstants.scopes`: `["Calendars.Read", "User.Read"]`
- `OAuthConstants.scopes`: Includes `offline_access` for refresh tokens

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

## Development & Testing

### Reset Credentials

**Full reset** (tokens + config):
```bash
security delete-generic-password -s "office365_access_token" 2>/dev/null
security delete-generic-password -s "office365_refresh_token" 2>/dev/null
security delete-generic-password -s "msal_client_id" 2>/dev/null
security delete-generic-password -s "msal_tenant_id" 2>/dev/null
defaults delete com.keepthebudget.KeepTheBudget
```

**Tokens only** (keep config):
- Settings → Account → Sign Out → Relaunch app

### Testing Device Code Flow

1. Reset tokens (see above)
2. Launch app → Click "Get Sign-In Code"
3. Verify: Large copyable code, "Open Browser" button, countdown timer
4. Complete auth in browser
5. Verify: Auto-detection, calendar selection appears

### Testing Token Refresh

1. Authenticate successfully
2. Check console for "🔍 Token Status" showing refresh token present
3. Wait for proactive refresh (45 min trigger)
4. Verify logs: "🔄 Refreshing access token using refresh token..."
5. No re-authentication prompt should appear

### Debugging

Graph API calls log detailed information:
- 🔐 Authentication operations
- 📡 Request URLs and responses
- 🔄 Token refresh attempts
- ❌ Errors with status codes

Enable Xcode console to see full request/response flow.

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

See `DEPLOY.md` for detailed deployment instructions.

**Quick deployment:**
```bash
xcodebuild -project KeepTheBudget.xcodeproj -scheme KeepTheBudget -configuration Debug build && \
killall KeepTheBudget 2>/dev/null; \
rm -rf /Applications/KeepTheBudget.app && \
cp -R ~/Library/Developer/Xcode/DerivedData/KeepTheBudget-*/Build/Products/Debug/KeepTheBudget.app /Applications/ && \
open /Applications/KeepTheBudget.app
```

**IMPORTANT**: Do NOT manually re-sign the app. Xcode's build process correctly applies entitlements.

## Files Not to Modify

- `Package.swift` - SPM dependencies (MSAL 1.3.0+)
- `project.yml` - XcodeGen config (regenerate Xcode project if changed)
- `KeepTheBudget.entitlements` - Security entitlements
- `Info.plist` - Must contain `msal{clientId}://auth` URL scheme matching configured Client ID
